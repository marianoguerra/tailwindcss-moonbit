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

### 13. O(N) keyed declaration dedup instead of O(N²) — REVERTED ❌

Instrumented the candidates first (per the proposal). `generated_footer.contains`
was a non-issue: `footer=0, atroot_total=0` on every workload — it is never called.
`dedupe_declarations`, however, runs on the `:root` theme rule with **n=417** on
stress/a-lot (one declaration per used theme var), doing O(N²) pairwise comparisons.
Replaced it with two O(N) passes over a `Map[String,Int]` keyed by
`name\0value\0important`, keeping the last occurrence (identical semantics).
`moon check`, 57/57 tests, 85/85 differential cases.

Five-trial warm median A/B against commit `0ca5b57`, back-to-back:

| workload | native | wasm-gc |
|---|--:|--:|
| a-lot  | +0.4% | +0.2% |
| stress | +0.2% | +0.9% |
| margaui| +0.5% | +0.9% |

No improvement — slightly worse. The O(N²) *looked* quadratic but is cheap in
practice: the 417 declarations are all distinct, so each comparison fast-fails on
the first character, and the O(N²) scan costs less than the ~800 concat-key string
allocations the keyed version adds per build. After opt 12, dedup is a minor cost.
Reverted.

### 14. Zero-copy parser representation + EOF sentinel — REVERTED / not viable ❌

Two separable parts, per the proposal.

**(a) Representation change (`StringView`/spans in parser nodes) — not viable.**
The parser emits `CssNode` directly, so this means making `CssNode`'s string fields
`@string.View`. A probe (change the fields, `moon check`) produced **57 type errors
across ~15 files**, almost all "has type StringView, expected String" on the
*consumer* side: the theme `Map[String,String]`, every utility function signature,
the `@apply`/variant/css-function passes, and the candidate renderer all take
`String`. A view AST only avoids allocation if that entire chain also speaks
`StringView`; fixing the errors with `.to_owned()` instead reintroduces the copies
(net worse — view creation plus copy). It is a whole-compiler string-handling rewrite,
not a bounded change. Not attempted beyond the evaluation.

**(b) Non-allocating EOF — no measurable win, reverted.** Replaced the
`Option`-returning `current()` in the three remaining hot loops (`skip_whitespace`,
`consume_string`, `parse_custom_property`) with a direct `pos < len` bounds check +
index (the same pattern opt 8 already applied to the hottest loop). `moon check`,
57/57 tests, 85/85 differential cases. Five-trial A/B vs `0ca5b57`:

| workload | native | wasm-gc |
|---|--:|--:|
| a-lot  | −0.8% | −0.3% |
| stress | +0.5% | +0.5% |
| margaui| +0.2% | −0.2% |

All within noise. opt 8 had already removed `current()` from the hottest loop, so the
remaining loops are not hot enough for the `Option` avoidance to register. Reverted.

## Profile after opt 14 (wasm-gc CPU, real workloads) — one function dominated

Re-profiled both heavy workloads with `moon-pprof profile --interval-us 500` over a
generated `benchmarks/_prof` harness (the workload request is embedded as a string
constant, because the wasmtime profiler passes no argv and has no filesystem).
Caller attribution came from `moon-pprof pprof2folded` + a rollup of the frame
below each `Eq::equal` leaf.

| workload | self time | function | caller |
|---|--:|---|---|
| stress  | **43.1%** | `Eq::equal` | 100% from `index_of` |
| stress  | 15.0% | `blit_from_string` | mostly `render_css_node` |
| margaui | **39.8%** | `Eq::equal` | 100% from `index_of` |
| margaui | 23.7% | `parse_value_nodes` | `substitute_css_functions` |

Inclusive: `index_of` was **47.1%** of the whole stress run and **43.1%** of margaui,
every sample under `build → render_generated_properties → generated_property_block_position`.
That single call site is ~66 trigger searches over the entire rendered output, once
per build. This is the "the bigger the workload, the worse we scale" signature: the
scan cost is (fixed trigger count) × (output size), and it was being run with a
hand-written matcher that allocates a `StringView` and calls `Eq::equal` per position.

### 15. `index_of` → `String::find` (naive O(n·m) scan → Boyer-Moore-Horspool) — KEPT ✅

