# Tailwind CSS compiler for MoonBit

This package implements the compiler-facing API of Tailwind CSS v4.3.3 in
MoonBit. Compilation is staged so a parsed stylesheet can be reused while new
candidate classes are discovered.

```mbt check
///|
async test {
  let compiler = @tailwindcss.compile(
    "@theme { --color-black: #000; } @tailwind utilities;",
  )
  let css = compiler.build(["flex", "hover:bg-black"])
  assert_true(css.contains("display: flex"))
  assert_true(css.contains("background-color: var(--color-black)"))
}
```

The implementation is independent MoonBit code. `tools/oracle/` contains a
development-only differential runner pinned to the original npm package.

## Live demo

**<https://marianoguerra.github.io/tailwindcss-moonbit/>** — type HTML, watch the
CSS those classes need get compiled in your browser, with the compile time and
output size measured as it happens. There is no server: the compiler is this
package built for wasm-gc, and the stylesheets are
[margaui](https://github.com/marianoguerra/margaui)'s component library — 78
files, ~270 KB of CSS, compiled from scratch on every edit.

The editor also closes the loop the API leaves open: it discovers candidates by
parsing the HTML with [`moonbit-community/html`](https://github.com/moonbit-community/html5-mbt)
and collecting `class` attributes, all inside MoonBit. Source and notes in
[`web/`](web/README.md); run it locally with `just web-serve`.

## Using it

The compiler is exposed three ways. In every case candidate discovery is the
**caller's** responsibility: pass the class names you want generated. This
package does not scan content files (HTML/JS/templates) for classes; `@source`
directives are parsed and surfaced via `Compiler::sources()` for hosts that want
to scan themselves.

### As a MoonBit library

`compile(css, options?)` resolves `@import`s through an async
`StylesheetLoader`; `compile_sync(css, options?)` does the same through a
`SyncStylesheetLoader`. Both return a reusable `Compiler`; call `build` with
candidate class names (candidates accumulate across calls). Use `compile_sync`
on hosts without an async runtime — notably the **wasm-gc** backend.

```mbt check
///|
test {
  let loader = @tailwindcss.MemoryStylesheetLoader::new(files=[
    ("base.css", "@theme { --color-black: #000; }"),
  ])
  let compiler = @tailwindcss.compile_sync(
    "@import \"base.css\"; @tailwind utilities;",
    options=@tailwindcss.CompileOptions::new(sync_loader=loader),
  )
  let css = compiler.build(["flex"])
  assert_true(css.contains("display: flex"))
}
```

### As a native CLI

`cmd/tailwindcss` is a native executable:

```sh
moon build --target native cmd/tailwindcss
tailwindcss -i input.css -o output.css -c candidates.txt --polyfills 3
```

`-i/--input` is the entry CSS (its `@import`s resolve against the filesystem via
`loader/fs`), `-c/--candidates` is a newline-separated class-name file (optional),
`-o/--output` defaults to stdout, and `--polyfills` is `0..3` (default all). Run
`tailwindcss --help` for the full listing.

Two sub-modes sit alongside the default compile. `bundle` resolves the entry's
whole `@import` graph from the filesystem and writes a JSON `{ path: content }`
map:

```sh
tailwindcss bundle -i input.css -o bundle.json
```

That map is exactly the shape the `imports` field below takes, so `bundle` is
how a filesystem project becomes a self-contained in-memory compile request for
the JS / Wasm-gc entry points, which have no filesystem access. A `--batch`
sub-mode backs the differential test harness.

### As a JS / Wasm-gc library

The `ffi` package exports `compile_css_json` (structured, in-memory) and
`compile_css` (inline CSS only) for the `js`, `wasm`, and `wasm-gc` backends.
`@import` resolution is **in-memory only**: pass the imported files as a
`{ path: content }` map. `compile_css_json` takes a JSON request and returns a
JSON `{ ok, css }` / `{ ok, error }` result:

```json
{
  "css": "@import \"base.css\"; @tailwind utilities;",
  "candidates": ["flex", "hover:bg-black"],
  "imports": { "base.css": "@theme { --color-black: #000; }" },
  "base": "",
  "from": "input.css",
  "polyfills": 3
}
```

Every field except `css` is optional: `candidates` defaults to none, `imports`
to empty, `base` to `""`, and `polyfills` to `POLYFILL_ALL`. `base` is the
prefix that relative `@import` specifiers and `@source` paths resolve against,
so it must match the keys used in `imports`.

`ffi/js/` ships an ergonomic, dependency-free wrapper (`compile({ input,
candidates, imports, ... })`); see `ffi/js/README.md` for the build and usage
steps.

## Current compiler surface

The package currently covers:

- structured CSS parsing for nested rules, at-rules, comments, strings, and
  balanced values
- a Tailwind-style generic value AST for lossless nested function
  transformation
- a Tailwind-oriented selector AST for structural nesting replacement,
  combinators, attributes, selector lists, and selector pseudo-functions
- `@theme` custom properties and used-variable emission
- `@tailwind utilities`, block and functional `@utility`, selector and block
  `@custom-variant`, stylesheet `@variant`, and `@apply` compiled through the
  shared candidate and variant pipeline (including variants and nested output)
- incremental candidate accumulation
- structured candidates with negative forms, modifiers, important flags,
  arbitrary properties, and stacked variants
- display, position, overflow, flexbox, alignment, spacing, sizing, color,
  typography, border, opacity, and arbitrary-property utilities
- screen-reader accessibility, table, float/clear, isolation, box-sizing,
  field-sizing, and basic flex-basis utilities
- logical spacing, inset positioning, viewport/content sizing, and paired
  `size-*` utilities
- text overflow, whitespace, wrapping, hyphenation, list, scrollbar-gutter,
  and vertical-alignment utilities
- aspect-ratio, object-position, and expanded content/item/self alignment
  utilities
- axis overflow, overscroll, scroll behavior, scrollbar width, user selection,
  resize, and basic scroll-snap utilities
- cursor, appearance, basic touch-action, accent/caret color, backface, and
  transform-box utilities
- numeric, arbitrary, and theme-backed grid templates plus auto-track and
  grid-flow utilities
- numeric, negative, arbitrary, full-span, auto, and theme-backed grid item
  placement utilities
- common state, structural, media, dark-mode, breakpoint, and arbitrary
  variants
- `@source` metadata discovery
- recursive CSS imports through an async loader, including an in-memory VFS and
  a native filesystem implementation
- import `layer()`, `supports()`, and media conditions
- `--spacing()`, `--theme()`, legacy `theme()`, and `--alpha()` substitution
- file, inline, and negated `@source` directives
- static and functional `@utility` definitions; functional values support
  theme namespaces, literals, constrained numbers/percentages, ratios,
  typed arbitrary values, defaults, and modifiers
- selector shorthand and selector/at-rule block `@custom-variant` definitions
  using `@slot`, including multiple branches, nesting, wrapper declarations,
  and composition through `@variant`
- theme-backed, arbitrary, named, minimum, and maximum container-query variants
- common `group-*`, `peer-*`, and `has-*` compound variants, including named
  group/peer markers and arbitrary `:has()` selectors
- structural `nth-*` variants plus `aria-*` and `data-*` attribute variants
- selector-compatible `not-*` and `in-*` compound variants, including
  arbitrary ancestor selectors
- functional `supports-*` conditions and compound negation of single media,
  supports, and container conditions
- theme-backed and arbitrary `min-*` / `max-*` responsive variants
- extended form-state, direction, starting-style, contrast, forced-color,
  pointer, and scripting variants
- stateful utilities that compose through generated custom properties and
  `@property` registrations: transforms, filters, backdrop filters, shadows,
  rings, gradients, transitions, and touch/scroll-snap state
- selector-producing utilities (`space-x/y`, `divide-*`, `placeholder-*`) with
  their generated child selectors and reverse custom properties
- `@reference` and `@import "…" reference`, `theme(reference)` imports, import
  `layer()`/`supports()`/media conditions, and per-file `@source` base
  propagation
- AST optimization: nesting flattening, adjacent rule and at-rule merging,
  declaration deduplication, and empty-node removal
- the `@property` and `color-mix()` polyfills, individually gated through the
  `polyfills` compile option (`POLYFILL_NONE`/`AT_PROPERTY`/`COLOR_MIX`/`ALL`)
- exact upstream property and variant sorting, independent of the order in which
  candidates are discovered

Every case in `tools/diff/cases.json` matches the reference compiler byte for
byte apart from the upstream license banner, which this package does not print.

JavaScript configuration and plugin loading is intentionally out of scope;
`@config` and `@plugin` are rejected with `UnsupportedJsCompatibility`. Source
maps are deferred because the agreed public surface returns CSS only (see
`migration-plan.md` step 16). Brace expansion in `@source` globs and the parts
of the upstream utility catalogue without a passing differential case are not
implemented. No input should be treated as compatible until a differential case
covers it.

## Conformance

Run both the MoonBit tests and the pinned JavaScript oracle:

```sh
moon test
npm install --prefix tools/oracle
node tools/diff/compare.mjs
```

See `UPSTREAM.md` for provenance and the porting boundary.
