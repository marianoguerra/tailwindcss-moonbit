# tw-mb optimization log

A disciplined, one-change-at-a-time performance log. Each entry: what changed, why
(profiler/reasoning), the benchmark delta, and whether it was kept (committed) or
reverted. Comparison metric = **warm median per compile, native backend** on the
heavy workloads (most stable; tiny tiers are too noisy). `many`/`few` use
`@tailwind utilities;`; `a-lot`/`stress` use full `@import "tailwindcss"`; margaui
uses its bundled component graph. Run: `node benchmarks/run.mjs --no-cold`.

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

## Queued (not yet done)

- **first-char-bucketed `static_utility`** (backend-neutral version of opt 6).
- Hoist / gate the remaining smaller per-call utility tables (paired_size, grid, …).
- Avoid rendering the whole AST twice for the pre/post-flatten `!=` comparison
  (compiler.mbt:203–204) — compare structurally instead.
