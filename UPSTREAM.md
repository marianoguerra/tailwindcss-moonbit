# Upstream provenance

- Repository: `https://github.com/tailwindlabs/tailwindcss`
- Tag: `v4.3.3`
- Commit: `c2b24dd15fed1c59dd521bd86082f520c9f5ad0d`
- Ported package: `packages/tailwindcss`
- Public surface modeled: `src/index.ts` `compile(css)` and its returned
  `build(candidates)` function, returning CSS only
- Intentionally not modeled: the JavaScript config/plugin loaders, `compileAst`,
  the design-system/intellisense APIs, and `buildSourceMap()` /
  `DecodedSourceMap`, which only exist on the JavaScript `compile(css, { from })`
  result. `@config` and `@plugin` are rejected with `UnsupportedJsCompatibility`
  rather than silently ignored.

The development oracle is independently pinned to the matching published npm
artifact in `tools/oracle/package-lock.json`.

The initial MoonBit tests are derived from the behavioral groups in
`packages/tailwindcss/src/index.test.ts`,
`packages/tailwindcss/src/utilities.test.ts`, and
`packages/tailwindcss/src/variants.test.ts`. They are rewritten as black-box
tests against the MoonBit public API. `tools/diff/cases.json` is the executable
cross-implementation compatibility ledger: a feature is compatible only when
its case produces the same canonical CSS with both compilers.

