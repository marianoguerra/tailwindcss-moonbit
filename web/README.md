# web/ — the showcase editor

A live editor for this compiler: type HTML on the left, get the CSS those classes
need on the right, with the compile time and output size measured as it happens.
It is static and serverless — the compiler is a MoonBit program built for
**wasm-gc** and loaded straight into the page.

The editor is a port of [margaui](https://github.com/marianoguerra/margaui)'s
editor (MIT), which does the same thing with the real `tailwindcss` npm package.
Layout, the CodeMirror wrapper and the theme switcher come from there; the
compile path is this project.

```sh
just web-serve            # build the artifacts and serve at :8080
just web-smoke            # exercise both artifacts under node
just web-size             # what a visitor downloads
```

## Layout

```
web/
  moon.mod             a second module in this workspace (see ../moon.work)
  ffi/                 the browser entry points
    scan.mbt           class extraction, via moonbit-community/html
    bundle.mbt         bundle + compiler handles
    lib.mbt            the exported JSON API
  site/                what GitHub Pages publishes
    index.html
    js/
    vendor/codemirror/ prebuilt CodeMirror 6 bundle (MIT, see its LICENSE)
    assets/            generated, committed — see below
    shell-classes.txt  the classes the page chrome itself uses
```

## Why a separate module

`ffi/` here depends on `moonbit-community/html` for class extraction. Putting it
in the published module would push that dependency — and its transitive
`moonbitlang/quickcheck` — onto everyone who installs
`marianoguerra/tailwindcss` from mooncakes or `@marianoguerra/tailwindcss` from
npm, none of whom need an HTML parser: candidate discovery is the caller's job in
the published API. A second module keeps it here. `../moon.work` makes the two a
workspace, so `just check` and `just test` at the repo root still cover both, and
build artifacts live under the shared `_build/<backend>/release/build/<module>/`.

## The browser artifacts

Both are gitignored and rebuilt by `just build-site` and by
`.github/workflows/pages.yml`:

| file | what |
|---|---|
| `site/assets/twffi.wasm` | the wasm-gc build, what browsers actually run |
| `site/assets/twffi.js` | the js build, fetched only as a fallback |

wasm-gc is the primary because it is both smaller and faster than the js
backend (`just web-size`, and the Benchmarks panel). Using it from a browser at
all depends on one link option in `ffi/moon.pkg`:

```
"use-js-builtin-string": true
```

Without it a MoonBit `String` lowers to `(array (mut i16))` — a GC array
JavaScript cannot construct, with no exported memory to fall back on. With it,
`String` *is* a JS string via the
[JS String Builtins](https://github.com/WebAssembly/js-string-builtins)
proposal, so the exported functions take and return strings directly. The host
side of that contract lives in `site/js/wasm.js`: instantiate with
`{ builtins: ['js-string'], importedStringConstants: '_' }`, and supply the
`__moonbit_time_unstable` imports that `moonbitlang/core/bench`'s clock needs on
wasm targets — which is how the compiler times its own stages instead of
trusting the page.

JS String Builtins need Chrome 130+, Firefox 134+ or Safari 18.4+. Older
browsers get the js artifact, which is fetched only when the feature probe fails.

## The generated assets

`site/assets/` is committed, so building and deploying the site never needs a
margaui checkout. Regenerating it does:

```sh
MARGAUI_DIR=/path/to/margaui just web-assets
just web-assets --with-benchmarks    # after a `just bench-warm`
just web-assets-check                # fail if the committed output is stale
```

| file | how it is produced |
|---|---|
| `margaui-bundle.json` | margaui's `entry.css` (minus its themes import and `@source`) plus its whole `@import` graph flattened by the CLI's `bundle` mode, with the upstream `tailwindcss` entry injected from `benchmarks/workloads/_shared/` |
| `themes/*.css`, `themes.json` | margaui's theme sheets, copied verbatim; fetched lazily and adopted at runtime, never compiled |
| `examples.json` | one canonical snippet per margaui component (68 of them, ~40 KB) — not the full 563-snippet corpus |
| `shell.css` | the page's own chrome, compiled ahead of time from `shell-classes.txt` so nothing flashes unstyled |
| `benchmarks.json` | a snapshot of `benchmarks/results/results.json`, for the Benchmarks panel |
| `ATTRIBUTION.md` | provenance and licences |

Add a class to `shell-classes.txt` whenever `index.html` grows one, then
regenerate.

## Notes on the editor itself

- **Class extraction happens in MoonBit.** `scan.mbt` wraps the fragment in
  `<template>` before parsing, which is what lets a bare `<tr class="hover">`
  keep its classes — the spec's "in template" insertion mode re-enters the table
  modes, where a document parse would discard those rows. A regex over
  `class="…"` also misses unquoted values, single quotes, `CLASS`, duplicate
  attributes and character references, and finds `class=` inside `<script>`
  bodies.
- **Cold by default.** Every edit builds a fresh `Compiler`, because
  `Compiler::build` accumulates candidates: a reused compiler would keep emitting
  rules for classes you just deleted, and the size the editor reports would only
  ever grow. The **Warm** checkbox shows the other side — one graph parse, ~5 ms
  builds, and no shrinking. Both are labelled in the stats line.
- **Scan first, compile only if needed.** Scanning costs microseconds, so
  editing text between tags reports `cached` and skips the compile entirely.
- **Timer resolution.** `performance.now()` is clamped, so a sub-tick stage reads
  `0 µs`. **Run ×10** reports a median instead.
