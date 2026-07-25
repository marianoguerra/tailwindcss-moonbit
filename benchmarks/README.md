# tw-mb benchmarks

Measures **compile time** of this Tailwind compiler across its execution targets
against the original `tailwindcss` npm package, over workloads of increasing size.

The compile model everywhere is *entry CSS + candidate class names → generated
CSS*, so the load axis is candidate count (and, for the heavier tiers, a large
parser-heavy entry stylesheet).

## Targets (4)

| target | how it runs | timed via |
|--------|-------------|-----------|
| `native` | `benchmarks/bench` compiled to the native backend | in-process |
| `js` | `benchmarks/bench` compiled to JS (V8, under moonrun) | in-process |
| `wasm-gc` | `benchmarks/bench` compiled to wasm-gc (under moonrun) | in-process |
| `original` | `tailwindcss@4.3.3` from `tools/oracle/node_modules` | in-process (Node) |

The three tw-mb backends are the **same** MoonBit executable (`bench/`) compiled
three ways and driven by `moon run --release --target <t>`. It uses the same
in-memory `compile_sync` + `MemoryStylesheetLoader` path as the shipped `ffi`
package, so the three differ only by backend codegen/runtime — a clean comparison.
Timing uses `moonbitlang/core/bench`'s portable monotonic clock, so one clock
measures all three. (Raw MoonBit `.wasm` can't be called from Node — its strings
have no stable linear-memory ABI — so wasm-gc runs under moonrun, not Node.)

## Workloads

Generated once and committed under `workloads/` (so a run needs no external
checkout). Regenerate with `node benchmarks/generate.mjs`.

| id | candidates | entry | source |
|----|-----------:|-------|--------|
| `empty` | 0 | `@tailwind utilities;` | pure compile/setup overhead |
| `one` | 1 | minimal | `flex` |
| `few` | 4 | minimal | cases.json "static display" |
| `many` | 37 | minimal | cases.json "border/background/SVG/color families" |
| `a-lot` | 81 | `@import "tailwindcss"` | cases.json largest case + full theme |
| `stress` | 440 | `@import "tailwindcss"` | every unique candidate in cases.json |
| `variants` | 1500 | `@import "tailwindcss"` | `md:p-[Npx]` — one shared breakpoint variant |
| `margaui` | 122 | bundled margaui graph | classes from margaui `examples/*.html` |

`variants` is a **scaling** tier rather than a size tier. Every candidate carries
the same breakpoint variant, so each renders its own `@media` wrapper and the
optimizer sees one long run of adjacent same-key at-rules — the shape a
super-linear merge blows up on. The other tiers cannot see it: `stress` has more
candidates but spreads them across many different variants, so its runs are
short. Real Tailwind codebases lean on a handful of breakpoints, which is exactly
this shape. Reverting opt 23 moves this tier from 35ms to 466ms while leaving
`stress` and `margaui` unchanged.

Candidate material comes from the differential corpus `tools/diff/cases.json`. The
full-import tiers inline the oracle's flattened `tailwindcss/index.css`
(`workloads/_shared/tailwindcss-bundle.json`) so tw-mb and the oracle compile an
identical, self-contained graph. Each runner is handed the workload's committed
`request.json` by **path**; the bench exe reads it via `moonbitlang/x/fs`, which
works on native, js, and wasm-gc under moonrun (so even the ~290 KB margaui
request needs no inlining into argv). The `margaui` tier bundles the external
[margaui](https://github.com/marianoguerra/margaui) component library (`@import`
graph via the `tailwindcss bundle` CLI, candidates scraped from its example pages)
— its **output** is committed, so the checkout is only needed to regenerate it:

```
MARGAUI_DIR=/path/to/margaui node benchmarks/generate.mjs --with-margaui
```

## Methodology (best practices)

- **Fresh compiler per iteration.** Every timed unit is one `compile()`+`build()`
  on a *fresh* compiler. `Compiler::build` accumulates candidates across calls, so
  reusing a compiler would time growing work.
- **Warm steady-state is the headline metric.** Each runner warms up W discarded
  iterations, then times N iterations in-process — process/VM startup is excluded.
  This isolates the compiler's algorithmic cost with a common clock. Per-workload
  W/N budgets live in `manifest.json` (tiny tiers get thousands of iterations so
  V8 warms and samples are measurable; heavy tiers get tens).
- **Cold end-to-end is secondary.** A separate table times a full process launch →
  one compile → exit for the real CLI surfaces (native `cmd/tailwindcss` exe;
  oracle `compile.mjs`), capturing runtime-startup cost. Native cold is `n/a` for
  workloads needing an on-disk import graph (the CLI resolves `@import` from disk,
  not from the in-memory bundle).
- **Correctness gate before timing.** Each cell's output is compared to
  tailwindcss 4.3.3 (normalized as in `tools/diff/compare.mjs`). Exact match times
  normally; **≈** means ≥95% line overlap (cosmetic diffs only — tw-mb omits the
  license banner and merges adjacent rules) and is still timed but flagged; below
  threshold is **DIFF** and not timed (guards against timing a broken/empty path).
- **Robust stats.** Samples are pooled across trials (each trial a fresh process,
  capturing cross-process variance); we report median & min (robust to GC/scheduler
  noise) plus mean/stddev/p95 and compiles/sec.
- **Dead-code-elimination guards.** MoonBit uses `@bench.keep`; the Node runners
  consume `css.length`.
- Run on a **quiet machine**; results carry full environment metadata.

## Running

```
node benchmarks/run.mjs                              # full suite -> results/
node benchmarks/run.mjs --workload stress,margaui --trials 5
node benchmarks/run.mjs --targets native,js,original --no-cold
node benchmarks/run.mjs --warmup 20 --iters 200     # override manifest budget
node benchmarks/run.mjs --threshold 0.9             # loosen the correctness gate
```

`run.mjs` builds the release artifacts, runs the target×workload matrix, and writes
`results/results.json` (env, config, per-cell stats + gate score + outLen) and
`results/results.md` (human tables). Both are gitignored.

Flags: `--workload <ids>`, `--targets <ids>`, `--trials N`, `--cold-trials N`,
`--warmup N`, `--iters N`, `--threshold F`, `--no-cold`.

## Layout

```
benchmarks/
  bench/            MoonBit bench executable (native + js + wasm-gc)
  runners/          moonbit.mjs (spawns the bench exe), oracle-bench.mjs
  lib/              stats, env capture, output normalizer, spawn helper, loader
  workloads/        committed fixtures (request.json is the canonical request)
  generate.mjs      (re)builds fixtures
  run.mjs           orchestrator
  manifest.json     workload list + per-workload iteration budget
  results/          run outputs (gitignored)
```