`string_utils.mbt`'s `index_of` compared `haystack[start:start + needle.length()] ==
needle` at **every** offset. MoonBit core already ships `String::find`, which uses
`boyer_moore_horspool_find` for needles longer than 4 code units. Replaced the body
with `haystack.find(needle)` — identical semantics (both return a code-unit offset,
both return `Some(0)` for an empty needle). `moon check --target native`, 57/57
tests, 85/85 differential cases.

Three-trial warm median A/B, back-to-back on the same session:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | **−30.7%** (9.64→6.68ms) | **−45.5%** (14.38→7.84ms) | **−22.6%** (24.41→18.90ms) |
| stress | **−27.4%** (20.48→14.86ms) | **−38.7%** (30.39→18.64ms) | **−20.0%** (53.03→42.44ms) |
| margaui| **−41.9%** (78.51→45.64ms) | **−48.2%** (109.38→56.67ms) | **−60.5%** (267.28→105.47ms) |

The largest single win recorded in this log, and universal across backends. The
lesson for future proposals: before optimizing *callers*, check that the primitive
they call is not a hand-rolled linear scan where core has a real algorithm.

### 16. Skip the value round-trip for declarations with no compile-time function — KEPT ✅

`substitute_css_functions` called `substitute_value_functions` on **every**
declaration value in the stylesheet — a full `parse_value` → `substitute_value_ast`
→ `render_value` round trip — even though only values containing `theme(`,
`--theme(`, `--spacing(` or `--alpha(` can change. On margaui (a ~290 KB import
graph) that made `parse_value_nodes` 45.7% inclusive of the whole run. Added the
same cheap guard `resolve_theme_value_functions` already used: return `(input,
false)` unless the value contains `theme(`, `--spacing(` or `--alpha(` (`theme(`
covers `--theme(`). The risk was output drift, since the round trip also normalizes
values it does not otherwise change — the differential gate says it does not:
`moon check`, 57/57 tests, 85/85 differential cases, and the benchmark similarity
gates are unchanged (97.9% / 99.0% / 99.7%).

Three-trial warm median A/B vs opt 15:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | **−13.5%** (6.68→5.78ms) | −4.1% (7.84→7.52ms) | +0.5% (noise) |
| stress | **−5.7%** (14.86→14.01ms) | −0.8% (noise) | +0.8% (noise) |
| margaui| **−21.5%** (45.64→35.84ms) | **−11.5%** (56.67→50.17ms) | **−5.7%** (105.47→99.42ms) |

Scales with import-graph size (margaui ≫ a-lot ≫ stress), as expected for a change
that skips work proportional to the number of authored declarations.

## Cumulative (opt 14 → opt 16, warm median)

| workload | native | wasm-gc | js | vs tailwindcss 4.3.3 (native) |
|---|--:|--:|--:|--:|
| a-lot  | 9.64→5.78ms (**−40.0%**) | 14.38→7.52ms (−47.7%) | 24.41→19.00ms (−22.2%) | 0.34× → **0.56×** |
| stress | 20.48→14.01ms (**−31.6%**) | 30.39→18.49ms (−39.2%) | 53.03→42.80ms (−19.3%) | 0.37× → **0.54×** |
| margaui| 78.51→35.84ms (**−54.4%**) | 109.38→50.17ms (−54.1%) | 267.28→99.42ms (−62.8%) | 0.28× → **0.56×** |

## Profile after opt 16 — where the remaining time goes

Same harness, re-profiled. Shares are of the whole profiled run, which includes
~8% (margaui) / ~4% (stress) of harness-only JSON request parsing — scale product
costs up slightly.

| share (stress) | share (margaui) | cost |
|--:|--:|---|
| 14.6% | 4.6% | `theme_rule_nodes` — one `usage.contains("var(--x")` per theme variable (417 on a full import) |
| 16.5% | 10.7% | `render_css_node` — the pipeline renders the full AST ~6–7× per compile+build |
| ~9%   | 2.9% | `boyer_moore_horspool_find` — the 66 remaining whole-output trigger scans |
| 9.1%  | 1.7% | `theme_meta` — interpolating `"\0tailwind:kind:name"` metadata keys |
| 5.4%  | 2.2% | `author_property_defaults` — re-parses the entire output CSS every build |
| 6.4%  | 1.3% | `parse_theme` |
| 6.8%  | 7.9% | `parse_css` |
| 3.4%  | 3.6% | `trim` (`s.trim().to_owned()` allocates at every call site) |
| 7.7%  | 50.0% | `substitute_css_functions` (margaui: still the top cost even after opt 16) |

### 17. Guard `author_property_defaults` on the `@property` literal — KEPT ✅

Every `build` called `author_property_defaults(usage, span)`, which ran a full
`parse_css` over the entire compiled stylesheet purely to find author `@property`
registrations. `parse_css` cannot produce an `@property` at-rule from CSS that
never spells it, so the whole parse is skippable with one `contains` check. Added
`if !css.contains("@property") { return (root, universal) }`. `moon check --target
all`, 57/57 tests, 85/85 differential cases; similarity gates unchanged.

Three-trial warm median A/B, back-to-back:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | **−6.4%** (5.79→5.42ms) | **−5.8%** (7.58→7.14ms) | −5.9% (19.11→17.98ms) |
| stress | **−8.3%** (14.14→12.97ms) | **−7.9%** (18.49→17.02ms) | −3.6% (41.32→39.83ms) |
| margaui| −0.3% (34.35→34.23ms) | −1.3% (49.04→48.38ms) | −0.5% (95.65→95.14ms) |

margaui is flat **because the guard does not fire there**: its bundled graph is the
only workload whose stylesheet actually contains an author `@property`, so it still
pays for the parse. a-lot and stress contain none and skip it entirely. That split
is the expected shape of the change, not noise.

### 18. Stop rendering CSS that nothing reads — KEPT ✅ (two iterations)

**(a) `Compiler.input` is now rendered only when it can be read.** `input` is read
at exactly one place — `build`'s `!has_utilities` early return, where the compiler
echoes the stylesheet back because it generates nothing itself — yet producing it
cost a full `render_css_nodes(resolved_ast)` in `compile`/`compile_sync` whenever
imports existed, plus another render in `compile_from_ast` when `did_rewrite`.
Since `did_rewrite` implies `has_utilities`, both were dead for every stylesheet
containing `@tailwind utilities`. `compile_from_ast` now takes the authored `css`
plus a `had_imports` flag and renders only in the echo case. Added two regression
tests for that path (as-authored echo, and import-resolved echo), which the eager
render had been covering implicitly.

**(b) `did_flatten` by structural comparison instead of two renders.** It was
`render_css_nodes(applied_ast) != render_css_nodes(flattened_ast)` — building two
complete copies of the stylesheet to diff them. `flatten_css_nesting` and
`merge_adjacent_at_rules` only ever reuse the spans of nodes they keep, so the
derived `CssNode` equality answers the same question: `applied_ast != flattened_ast`.

`moon check --target all`, 59/59 tests, 85/85 differential cases after each step.
Three-trial warm median A/B, each step against the previous state:

| workload | native (a) | native (b) | **native total** | wasm-gc total | js total |
|---|--:|--:|--:|--:|--:|
| a-lot  | −2.2% | −2.5% | **−4.6%** (5.42→5.17ms) | −4.3% (7.14→6.83ms) | −1.9% |
| stress | −1.5% | −1.3% | **−2.9%** (12.97→12.60ms) | −1.1% (17.02→16.83ms) | −0.4% |
| margaui| −3.4% | −1.5% | **−4.8%** (34.23→32.59ms) | **−9.2%** (48.38→43.93ms) | −2.3% |

Largest on margaui, the biggest import graph — exactly where a dead full-stylesheet
render costs most.

### 19. One `var(` pass instead of one whole-CSS search per theme variable — KEPT ✅

`theme_rule_nodes` decided which theme variables to emit by asking
`generated_css.contains("var(<name>")` **once per theme variable** — 417 searches
over the entire compiled stylesheet on a full import — and then ran a fixed point
that re-scanned every theme value against all 417 candidate dependencies on every
round. Replaced with:

- `var_reference_tokens`: one left-to-right pass collecting the distinct text that
  follows each literal `var(`, sorted with `lexical_compare`.
- `sorted_has_prefix`: a binary search for the first token ≥ the variable name.
  The usage test is a *prefix* test (`var(--text-sm--line-height)` also marks
  `--text-sm` used), and strings sharing a prefix are contiguous in lexicographic
  order, so one binary search decides it — preserving the old semantics exactly
  rather than switching to equality.
- The fixed point now skips any theme value that contains no `var(` at all, which
  is nearly all of them.

`moon check --target all`, 59/59 tests, 85/85 differential cases. Because the win
was much larger than the profile predicted, output was also compared **byte for
byte** against the pre-optimization compiler (`git checkout` of opts 15–19, native
`--emit`): a-lot, stress, margaui, many and few are all **identical**, so the
speedup is not a behaviour change.

Three-trial warm median A/B vs opt 18:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | **−30.8%** (5.17→3.58ms) | **−27.4%** (6.83→4.96ms) | −31.7% (17.64→12.04ms) |
| stress | **−34.5%** (12.60→8.25ms) | **−31.5%** (16.83→11.53ms) | −39.5% (39.68→24.01ms) |
| margaui| **−40.3%** (32.59→19.45ms) | **−36.0%** (43.93→28.13ms) | −44.5% (92.94→51.59ms) |

Far above the ~15% the profile attributed to `theme_rule_nodes`: the profiler
charged most of the fixed point's cost to `String::contains`/BMH rather than to the
enclosing function, so the real total was hidden. Lesson: when a hot function is a
loop of calls into core primitives, read the primitive's share too, not just the
caller's.

### 20. One `--tw-` pass for the `@property` trigger table — KEPT ✅

`render_generated_properties` located each registration block by searching the
whole compiled stylesheet for every one of its triggers — ~66 full scans per
`build`, and it rebuilt the block table on each call as well. Every trigger names
a `--tw-…` custom property, so `--tw-` occurs in it exactly once. Now the block
table and a trigger index are module-level constants (each entry carries the
offset of `--tw-` inside the trigger and the code unit that follows it), and one
pass over the CSS stops at each `--tw-`, rejects most triggers on a single code
unit compare, and rewinds by the stored offset to test the rest. Block ordering is
unchanged: the scan keeps the smallest start position per block, which is what the
per-trigger minimum computed before.

`moon check --target all`, 59/59 tests, 85/85 differential cases, and native
`--emit` output byte-identical to the pre-optimization compiler on all five
workloads.

Three-trial warm median A/B vs opt 19:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | **−3.6%** (3.58→3.45ms) | **−5.0%** (4.96→4.71ms) | −0.7% |
| stress | **−3.0%** (8.25→8.00ms) | **−3.8%** (11.53→11.09ms) | −0.5% |
| margaui| **−8.7%** (19.45→17.76ms) | **−7.7%** (28.13→25.96ms) | −9.0% (51.59→46.97ms) |

### 21. Stop building theme-metadata key strings — KEPT ✅ (two iterations)

Re-profiling after opt 20 promoted this to the top `stress` cost: `theme_meta` was
**14.0% inclusive** (5.7% under `collect_theme`, 5.3% under `theme_rule_nodes`,
2.6% under `theme_prefix`), because theme options live in the value map under
`"\0tailwind:<kind>:<name>"` keys that were built by interpolation on every
probe.

**(a) Constant prefixes instead of interpolation.** Replaced `theme_meta(kind,
name)` with per-kind module constants (`theme_meta_inline_prefix`, …) and one
concatenation, plus a fixed `theme_meta_prefix_key` for the single variable-prefix
entry (`theme_prefix` is called by `theme_variable_name` for every variable, and
was allocating a key each time). `theme_meta` itself is gone.

**(b) Collect the option sets in the pass that is already happening.**
`theme_rule_nodes` walks the whole theme map anyway, so it now classifies the
metadata keys it passes into `inline`/`reference`/`static` name sets, instead of
building three key strings and probing the map three times per variable — twice,
since the emit loop repeated the inline/reference test.

`moon check --target all`, 59/59 tests, 85/85 differential cases, and native
`--emit` byte-identical to the pre-optimization compiler on all five workloads
after each step.

| workload | native (a) | native (b) | **native total** | wasm-gc total | js total |
|---|--:|--:|--:|--:|--:|
| a-lot  | **−15.4%** | −0.7% | **−15.9%** (3.45→2.90ms) | −9.8% (4.71→4.25ms) | −4.9% |
| stress | **−7.5%** | −0.1% | **−7.6%** (8.00→7.39ms) | −6.5% (11.09→10.37ms) | −2.9% |
| margaui| −2.8% | −0.2% | −3.0% (17.76→17.22ms) | −2.9% (25.96→25.22ms) | −0.4% |

Step (b) is native-neutral on its own but improves wasm-gc (−1.2…−2.4%) and js
(−0.8…−3.1%) on every workload — 9 of 9 cells non-regressing — so it is kept under
the "wasm-gc improves, native neutral" rule. The proposal's larger option (replace
`Map[String, String]` with `Map[String, ThemeEntry]`) was **not** attempted: the
map type appears in 107 signatures across the compiler, while the encoded keys are
confined to 19 sites, so the cheap version captured the win at a fraction of the
risk. That refactor remains available if theme lookups resurface in a profile.

### 22. Non-allocating `trim` — REVERTED ❌ (core already does it)

The post-opt-20 profile put `trim` at 10.0% of margaui, 7.2% of it under the value
parser's `trim(output.to_string())`, and `trim` reads `s.trim().to_owned()` — a
view followed by a copy. Added a fast path returning `s` unchanged when the
trimmed view spans the whole string (which is the common case: the value parser
never emits leading or trailing space). Correct — 59/59 tests, 85/85 differential
cases, byte-identical output — but a wash:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | −0.7% | +0.2% | +1.3% |
| stress | −0.5% | +1.8% | +0.8% |
| margaui| +0.6% | +0.8% | +0.7% |

**Why:** core's `StringView::to_owned` is
`self.str().unsafe_substring(start, end)`, and `unsafe_substring` already returns
the original string when the range covers it — the copy this proposal removed does
not exist. The added length check is pure overhead. Reverted.

The profiled cost is therefore in `output.to_string()` (materializing the builder),
not in the trim, so a real fix would have to make the value parser hand out its
buffer without a copy — a different, larger change than this proposal.

Mirror image of opt 15's lesson: check what core's primitive actually does before
either hand-rolling it *or* trying to improve on it.

### 23. De-quadratic `merge_adjacent_at_rules` — KEPT ✅ (9.5× on the shape it targets)

When consecutive siblings shared a name/params (or selector), the merge copied the
accumulated children, appended the new ones, and re-ran `merge_adjacent_at_rules`
(plus `dedupe_declarations`) over **all** of them — re-walking and re-merging the
whole subtree for every additional sibling, so a run of K wrappers cost O(K²)
walks. Replaced with `append_merged`, which extends the wrapper already in the
output **in place**: both sides are internally merged, so concatenating them can
create only one new adjacency — the junction — and merging that junction can
create only one more, one level down. Cross-run deduplication is preserved
(`rededuplicate` re-runs `dedupe_declarations` over the whole run when rules
merge, since a declaration repeated by a later member still removes the earlier
copy).

`moon check --target all`, 59/59 tests, 85/85 differential cases, native `--emit`
byte-identical on all five workloads.

Three-trial warm median A/B vs opt 21 (opt 22 was reverted):

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | −0.7% (2.90→2.88ms) | −1.2% | +0.4% |
| stress | −1.2% (7.39→7.30ms) | +0.3% | −0.9% |
| margaui| −0.2% (17.22→17.19ms) | −0.1% | −1.1% |

Marginal — because no benchmark workload has long runs of same-key wrappers. Since
the proposal targets an *asymptotic* cost, it was measured on the shape it is about:
1500 candidates sharing one variant (`md:p-[Npx]`, one `@media` wrapper each),
native, same session, identical output (68314 bytes both ways):

| | median | min |
|---|--:|--:|
| before | 452.73ms | 444.85ms |
| after  | **47.85ms** | **31.84ms** |

**9.5× on the median, 14× on the min.** Kept: neutral on today's suite, and it
removes the last super-linear-in-candidate-count algorithm in the pipeline — the
one that would dominate any project that leans on a handful of breakpoints, which
real Tailwind codebases do. Worth adding such a tier to the workload set so this
stays covered.

## Cumulative: opt 14 → opt 23

Full suite, warm median, 3 trials, all four targets in one run (so the
`tailwindcss 4.3.3` column is measured under the same conditions as the rest —
its own numbers drift a few percent between sessions).

| workload | native before | **native after** | change | wasm-gc after | js after | tailwindcss 4.3.3 | speedup before → after |
|---|--:|--:|--:|--:|--:|--:|--:|
| empty (0)     | 13.2µs  | **4.8µs**   | −64% | 7.8µs   | 6.3µs   | 418.8µs | 31.9× → **87.3×** |
| one (1)       | 25.1µs  | **9.0µs**   | −64% | 15.8µs  | 12.2µs  | 393.8µs | 18.6× → **43.8×** |
| few (4)       | 73.2µs  | **23.3µs**  | −68% | 38.1µs  | 28.9µs  | 471.0µs | 7.1× → **20.2×** |
| many (37)     | 987.9µs | **408.7µs** | −59% | 654.5µs | 1.31ms  | 730.8µs | 0.84× → **1.79×** |
| a-lot (81)    | 9.56ms  | **2.88ms**  | −70% | 4.20ms  | 11.45ms | 2.95ms  | 0.34× → **1.02×** |
| stress (440)  | 20.46ms | **7.31ms**  | −64% | 10.40ms | 23.03ms | 6.90ms  | 0.37× → **0.94×** |
| margaui (122) | 72.47ms | **17.13ms** | −76% | 25.06ms | 46.57ms | 19.08ms | 0.28× → **1.11×** |

**The scaling gap is closed.** tw-mb was 3–4× *slower* than upstream on every heavy
workload; native is now at parity or ahead everywhere except `stress` (0.94×), and
the real-world tier (`margaui`) is 1.11× faster. wasm-gc is within ~1.4× of upstream
on the heavy tiers. js remains the slow backend by design.

What made the difference was not micro-optimization: six of the seven kept changes
removed **whole-output string scans and whole-AST renders** that ran once per fixed
table entry (66 `@property` triggers, 417 theme variables) or produced strings
nothing read. Output is byte-identical to the pre-optimization compiler on every
workload, verified with native `--emit` after each step.

## Cumulative: opt 23 → opt 29

Full suite, warm median, 3 trials, all four targets in one run, including the new
`variants` tier.

| workload | native | wasm-gc | js | tailwindcss 4.3.3 | speedup |
|---|--:|--:|--:|--:|--:|
| empty (0)      | 5.2µs   | 8.1µs   | 6.3µs    | 448.9µs | **86.3×** |
| one (1)        | 9.2µs   | 16.1µs  | 12.9µs   | 479.0µs | **52.1×** |
| few (4)        | 23.5µs  | 40.6µs  | 31.8µs   | 525.4µs | **22.4×** |
| many (37)      | 411.9µs | 680.5µs | 1.37ms   | 819.6µs | **1.99×** |
| a-lot (81)     | 2.74ms  | 4.17ms  | 10.97ms  | 3.28ms  | **1.20×** |
| stress (440)   | 7.42ms  | 10.86ms | 23.40ms  | 7.87ms  | **1.06×** |
| variants (1500)| 35.57ms | 50.93ms | 115.73ms | 16.05ms | 0.45× |
| margaui (122)  | 15.55ms | 24.32ms | 41.28ms  | 20.62ms | **1.33×** |

Compare speedups against the opt-23 table rather than the absolute milliseconds:
the `tailwindcss 4.3.3` column moved 7–14% between the two sessions, so the ratio
is the only fair cross-session statistic.

| workload | speedup at opt 23 | speedup at opt 29 |
|---|--:|--:|
| a-lot  | 1.02× | **1.20×** |
| stress | 0.94× | **1.06×** |
| margaui| 1.11× | **1.33×** |

Native is now ahead of upstream on **every** tier the previous round measured,
`stress` included — it was the last one behind. The real-world tier (margaui)
gained the most, which is what opts 25, 27 and 28 all targeted.

The exception is the new `variants` tier at **0.45×** — the one shape where tw-mb
is clearly slower than upstream. That is not a regression (opt 23 already took it
from 466ms to 35ms); it is a part of the compiler no previous workload measured,
now visible. It is the obvious starting point for the next queue.

## Ordered proposal queue

Take the first uncompleted proposal, run the complete iteration protocol above,
and update this order after each result. Do not begin the next proposal until the
current one is kept and committed or reverted and documented.

**11 — reverted (no win). 12 — KEPT (native −17..−24%). 13 — reverted (no win).
14 — reverted (representation change not viable; EOF sentinel no win).
15 — KEPT (native −27..−42%, all backends). 16 — KEPT (native −6..−22%).
17 — KEPT (native −6..−8% where the guard fires). 18 — KEPT (native −3..−5%).
19 — KEPT (native −31..−40%). 20 — KEPT (native −3..−9%).
21 — KEPT (native −3..−16%). 22 — reverted (core already avoids the copy).
23 — KEPT (neutral on the suite, 9.5× on a same-variant-heavy workload).
24 — rejected (the cost it targets is ~1%; the rest was proposal 25's).
25 — KEPT (native −16% on margaui). 26 — rejected (nothing is parsed twice).
27 — KEPT (native −1..−5%, all nine cells improve).
28 — KEPT (native ~−3.5% on margaui, scales with source size).
29 — ADDED (`variants` tier; catches opt 23's quadratic at 13.3×).
Queue complete.**

Proposals 17 through 29 are complete — their outcomes are the iteration entries
above. The queue that produced 24–29 was rebuilt from the profile taken *after*
opt 21, so the shares it quoted are of the compiler as it stood then (the
`margaui` numbers still include ~23% harness-only JSON parsing; scale product
costs up accordingly).

Two of the six were rejected on **instrumentation rather than implementation**,
which is the pattern worth keeping: proposal 24's headline cost turned out to
belong to proposal 25, and proposal 26's premise — a file parsed once per
importer — was simply false. Both were settled with a probe far cheaper than the
change would have been.

### Proposal 24 — Discover usage from the AST, not from a rendered string

`build` still renders the theme-free base stylesheet and the generated nodes into
strings whose *only* purpose is usage discovery (`render_css_node` is 11.5% of
stress, 9.2% of margaui, and the `usage` concatenation feeds three consumers).
After opts 19 and 20 both consumers are single-pass scanners, so they could walk
the AST instead and skip building `base` and `usage` altogether. The catch is
ordering: `@property` blocks are emitted in first-rendered-position order, so the
AST walk has to produce a comparable ordering key. Note opt 11 tried *caching* this
render and failed; not rendering it at all is the different, promising version.

### 24. Discover usage from the AST, not from a rendered string — REVERTED ❌

Instrumented before implementing (opt 13's lesson), because the proposal's own
justification — `render_css_node` at 11.5% of stress / 9.2% of margaui — is a
share of *all* renders, not of the two this change would remove.

**Upper-bound probe.** Replacing `usage` with just the generated CSS (wrong
output, but it deletes the whole base pipeline: the `remove_theme_nodes_deep` AST
clone, the base render, the concatenation, and all four scans over the base text)
gives the most the proposal could possibly return:

| workload | baseline | `usage = generated` | ceiling |
|---|--:|--:|--:|
| a-lot  | 2.91ms | 2.76ms | −5.2% |
| stress | 7.59ms | 7.34ms | −3.3% |
| margaui| 18.23ms| 15.70ms| **−13.9%** |

**Step (a) — no AST clone, no concatenation.** `write_without_theme_nodes` renders
the stylesheet with its `@theme` blocks skipped straight into the `usage` builder,
so the copy of the AST and the third full copy of the text both disappear.
Correct: `moon check --target all`, 59/59 tests, 85/85 differential cases, native
`--emit` byte-identical on all five workloads. Three-trial back-to-back A/B:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | −1.0% (2.92→2.89ms) | +1.1% | +0.5% |
| stress | +0.5% (7.49→7.53ms) | +1.4% | +1.6% |
| margaui| −0.1% (18.19→18.18ms) | −0.1% | −1.7% |

A wash. So the ceiling is not in the render or the clone — it is in the scanning.

**Where the 13.9% actually is.** Disabling `author_property_defaults` alone (base
render and all other scans left in place) recovers nearly all of it:

| workload | baseline | no `author_property_defaults` | delta |
|---|--:|--:|--:|
| stress  | 7.49ms | 7.46ms | −0.4% (no `@property` in that workload) |
| margaui | 18.19ms| 15.89ms| **−12.6%** |

That is **proposal 25's** target — the full `parse_css` of the compiled stylesheet
that opt 17's guard cannot skip on margaui, the one workload whose graph really
does register an author `@property`. What is left for proposal 24 is the base's
share of the other three scanners plus the render: 15.89 − 15.70 ≈ 0.19ms, about
**1% of margaui** and ~2% of stress.

Rejected: a ~1–2% native return does not justify the change the proposal actually
requires. Every consumer of `usage` is a *byte-offset* scanner — `@property` blocks
are ordered by first-rendered-position, and triggers such as `filter: var(--tw-blur`
straddle the `name: value` boundary that only exists in rendered text — so an AST
walk has to reproduce render offsets exactly across declarations, selectors,
at-rule params, `Context` transparency and `AtRoot` re-indentation. Step (a) is
reverted with it; it carries its own risk surface for no measured gain.

### 25. Read author `@property` off the AST instead of re-parsing the output — KEPT ✅

Opt 24's instrumentation put this at −12.6% of margaui on its own. The proposal
was to find each `@property` occurrence in the compiled CSS and parse only that
at-rule; the implementation goes one step further and parses nothing at all. That
text is rendered from an AST `build` is still holding, so the registrations are
read straight off the nodes: `collect_author_property_at_rules` walks the
theme-free stylesheet and the merged generated nodes, and `author_property_defaults`
now takes those at-rules instead of a string. Opt 17's `contains("@property")`
guard is gone with the parse it guarded.

Only top-level registrations count, which is exactly what iterating `parse_css`'s
result did. The walk therefore descends into `Context` (renders its children
inline) and `at-root` (re-indents its children to column zero) — both keep their
children at the top level of the text — and stops at rules and other at-rules,
whose contents `parse_css` would have seen as nested. `@theme` needs no special
case: it is skipped as a non-`@property` at-rule, matching `remove_theme_nodes_deep`.

`moon check --target all`, 59/59 tests, 85/85 differential cases, and native
`--emit` byte-identical to the pre-optimization compiler on all five workloads —
including margaui, the workload that actually exercises the author-registration
path.

Three-trial warm median A/B, back-to-back on the same session:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | −0.3% (2.92→2.91ms) | +0.2% | −1.7% |
| stress | +0.1% (7.48→7.49ms) | **−3.2%** (10.96→10.61ms) | −2.4% |
| margaui| **−16.0%** (18.46→15.50ms) | **−10.9%** (26.78→23.85ms) | −7.7% (49.61→45.80ms) |

The exact mirror image of opt 17: a-lot and stress register no author `@property`,
so the guard already skipped their parse and they cannot gain. margaui is the
workload that pays, and it is the one that moves.

### 26. Cache parsed stylesheets by resolved path — REJECTED ❌ (nothing is parsed twice)

The proposal instructed instrumenting before implementing. Instrumented, and the
premise does not hold: **no file in the margaui graph is parsed more than once.**

A static reconstruction of the graph (extract every `@import`/`@reference`, resolve
each spec the way the loader does, count importers per target) reports 82 import
edges reaching 82 distinct targets and **zero files with more than one importer** —
the graph is a tree, not a DAG with shared subtrees.

A counter compiled into `resolve_imports_sync` itself confirms it directly:

```
PROBE parses=81 bytes=275750
```

81 parses for 81 distinct imported files, and the byte total is exactly the sum of
the file sizes with no file counted twice. A by-path cache would have a 0% hit rate.
The remaining `parse_css` call sites are the entry stylesheet (once) and the 81
imports (once each); `author_property_defaults`, which used to parse the compiled
output a second time, was removed by opt 25.

So `resolve_imports_sync` at 18.1% and `parse_css` at 23.6% of margaui are not
repeated work — they are the irreducible cost of reading a ~276 KB import graph
once. Making that cheaper means making the parser itself faster, which is
proposal 28's subject, not a cache.

### 27. One theme pass for keyframes instead of one per keyframe — KEPT ✅

The proposal filed this at 1.4% of stress and suggested threading opt 19's `var(`
token set through. Probed first (return `""` from `render_used_keyframes`): the
function is worth far more than that, and the token set turns out to be the wrong
tool for it.

| workload | baseline | no `render_used_keyframes` | ceiling |
|---|--:|--:|--:|
| a-lot  | 2.91ms | 2.67ms | **−8.2%** |
| stress | 7.49ms | 7.23ms | −3.5% |
| margaui| 15.50ms| 15.71ms| +1.4% (noise) |

The cost is not the searches, it is the **walk**: the function iterated the whole
theme map again for *every* `@keyframes` block to find the `--animate-*` tokens
that could name it, so a full import paid (keyframes × theme size) prefix tests
plus a `trim` each, and re-ran `theme_css_value` and a whole-output search for
every (keyframe, token) pair that matched. `a-lot` is hit hardest precisely
because it emits **no** keyframes at all — it paid the entire nested walk to
discover that nothing was used.

Now one pass collects the keyframe blocks and the `--animate-*` tokens together,
and each token's search runs at most once, memoized in a small state array. The
searches stay lazy — a token is only looked for once some keyframe actually names
it — which is what the old inner loop did, so no search is added.

The token set was **not** used: `theme_css_value` yields `var(--animate-spin)` for
a plain variable but the raw value for an `inline` theme and `var(--x, <value>)`
for a `reference` one, and opt 19's tokens stop at `)`/`,`, so matching them
against the token set would accept `var(--animate-spin, …)` where `contains`
rejects it. That is a behaviour change for no extra gain, since the searches were
never the bottleneck.

`moon check --target all`, 59/59 tests, 85/85 differential cases, native `--emit`
byte-identical on all five workloads — margaui emits 11 keyframes and stress 1, so
the emit path is genuinely covered.

Three-trial warm median A/B, back-to-back:

| workload | native | wasm-gc | js |
|---|--:|--:|--:|
| a-lot  | **−4.8%** (2.90→2.76ms) | **−6.8%** (4.40→4.10ms) | −6.3% (11.93→11.18ms) |
| stress | **−2.3%** (7.52→7.35ms) | −2.3% (10.78→10.53ms) | −1.3% |
| margaui| −1.0% (16.01→15.85ms) | **−3.6%** (24.59→23.71ms) | −1.4% |

All nine cells improve.

### 28. Keep the parser's token as source offsets until something rewrites it — KEPT ✅

Opt 22 showed the cost at `trim(output.to_string())` is the materialization, not
the trim: every token was copied into a `StringBuilder` and then copied a second
time on the way out. Proposal 14 had already ruled out making the AST hold views —
that is a whole-compiler rewrite — but the *token* does not have to be a view to
avoid the double copy.

Almost every token `read_until_top_level` produces is exactly a slice of the
source. Only two things make the result differ from
`input[content_start:content_end]`:

- a **comment**, which is dropped from the output, and
- a **whitespace run that is not already a single space**, which is collapsed
  to one.

Everything else — plain runs, escapes, quoted strings, parens/brackets and other
single characters — is written through verbatim, so the slice still stands in for
it. The loop therefore tracks a pair of offsets and allocates nothing; on the
first comment or non-trivial whitespace run it flushes those offsets into the
builder and the original character path takes over. Whitespace that turns out to
be trailing never forces the flush, because the pending space is only reconciled
at the next write. `finish_token` then produces the token with a **single** copy.

The loop was restructured so all four write sites (`plain run`, escape, quoted
string, single char) share one emit point, which is what makes the two modes
tractable to reason about.

`moon check --target all`, 59/59 tests, 85/85 differential cases, native `--emit`
byte-identical on all five workloads.

The first A/B came out close, so it was run **twice, with the order reversed** the
second time (baseline first) to separate the change from warm-up drift:

| workload | native r1 | native r2 | wasm-gc r1 | wasm-gc r2 | js r1 |
|---|--:|--:|--:|--:|--:|
| a-lot  | −0.7% | +0.4% | −0.2% | 0.0% | −1.6% |
| stress | 0.0% | −1.8% | −1.7% | −0.8% | −1.1% |
| margaui| −1.1% | **−4.8%** | +2.2% | −0.6% | −4.0% |

The medians disagree on margaui (−1.1% vs −4.8%), but the **minima agree closely**
— 14.40 vs 14.98ms in round 1 and 14.37 vs 14.86ms in round 2, both about −3.5% —
so the margaui gain is real and round 1's median simply landed high. Kept: a
repeatable native gain on the most parse-bound workload, scaling with source size
(margaui ≫ stress ≫ a-lot, exactly as a per-token copy should), no material
regression on any backend, and js gains throughout.

### 29. `variants` — a same-variant scaling tier — ADDED ✅

Opt 23 removed an O(K²) that no committed workload exercised; it took a throwaway
probe to see it. That probe is now a committed tier: **1500 candidates sharing one
breakpoint variant** (`md:p-[1px]` … `md:p-[1500px]`) over the full-import entry.
Each renders its own `@media` wrapper, so the optimizer sees one long run of
adjacent same-key at-rules. Arbitrary values keep every candidate distinct while
keeping the generated declaration trivial, so the tier measures the merge path
rather than utility matching.

This is a **scaling** tier, not a size tier. `stress` has 440 candidates but
spreads them over many different variants, so its runs are short — which is
exactly why it could not see the quadratic.

Validated by reverting opt 23 and re-running, with everything else identical:

| workload | opt 23 present | opt 23 reverted | ratio |
|---|--:|--:|--:|
| **variants** (1500) | **35.14ms** | **466.38ms** | **13.3×** |
| stress (440)  | 7.30ms  | 7.25ms  | 1.00× |
| margaui (122) | 15.60ms | 15.12ms | 1.00× |

The regression is invisible to the rest of the suite and unmissable in the new
tier. It also gates against the oracle like every other tier (~99.9% similarity),
and it is the tier where tw-mb is currently *slowest* relative to upstream
(35.14ms vs 15.03ms, 0.43×), so it doubles as a standing target.

Budget: `warmup 5, iters 40` — the tier is ~35ms per compile, so it needs far
fewer iterations than the small tiers.

*(The historical descriptions of proposals 11–14 were removed once their
iterations were recorded above; see entries 11–14 for what happened.)*
