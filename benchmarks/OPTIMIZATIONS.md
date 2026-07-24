# tw-mb optimization log

A disciplined, one-change-at-a-time performance log. Each entry: what changed, why
(profiler/reasoning), the benchmark delta, and whether it was kept (committed) or
reverted. Comparison metric = **warm median per compile, native backend** on the
heavy workloads (most stable; tiny tiers are too noisy). `many`/`few` use
`@tailwind utilities;`; `a-lot`/`stress` use full `@import "tailwindcss"`; margaui
uses its bundled component graph. Run: `node benchmarks/run.mjs --no-cold`.

## Iteration protocol and acceptance policy

Work on exactly **one numbered proposal at a time**. Do not combine opportunistic
cleanups with an optimization: a benchmark delta must have one plausible cause.

For every proposal:

1. **Measure the baseline** from the current committed implementation:

   ```sh
   node benchmarks/run.mjs \
     --workload many,a-lot,stress,margaui \
     --targets native,wasm-gc,js,original \
     --trials 5 --no-cold
   ```

   Save the result outside `benchmarks/results/` or copy its values into the draft
   log entry before the post-change run overwrites it. Record the commit, machine,
   MoonBit version, and benchmark configuration.

2. **Implement only that proposal.** Preserve public behavior and avoid unrelated
   formatting or refactors.

3. **Validate correctness before timing:**

   ```sh
   moon check --target all --warn-list +unnecessary_annotation
   moon test
   node tools/diff/compare.mjs
   ```

   A correctness failure rejects the proposal regardless of performance.

4. **Measure again** with the exact baseline command, on the same machine and in
   the same session/thermal conditions. Compare per-workload medians and mins; use
   the heavier workloads as the decision signal and treat tiny deltas within
   run-to-run variance as noise. If the result is close, alternate baseline and
   candidate builds back-to-back rather than comparing against an older result.

5. **Decide:**
   - Keep a meaningful, repeatable improvement in **native**, the primary target.
   - Also keep a meaningful **wasm-gc** improvement when native is neutral within
     noise and there is no material native regression.
   - A regression isolated to **JS is acceptable**. JS is a fallback target and
     the original Tailwind implementation is already available to JavaScript
     users. Still record the JS delta so the tradeoff remains visible.
   - Revert when native materially regresses, or when neither native nor wasm-gc
     improves beyond noise.

6. **Document and commit only when kept.** Append the implementation, correctness
   results, full native/wasm-gc/JS A/B table, and decision to this file, then commit
   the implementation, tests, and log together. Stage explicit paths so unrelated
   working-tree changes are not included. If rejected, revert only the proposal's
   files and append a concise `REVERTED` entry before committing the benchmark
   finding when it is useful.

## Profiling findings (moon-pprof, native allocation profile, `many` workload)

