# Ported upstream utility tests

`tools/diff/cases.json` is the hand-written compatibility ledger. This directory
is its mechanical companion: every candidate list upstream asserts on in
`packages/tailwindcss/src/utilities.test.ts`, run through both compilers.

```sh
just build-cli          # the comparison drives the native CLI
just oracle             # once, to install tailwindcss 4.3.3
just upstream-diff
```

## How the port works

The upstream file is *executed*, not parsed. `harness.mjs` stubs `vitest` and
the `run()` helper so that calling `run(candidates, css)` records its arguments
instead of compiling, and `extract.mjs` imports the file under those stubs. Loops
and spreads that build candidate lists are therefore evaluated exactly as
upstream evaluates them, which no regex over the source could do.

Upstream asserts a result in one of two ways, and both are captured:

- `toMatchInlineSnapshot(...)` — the candidates produce CSS (`"expect": "output"`)
- `.toEqual('')` — the candidates are rejected (`"expect": "empty"`)

The inline snapshots themselves are *not* ported. `compare.mjs` compiles each
group with the pinned oracle at the same commit, so the oracle stands in for the
snapshot and stays correct if a case is regenerated.

`cases.json` is generated and committed; `extract.mjs` downloads the upstream
file into `vendor/` (gitignored) at the commit `tools/diff/features.json` pins.
Rerun it only to move to a new upstream version:

```sh
node tools/upstream/extract.mjs
```

## The baseline

This is a partial reimplementation, so most of these tests do not pass yet.
`baseline.json` records every currently divergent test with the shape of its
divergence:

- `not implemented` — upstream emits CSS, this compiler emits nothing
- `accepted, upstream rejects` — this compiler emits CSS for a candidate upstream
  refuses; the failure mode that produces silently invalid CSS
- `different output` — both emit CSS and the two disagree
- `input rejected by this compiler` — the stylesheet itself is refused

`compare.mjs` fails when a test outside the baseline breaks **and** when a test
listed in it starts passing, so fixing a divergence forces the ledger to be
updated:

```sh
node tools/upstream/compare.mjs --report            # divergences grouped by shape
node tools/upstream/compare.mjs --filter gap --verbose
node tools/upstream/compare.mjs --update-baseline   # after reviewing the diff
```
