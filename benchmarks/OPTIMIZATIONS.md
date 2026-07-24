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