`moon-pprof memprofile-native` on the `many` workload (37 candidates, 17505 total
allocations). CPU profiling was unavailable (`perf_event_paranoid=4`, no sudo; the
wasm CPU profiler can't receive the workload via argv), so this is allocation-based.
Heavy workloads (stress/margaui) SIGSEGV the alloc hook at high alloc volume.

Top allocation sites (bytes / share / allocs):
1. `prefixed_value` — 110.9 kB, **36.2%**, 7100 allocs. Called ~192×/candidate; each
   call builds a `"\{prefix}-"` marker string then slices. The project's pervasive
   "starts-with check" helper.
2. `one_filter_utility` — 48.6 kB, 15.8%, 1998 allocs. Rebuilds a 9-entry tuple
   **table on every call** + per-entry `"\{prefix}\{root}"` strings.
3. `radius_utility` — 34.7 kB, 11.3%, 2220 allocs. Same per-call table pattern.
4. `directional_spacing` — 21.9 kB, 7.1%, 1400 allocs. Rebuilds a ~20-entry table
   per call; the dispatcher also calls it **twice** on a hit (guard + return).

Diagnosis: the compile-per-candidate path is allocation-bound. Two structural causes,
both ported-from-JS idioms that don't suit a compiled, fixed-ruleset tool:
- **(A) starts-with helper allocates** a throwaway marker string per check.
- **(B) constant data tables are rebuilt per call** (the utility rule tables never
  change after creation — verified read-only — so they should be built once).
- **(C) master dispatch** (`dynamic_utility`) is a chain of ~21 `guard util(name) is
  None else { return util(name) }` that invokes each matching utility **twice**.

Potential fixes (queued as iterations): make `prefixed_value` allocation-free;
hoist per-call tables to top-level constants (data→code); de-double-call the
dispatch; longer term, replace the linear dispatch with prefix pattern matching.

## Baseline (commit 3b3cd20) — warm median per compile

| workload | native | js | wasm-gc | tailwindcss 4.3.3 |
|---|--:|--:|--:|--:|
| many (37)     | 1.66ms  | 3.72ms  | 2.47ms  | 0.81ms |
| a-lot (81)    | 14.63ms | 35.44ms | 20.04ms | 3.39ms |
| stress (440)  | 34.73ms | 79.93ms | 44.43ms | 7.54ms |
| margaui (122) | 100.67ms| 312.57ms| 141.71ms| 21.40ms |

_Machine: AMD Ryzen 5 7520U, node v24, moon 0.1.20260713, native release, 3 trials._

## Iterations

<!-- each optimization appended below -->

### 1. Allocation-free `prefixed_value` — KEPT ✅

The hottest allocation site (36% of allocs in `many`). It built a `"\{prefix}-"`
marker string on every call (~192 calls/candidate) just to run `has_prefix`, then
sliced. Rewrote it to check the `-` separator (O(1)) and `has_prefix(prefix)`
directly — no marker allocation. Semantics identical (57 tests + 85 differential
cases still pass).

Warm median delta vs baseline (native / js / wasm-gc):

| workload | native | js | wasm-gc |
|---|--:|--:|--:|
| many   | **−33.6%** (1.66→1.10ms) | −31.8% | −21.8% |
| a-lot  | −6.7% (14.63→13.65ms) | −6.6% | −4.7% |
| stress | **−15.9%** (34.73→29.22ms) | −11.9% | −10.2% |
| margaui| −1.8% (100.67→98.88ms) | −3.0% | −1.7% |

Biggest wins where utility matching dominates (`many`/`stress`); margaui is
parse-graph-bound so it moves least.

### 2. Hoist per-call utility tables to module constants (data→code) — KEPT ✅

The dispatch scans every utility for every candidate, so each utility's constant
lookup table was rebuilt on every candidate — even for candidates it never matches.
Hoisted the three biggest (profiler allocators #2–#4): `one_filter_utility`'s
`roots`, `radius_utility`'s entries, and `directional_spacing`'s entries → top-level
`let` constants built once at startup. Verified read-only (pure literals, iterated
only). 57 tests + 85 differential cases unchanged.

Warm median delta vs iteration 1 (native / js / wasm-gc):

| workload | native | js | wasm-gc |
|---|--:|--:|--:|
| many   | **−6.5%** (1.10→1.03ms) | −0.9% | −1.2% |
| a-lot  | −0.5% | +0.2% | −1.4% |
| stress | −1.6% (29.22→28.77ms) | +2.6%* | −0.7% |
| margaui| −0.1% | +1.0%* | −0.1% |

Small but consistent on native (the stable metric); js deltas marked * are within
run-to-run noise. These three tables were the bulk of table allocation; the ~12
smaller utility tables were left (diminishing returns).

### 3. Direct StringBuilder writes in the CSS renderer (no interpolation temp) — KEPT ✅

`render_css_node` already used a `StringBuilder` but interpolated a throwaway string
per node (`out.write_string("\{name}: \{value}")`) before appending. Since
`render_css_nodes` walks the whole output tree AND is called ~6–8× per compile
(compiler.mbt even renders the full AST twice just to compare pre/post-flatten),
that intermediate string was a per-node hot-path allocation. Now each fragment
(name, `": "`, value, …) is written straight to the builder. 57 tests + 85
differential cases unchanged.

Warm median delta vs iteration 2 (native / js / wasm-gc):

| workload | native | js | wasm-gc |
|---|--:|--:|--:|
| many   | −1.2% | +0.1% | −1.7% |
| a-lot  | **−3.3%** (13.58→13.13ms) | +0.4% | −2.8% |
| stress | **−3.8%** (28.77→27.67ms) | −3.9% | −1.7% |
| margaui| **−3.9%** (98.79→94.93ms) | −0.9% | −2.5% |

Scales with output size (largest on stress/margaui), as expected for a render-path
change. js gains least (V8 optimizes interpolation well).

### 4. De-double-call the dynamic-utility dispatch — KEPT ✅

The dispatch was ~21 `guard util(theme, name) is None else { return util(theme,
name) }` — each matching utility ran **twice** (the test and the return). Rewrote
each as `match util(...) { Some(_) as r => return r; None => () }`, so every utility
runs once and the matched Option is returned without recomputation. 57 tests + 85
differential cases unchanged.

Warm median delta vs iteration 3 (native / js / wasm-gc):

| workload | native | js | wasm-gc |
|---|--:|--:|--:|
| many   | −1.6% (1.02→1.00ms) | +0.0% | +0.7% |
| a-lot  | −0.7% | +0.7% | +0.1% |
| stress | −0.1% | −0.6% | −2.6% |
| margaui| −1.7% (94.93→93.28ms) | −1.5% | +0.5% |

Smaller than expected: the double-call only fires on a **hit**, and only one utility
matches per candidate — so it removed ~1 redundant call/candidate, not 21. Still a
consistent native gain and it avoids recomputing expensive matched utilities.

## Cumulative (baseline → opt 4, native warm median)

| workload | baseline | now | total |
|---|--:|--:|--:|
| many   | 1.66ms  | 1.00ms  | **−39.8%** |
| a-lot  | 14.63ms | 13.04ms | −10.9% |
| stress | 34.73ms | 27.64ms | **−20.4%** |
| margaui| 100.67ms| 93.28ms | −7.3% |

### 5. First-char / prefix fast-reject on loop-heavy utilities — KEPT ✅

Every candidate reaches the linear utility dispatch, so the loop-heavy utilities ran
their whole tables even for candidates they can't match. Added a cheap first-char (or
prefix) guard at the top of the four biggest: `directional_spacing` (m/p/g),
`radius_utility` (`rounded`), `one_filter_utility` (`backdrop-` or b/c/g/h/i/o/s),
`color_utility` (b/t/o/d/f/s, before its table is even built). Each guard is derived
from — and provably covers — that utility's own table, so it can only fast-reject
non-matches. 57 tests + 85 differential cases unchanged.

**Measured with a back-to-back A/B (gated vs reverted, same session/thermal state)** —
the reliable method, since comparing against the older opt-4 baseline was confounded
by machine warm-up drift:

| workload | native median (gated → ungated) | delta |
|---|---|--:|
| stress  | 26.93 vs 27.92ms (min 25.95 vs 26.76) | **−3.6%** |
| margaui | 94.61 vs 95.87ms (min 91.45 vs 92.54) | **−1.3%** |

(Earlier vs-stale-baseline runs wrongly showed margaui *regressing* +2% — pure thermal
drift. Lesson: A/B under identical conditions, not against a stale baseline.)

## Fresh CPU profile (after opt 5) — the dominant cost

Native allocation profiling now SIGSEGVs the moon-pprof hook (the opt-2 module-level
constants allocate during static init, which the hook mishandles). Switched to CPU
profiling via the wasm-gc GuestProfiler (`moon-pprof profile --wasm-gc`) on a
dispatch-isolating workload (all 440 stress candidates vs minimal `@tailwind
utilities;`, 40 compiles). Top self-time:

| self time | function |
|--:|---|
| **55.3%** | **`Eq::equal`** (string equality) |
| 6.9% | `FixedArray::unsafe_blit_from_string` (string copy) |
| 4.0% | `boyer_moore_horspool_find` (substring search) |
| 2.5% | `is_trailing_surrogate` · 2.2% `string_literal` · 1.5% `has_prefix` |

**Over half the CPU is string equality.** Root cause: `static_utility` (utilities.mbt)
is a `match name { "literal" => … }` with **280 arms**, which MoonBit compiles to a
linear chain of up to 280 `String == String` checks — run for *every* candidate.
(~10 other `match name` blocks add more.) This is the next dominant lever.

### 6. Hash-map `static_utility` (280-arm match → Map) — REVERTED ❌

Replaced the 280-arm `match name` with a module-level `Map[String,
Array[Declaration]]` built once + an O(1) `.get(name).map(copy)` lookup. Correct (57
tests + 85 differential cases pass). But the back-to-back A/B shows it's a
**backend-dependent tradeoff, not a portable win**:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| many   | −3.0% | −3.0% (min −7.6%) | +0.6% |
| stress | −0.7% | −2.3% | **+19.8%** ❌ |
| margaui| −1.7% | −0.9% | +0.5% |

The 55% `Eq::equal` was measured on **wasm-gc**. On **js (V8)** the string `match`
was already heavily optimized (V8's string switch/interning), so MoonBit's `Map.get`
is *slower* per lookup — and it scales with candidate count, so stress (440 cands)
regressed ~20% on js while native/wasm-gc improved. A 20% js regression is
unacceptable for a compiler shipping all three backends → reverted.

Lesson: the dominant cost is **backend-specific**. A portable fix must not replace the
match (V8 likes it). The promising alternative is **first-char bucketing** — keep the
`match name` but wrap it in `match name[0] { 'b' => match name {…b-arms…}, … }`, so
native/wasm-gc do ~20 compares instead of 280 while js keeps its optimized switches.
That's a large, careful refactor (grouping 280 arms by first char); not yet attempted.

### 7. First-char-bucketed `static_utility` — REVERTED ❌ (a wash)

Kept the `match` (so V8 stays fast) but bucketed the 280 arms by first char:
`match name[0] { 'b' => match name {…b-arms…}, … }` (18 buckets, ~15 arms each). No
js regression this time — but no meaningful gain either:

| workload | native | js | wasm-gc |
|---|--:|--:|--:|
| many   | +0.1% (min −2.7%) | −0.7% | −2.1% (min −7.9%) |
| stress | +0.2% | +0.2% | −1.0% |
| margaui| +0.8% | +1.3% | +1.1% |

All within noise except wasm-gc/many. **Why the 55% didn't materialize:** that number
came from a *dispatch-only synthetic* (minimal CSS, 440 candidates) that stripped out
all the theme/parse/render work, inflating `static_utility`'s share. Reverted — no gain
worth added nesting.

## Representative profile (stress with full `@import "tailwindcss"`, wasm-gc CPU)

Re-profiled with the REAL workload (not dispatch-only). Cost is distributed — no single
dominant lever:

| self time | function | source |
|--:|---|---|
| 31.1% | `Eq::equal` | Map-key / `name==root` / Array `.contains` equality (was 55% in synthetic) |
| 16.0% | `blit_from_string` | string copies — `.to_owned()`, slicing |
| 7.0% | `String::contains` | substring search |
| 6.0% | `Map::get` | theme lookups |
| 5.7% | `Show::output` | string interpolation `"\{}"` (theme-key building) |
| 4.6% | `boyer_moore_horspool_find` | backs contains/find |

**Lesson:** profile the representative workload, not a synthetic isolate — the isolate
mis-ranked the bottleneck and sent opt 6/7 chasing a cost that's minor on real input.

### 8. Parser copies runs, not chars (from mizchi/css + moonbitlang/parser) — KEPT ✅

Researched the tokenizers in `mizchi/css` and `moonbitlang/parser`. Both **scan a run
then copy once** (mizchi via `unsafe_substring`, moonbitlang via `lexscan`/regex-DFA
over `StringView` with copy only at token emission) instead of char-by-char. tw-mb's
`read_until_top_level` — the hot parse loop — wrote **one code unit at a time**
(`output.write_view(input[pos:pos+1])` per char). Added `is_plain_value_char` and a
fast path that copies a maximal run of plain content chars in a single `write_view`;
boundary chars (escapes, quotes, comments, parens/brackets, whitespace, terminals)
keep the per-char handling. Also switched the loop guard to a cached `len` + direct
index instead of the `Option`-returning `current()`. 57 tests + 85 differential cases
unchanged.

Warm median delta vs opt 5 (native / js / wasm-gc), parse-heavy workloads:

| workload | native | js | wasm-gc |
|---|--:|--:|--:|
| a-lot  | −1.5% | −1.1% | 0.0% |
| stress | −0.9% | −0.9% | −1.0% |
| margaui| **−2.3%** | **−1.9%** | −0.8% |

Small but **consistent across all three backends** (a portable win, unlike opt 6),
largest on the most parse-bound workload (margaui). Validates the research direction:
the parse path is where tw-mb trails upstream, and batching copies is the lever.

### 9. Collect theme from the already-parsed AST — KEPT ✅

`compile`/`compile_sync` parsed and resolved the stylesheet, rendered it, then
`parse_theme(effective_css)` parsed that rendered CSS again solely to collect
`@theme` declarations. Changed theme collection to walk `resolved_ast` directly,
removing one complete parse per compile. Also materialized `params.split(" ")` once
per `@theme` block and reused the resulting option array instead of creating four
separate split iterators.

The first implementation reused the split iterator itself, which exposed an
important correctness detail: MoonBit `Iter` values are consumed by traversal.
The differential gate caught the resulting lost `reference`/`static` options in
four cases. Materializing the iterator with `.to_array()` fixed the issue. Final
validation: `moon check --target all`, 57/57 tests, and 85/85 differential cases.

Five-trial warm median A/B against commit `4b1ac20`, same session and machine:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| many | 966.7→962.3µs (−0.5%) | 1.896→1.918ms (+1.1%) | 2.536→2.528ms (−0.3%) |
| a-lot | 13.084→12.756ms (**−2.5%**) | 19.121→18.592ms (**−2.8%**) | 33.422→32.360ms (**−3.2%**) |
| stress | 27.293→27.013ms (**−1.0%**) | 39.649→38.887ms (**−1.9%**) | 70.596→69.424ms (**−1.7%**) |
| margaui | 94.081→89.191ms (**−5.2%**) | 140.505→132.311ms (**−5.8%**) | 303.640→288.629ms (**−4.9%**) |

Minima agree on the parse-heavy workloads: native `margaui` −3.0%, wasm-gc
`margaui` −11.2%, and JS `margaui` −6.5%. The `many` workload has no full import
graph, so its approximately ±1% movement is treated as noise. Kept for the clear
and repeatable heavy-workload improvement.

### 10. Track flatten/merge changes instead of rendering twice — REVERTED ❌

Replaced the two full `render_css_nodes` calls used to compute `did_flatten` with
a shared mutable change flag threaded through nesting flattening, declaration
deduplication, and adjacent-rule merging. The flag was set only when rendered
structure changed: a nested rule was dissolved or dropped, duplicate declarations
were removed, or adjacent wrappers were combined. Correctness passed:
`moon check --target all`, 57/57 tests, and 85/85 differential cases.

Five-trial warm median A/B against commit `6acfada`, same session and machine:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| many | 950.5→942.1µs (−0.9%) | 1.891→1.865ms (−1.4%) | 2.531→2.475ms (−2.2%) |
| a-lot | 12.774→12.570ms (−1.6%) | 18.452→18.369ms (−0.4%) | 32.319→32.067ms (−0.8%) |
| stress | 26.901→26.998ms (+0.4%) | 38.775→38.754ms (−0.1%) | 69.697→69.348ms (−0.5%) |
| margaui | 88.559→88.242ms (−0.4%) | 132.781→131.631ms (−0.9%) | 290.199→293.254ms (+1.1%) |

Only `a-lot` showed a modest native gain. The representative `stress` and
`margaui` medians were effectively unchanged, native `margaui` minimum regressed
1.5%, and the implementation added roughly 80 lines of bookkeeping to recursive
optimizer code. This does not clear the acceptance threshold, so the implementation
was reverted. The two render comparisons remain.

### 11. Cache the build-invariant base render — REVERTED ❌

`build` recomputed `render_css_nodes(remove_theme_nodes_deep(self.stylesheet))`
(the theme-free base, used only for property/keyframe/theme usage discovery) on
every call. Added a `base_render : String` field to `Compiler`, computed once at
construction (guarded by `has_utilities`), and read it in `build`. Correctness
passed: `moon check --target all`, 57/57 tests, 85/85 differential cases.

Fresh compilation is neutral by construction (the benchmark times compile+build as
one unit, so the work only moves from `build` into construction). The proposal's
target is repeated `build` calls, measured with an incremental probe (compile once,
then 40 timed `build` calls; native, medians):

| workload | baseline (opt10) | cached (opt11) | delta |
|---|--:|--:|--:|
| stress  | 23.61ms/build | 23.84ms/build | +1.0% (noise) |
| margaui | 61.97ms/build | 62.45ms/build | +0.8% (noise) |

No improvement even on the incremental scenario: the base render is a negligible
fraction of a `build`, which is dominated by candidate rendering, `compose_stylesheet`,
and the full output render (all still per-build). Neither native nor wasm-gc improves
beyond noise, so reverted.

### 12. Hoist the theme-usage fixed-point's repeated interpolation — KEPT ✅

`theme_rule_nodes` discovers which theme variables are used, including a fixed-point
that closes over `var(...)` references between theme values. That inner loop ran
`value.contains("var(\{theme_variable_name(theme, dependency)}")` for **every
(used × dependency) pair on every iteration** — recomputing `theme_variable_name`
and re-interpolating the `"var(--x"` search string each time (O(V²) throwaway string
allocations for the full theme). Precomputed each non-meta variable's `"var(<name>"`
search string once into a parallel array and reused it in both the initial scan and
the fixed-point. Semantics identical (same `contains`, same prefix behavior, same
order); the combined `usage` string is kept because `render_generated_properties`
needs its byte positions. `moon check --target all`, 57/57 tests, 85/85 differential
cases.

Five-trial warm median A/B against commit `c28e87f`, same session, back-to-back:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | **−16.7%** (12.64→10.53ms) | −0.1% (min −16.3%) | −21.5% |
| stress | **−24.0%** (26.75→20.34ms) | **−16.6%** (36.85→30.75ms) | −19.2% |
| margaui| **−17.7%** (87.75→72.20ms) | **−13.0%** (129.18→112.39ms) | −8.7% |

A large, universal win on the theme-heavy full-import workloads — matches the
profile (interpolation `Show::output` + `String::contains` were top costs). Kept.

## Ordered proposal queue

Take the first uncompleted proposal, run the complete iteration protocol above,
and update this order after each result. Do not begin the next proposal until the
current one is kept and committed or reverted and documented.

**11 — done (reverted, no measurable win). 12 — done (KEPT, native −17..−24%).**
Next: proposal 13.

### Proposal 11 — Cache build-invariant base stylesheet work

`Compiler::build` repeatedly removes theme nodes and renders the same base
stylesheet. Precompute the invariant representation during compiler construction
or retain a reusable theme-free tree/string. Measure both fresh compilation (the
current benchmark contract) and a small incremental-build workload, because the
largest benefit may be in repeated `build` calls.

### Proposal 12 — Avoid the combined `usage` string and repeated theme scans

Stop copying `base` and `generated` into one large interpolated string merely for
property/keyframe/theme usage discovery. First try scanners that accept the two
strings separately. If that is insufficient, collect used custom properties while
walking declarations and replace the theme dependency fixed-point's repeated
whole-string searches with an explicit dependency graph.

### Proposal 13 — Reduce quadratic AST merge/deduplication

Instrument collection sizes first, then optimize the measured hotspot among
`dedupe_declarations`, recursive `merge_adjacent_at_rules`, and
`generated_footer.contains`. Prefer stable compact keys over hashing entire
`CssNode` trees. This proposal must remain one concrete hotspot per iteration.

### Proposal 14 — Deeper zero-copy parser representation

Only after the smaller experiments: evaluate storing `StringView` or `(start, end)`
spans in parser nodes instead of eagerly owning every substring. This targets the
profiled string-copy cost but changes AST lifetimes and is therefore the
highest-risk proposal. Treat the representation change and any non-allocating EOF
sentinel as separate iterations.
