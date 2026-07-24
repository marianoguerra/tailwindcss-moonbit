# Differential testing

`compare.mjs` compiles every case with both implementations:

```sh
npm install --prefix tools/oracle
node tools/diff/compare.mjs
```

`features.json` is the machine-readable compatibility inventory. It records a
stable feature ID, upstream test group, status, MoonBit tests, differential
cases, and the reason for each deliberate exclusion. The runner validates the
manifest before compiling and fails when a `passing` feature loses all of its
differential coverage.

Select one or more feature groups, choose comparison strictness, or only
validate and summarize the manifest:

```sh
node tools/diff/compare.mjs --feature compile.static-utilities
node tools/diff/compare.mjs --mode exact
node tools/diff/compare.mjs --summary-only
```

The oracle dependency is exactly `tailwindcss@4.3.3`, locked by
`tools/oracle/package-lock.json`. Cases may include an in-memory `files` map;
the MoonBit side exercises the native filesystem loader while the oracle uses
the equivalent virtual files. A case may use `builds` instead of `candidates`
to exercise multiple incremental builds against one compiler. Expected
rejections use `"expect": "reject"` or an implementation-specific object such
as `"expect": { "moonbit": "reject" }`. A case-level `"mode"` can be `exact`
or `normalized`.

Normalized mode removes only CRLF differences, surrounding whitespace, and the
upstream license banner. Formatting, declarations, selectors, at-rules,
ordering, and values otherwise agree exactly: every case in `cases.json`
currently matches the reference byte for byte once the banner and the trailing
newline are set aside. `--mode exact` therefore always fails, because this
implementation deliberately does not print the upstream `tailwindcss` license
banner.
