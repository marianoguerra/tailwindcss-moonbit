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
