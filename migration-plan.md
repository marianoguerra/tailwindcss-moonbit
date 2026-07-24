# Remaining Tailwind CSS v4.3.3 migration plan

This plan covers the remaining work required for the MoonBit package to expose
a `compile` function that is compatible with
`tailwindcss@4.3.3/packages/tailwindcss`.

JavaScript configuration files, JavaScript plugins, and the JavaScript plugin
API are intentionally out of scope. `compileAst`, design-system/intellisense
APIs, and PostCSS integration are also outside the required public MoonBit API
unless they become necessary internally to implement `compile`.

## Ordered todo list

- [x] 1. Build a machine-readable compatibility manifest and expand the drift harness
- [x] 2. Complete CSS, value, selector, and attribute parser conformance
- [x] 3. Complete candidate parsing, arbitrary-value decoding, and canonicalization
- [x] 4. Replace rendered-string utility composition with a complete internal AST
- [x] 5. Complete variant coverage, compound compatibility, and variant ordering
- [x] 6. Complete `@theme`, prefix, reference-theme, and keyframe semantics
- [x] 7. Finish declaration-only and simple functional utility families
- [x] 8. Finish typography, borders, backgrounds, and color utilities
- [x] 9. Implement stateful utilities that require generated custom properties
- [x] 10. Implement selector-producing utilities and declaration expansion
- [x] 11. Complete `@apply`, `@utility`, `@custom-variant`, and `@variant`
- [x] 12. Complete imports, sources, reference imports, and path/base propagation
- [x] 13. Implement AST optimization, declaration folding, and required polyfills
- [x] 14. Implement exact property and variant sorting
- [x] 15. Port the remaining upstream tests and add fuzz/property testing
- [x] 16. Add source-map support if required by the final `compile` contract
- [x] 17. Run the final compatibility, performance, and release audit

## 1. Build a machine-readable compatibility manifest and expand the drift harness

### Goal

Make remaining work measurable. Every upstream feature or test group should be
marked as `passing`, `partial`, `excluded`, or `not-started`, with an associated
MoonBit test and differential case where applicable.

### High-level implementation

1. Generate an inventory from upstream `utilities.test.ts`, `variants.test.ts`,
   `index.test.ts`, `css-functions.test.ts`, and parser tests.
2. Store stable feature IDs and status in a JSON or Markdown table under
   `tools/diff/`.
3. Extend `tools/diff/compare.mjs` to support:
   - selecting cases by feature ID;
   - expected rejections;
   - multiple builds against one reusable compiler;
   - fixtures with imports and source directives;
   - optional byte-for-byte versus normalized comparison modes.
4. Add a coverage summary that fails CI if a passing feature loses its
   differential case.
5. Keep all deliberate exclusions explicit, especially JS config and plugins.

### Relevant resources

- Current cases: `tools/diff/cases.json`
- Current runner: `tools/diff/compare.mjs`
- Original oracle: `tools/oracle/compile.mjs`
- Upstream tests:
  - `packages/tailwindcss/src/utilities.test.ts` in the v4.3.3 clone
  - `packages/tailwindcss/src/variants.test.ts` in the v4.3.3 clone
  - `packages/tailwindcss/src/index.test.ts` in the v4.3.3 clone
- Validation: `node tools/diff/compare.mjs`

## 2. Complete CSS, value, selector, and attribute parser conformance

### Goal

Support every syntax form consumed by the compiler without adopting a general
CSS parser whose model conflicts with Tailwind's shallow, lossless parsers.

### High-level implementation

1. Port the remaining upstream parser fixtures into white-box MoonBit tests.
2. Extend the CSS AST for upstream node kinds not yet represented, especially
   context and at-root nodes.
3. Complete lossless handling of comments, escapes, malformed input, Unicode,
   nested functions, custom-property values, and unusual at-rule parameters.
4. Complete selector parsing for pseudo-elements, namespace syntax, complex
   attributes, relative selectors, nesting, and selector-list traversal.
5. Add a dedicated attribute-selector validator equivalent to upstream
   `attribute-selector-parser.ts`; use it for `aria-*`, `data-*`, and arbitrary
   selectors.
6. Add round-trip and rejection property tests for all parsers.

### Relevant resources

- MoonBit:
  - `css_parser.mbt`
  - `css_ast.mbt`
  - `value_parser.mbt`
  - `selector_parser.mbt`
- Upstream:
  - `src/css-parser.ts` and `src/css-parser.test.ts`
  - `src/value-parser.ts` and `src/value-parser.test.ts`
  - `src/selector-parser.ts` and `src/selector-parser.test.ts`
  - `src/attribute-selector-parser.ts`
- Prior parser decision: selectively port Tailwind algorithms/tests; do not
  vendor `mizchi/css` wholesale.

## 3. Complete candidate parsing, arbitrary-value decoding, and canonicalization

### Goal

Produce the same accepted/rejected candidate set and normalized meaning as
Tailwind before utility or variant compilation begins.

### High-level implementation

1. Replace the remaining string-only candidate fields with explicit variants
   for static, functional, arbitrary-property, modifier, and compound forms.
2. Port arbitrary-value decoding completely, including escaped underscores,
   CSS variables, math operators, type hints, and nested values.
3. Implement exact modifier movement for nested compound variants.
4. Validate prefixes, negative forms, important flags, empty values, and
   invalid arbitrary properties at parse time.
5. Port candidate printing/canonicalization internally so round-trip tests can
   compare semantic candidates even though no public JS-compatible API is
   required.
6. Add candidate fuzzing to guarantee parsing never panics.

### Relevant resources

- MoonBit: `candidate.mbt`, `candidate_wbtest.mbt`, `string_utils.mbt`
- Upstream:
  - `src/candidate.ts`
  - `src/candidate.test.ts`
  - `src/canonicalize-candidates.ts`
  - `src/utils/decode-arbitrary-value.ts`
  - `src/utils/infer-data-type.ts`
  - `src/utils/is-valid-arbitrary.ts`

## 4. Replace rendered-string utility composition with a complete internal AST

### Goal

Remove the main architectural limit on complex utilities, nested selectors,
at-root property declarations, compound variants, optimization, and source
maps.

### High-level implementation

1. Make candidate compilation return `Array[CssNode]` instead of a selector and
   rendered CSS string.
2. Add internal node forms equivalent to Tailwind's `Context` and `AtRoot`.
3. Represent generated `@property` rules and fallback declarations as nodes.
4. Apply variants by walking/mutating nodes rather than reparsing generated
   wrapper strings.
5. Render only once after sorting and optimization.
6. Preserve the existing public `Compiler::build(Array[String]) -> String`
   behavior throughout the refactor.
7. Split the current large compiler/utility files into cohesive package-local
   files as the AST boundary stabilizes.

### Relevant resources

- MoonBit: `css_ast.mbt`, `compiler.mbt`, `utilities.mbt`
- Upstream:
  - `src/ast.ts`
  - `src/walk.ts`
  - `src/compile.ts`
  - `src/design-system.ts`
- This step is a prerequisite for complete transforms, filters, gradients,
  scroll snap, space/divide utilities, and exact compound variants.

## 5. Complete variant coverage, compound compatibility, and variant ordering

### Goal

Accept and order the same variant graph as Tailwind, including nested compound
variants and variants that produce multiple rules.

### High-level implementation

1. Port the remaining pseudo-element variants:
   `first-letter`, `first-line`, `marker`, `selection`, `file`, `placeholder`,
   `backdrop`, `details-content`, `before`, and `after`.
2. Add missing state variants such as `user-valid` and `user-invalid`.
3. Complete arbitrary, group, peer, has, in, and not combinations, including
   named modifier movement and multi-branch custom variants.
4. Complete conditional negation for media, supports, and named container
   queries, including comma-condition rejection rules.
5. Implement compound capability checks instead of accepting combinations
   optimistically.
6. Port the complete upstream variant registration order and comparison rules.
7. Add differential cases for stacked variants and same-root deterministic
   ordering.

### Relevant resources

- MoonBit: variant code currently in `compiler.mbt`, plus
  `custom_variant.mbt`
- Upstream: `src/variants.ts`, `src/variants.test.ts`
- Important upstream test groups:
  - `variant order`
  - `sorting stacked min-* and max-* variants`
  - `move modifier of compound variant to sub-variant`

## 6. Complete `@theme`, prefix, reference-theme, and keyframe semantics

### Goal

Match how Tailwind stores, resolves, emits, and scopes design tokens.

### High-level implementation

1. Model all relevant theme options rather than storing only a flat map.
2. Implement `reference`, `inline`, `static`, and default emission behavior.
3. Track used variables through fallbacks and generated utility dependencies.
4. Implement wildcard namespace reset/removal semantics.
5. Implement CSS prefix configuration and candidate prefix validation.
6. Support theme-defined keyframes and emit only required animation data.
7. Complete nested theme-key resolution and ambiguity rules.
8. Add `@reference`/`theme(reference)` behavior without adding JS config
   loading.

### Relevant resources

- MoonBit: `theme.mbt`, `at_import.mbt`, `compiler.mbt`
- Upstream:
  - `src/theme.ts`
  - theme sections in `src/index.test.ts`
  - `src/prefix.test.ts`
  - `src/compat/apply-keyframes-to-theme.ts` for behavior only

## 7. Finish declaration-only and simple functional utility families

### Goal

Complete utilities that return ordinary declarations and do not require
generated property state or nested selectors.

### High-level implementation

1. Finish sizing, logical sizing, container sizing, spacing, scroll
   margin/padding, border spacing, order, z-index, flex, basis, columns, and
   line-clamp.
2. Add remaining simple typography, list, SVG, outline, decoration, opacity,
   blend-mode, isolation, object, and form-control utilities.
3. Use table-driven utility descriptors instead of continuing to grow one
   static match expression.
4. Implement strict validators for integer, number, percentage, ratio, and
   theme-only values.
5. Port each upstream utility test group as a dedicated MoonBit test file.

### Relevant resources

- MoonBit: `utilities.mbt`, `compiler_test.mbt`
- Upstream: `src/utilities.ts`, `src/utilities.test.ts`
- Suggested first remaining groups:
  - line clamp and columns;
  - logical inline/block sizing;
  - scroll margin/padding;
  - order and complete flex values;
  - border spacing.

## 8. Finish typography, borders, backgrounds, and color utilities

### Goal

Match Tailwind's overloaded utility roots, theme namespace precedence, color
fallbacks, opacity modifiers, and multi-declaration typography values.

### High-level implementation

1. Implement font family, font size/line-height modifiers, tracking, leading,
   text indent, text decoration style/thickness/offset, and font feature
   utilities.
2. Implement every border side/logical side, width/style/color, radius corner,
   divide, outline, and ring family.
3. Implement background color/image/position/size/repeat/clip/origin/attachment
   families.
4. Complete color parsing and fallback generation for modern color spaces and
   opacity modifiers.
5. Resolve overloaded roots such as `text-*`, `border-*`, `stroke-*`, and
   `outline-*` using the same type inference and theme priority as upstream.

### Relevant resources

- MoonBit: `utilities.mbt`, `value_parser.mbt`, `theme.mbt`
- Upstream:
  - typography, background, border, SVG, and color sections of
    `src/utilities.ts`
  - `src/utils/is-color.ts`
  - `src/utils/infer-data-type.ts`
  - `src/utils/replace-shadow-colors.ts`

## 9. Implement stateful utilities that require generated custom properties

### Goal

Support utilities whose declarations compose through Tailwind-owned custom
properties and `@property` registrations.

### High-level implementation

1. Add generated-property dependency tracking to the internal AST.
2. Implement transforms: translate, rotate, skew, scale, transform-style,
   transform-origin, and perspective.
3. Implement filters and backdrop filters.
4. Implement shadows, inset shadows, rings, ring offsets, and text shadows.
5. Implement gradients and background-position interpolation state.
6. Implement transition and animation utilities, including theme keyframes.
7. Implement touch-pan and complete scroll-snap strictness state.
8. Deduplicate property registrations and emit them in upstream order.

### Relevant resources

- Upstream:
  - stateful sections of `src/utilities.ts`
  - `src/property-order.ts`
  - `src/index.test.ts` sections for the `@property` polyfill
- Architectural prerequisite: step 4.

## 10. Implement selector-producing utilities and declaration expansion

### Goal

Support utilities that create nested selectors or expand into logical
declarations rather than returning a flat declaration list.

### High-level implementation

1. Implement `space-x/y`, divide, placeholder, file-selector, marker, and
   child-selector utility output.
2. Add at-root nodes for generated defaults used by those utilities.
3. Port declaration expansion for logical shorthands and browser-compatible
   fallback declarations.
4. Implement exact nesting optimization and selector merging.
5. Ensure important handling does not incorrectly mark internal custom
   properties.

### Relevant resources

- Upstream:
  - `src/expand-declaration.ts`
  - `src/expand-declaration.test.ts`
  - selector-producing sections of `src/utilities.ts`
  - `src/important.test.ts`
- MoonBit prerequisite: complete AST from step 4.

## 11. Complete `@apply`, `@utility`, `@custom-variant`, and `@variant`

### Goal

Match directive behavior, error reporting, cycle detection, and composition for
CSS-authored extensions.

### High-level implementation

1. Make `@apply` consume the same candidate/variant compiler as normal builds.
2. Support utilities that expand into nested rules and at-rules.
3. Implement exact dependency ordering and circular-application diagnostics.
4. Complete validation for static and functional `@utility` names/bodies.
5. Complete custom variant multi-branch, nested at-rule, and declaration
   behavior using AST substitution rather than rendered templates.
6. Complete stylesheet `@variant` substitution and compound lists.
7. Port upstream error cases, not only successful snapshots.

### Relevant resources

- MoonBit:
  - `apply.mbt`
  - `custom_utility.mbt`
  - `functional_utility.mbt`
  - `custom_variant.mbt`
- Upstream:
  - `src/apply.ts`
  - directive sections of `src/index.test.ts`
  - `src/variants.ts::substituteAtVariant`

## 12. Complete imports, sources, reference imports, and path/base propagation

### Goal

Match recursive stylesheet loading and metadata behavior for every CSS-only
import/source form.

### High-level implementation

1. Complete case-insensitive import parsing and all legal condition ordering.
2. Implement `@reference` and `@import ... reference`.
3. Propagate each nested file's base to `@source` metadata.
4. Preserve URL imports and reject invalid local import cycles with matching
   diagnostics.
5. Complete layer/supports/media wrapper merging.
6. Keep module/plugin loading callbacks absent or explicitly unsupported,
   because JS compatibility is excluded.

### Relevant resources

- MoonBit:
  - `at_import.mbt`
  - `stylesheet_loader.mbt`
  - `source_directive.mbt`
- Upstream: `src/at-import.ts`, `src/at-import.test.ts`

## 13. Implement AST optimization, declaration folding, and required polyfills

### Goal

Produce the same final CSS structure as the upstream `compile` path rather than
only semantically equivalent declarations.

### High-level implementation

1. Port relevant `optimizeAst` behavior: selector merging, empty-node removal,
   at-rule merging, declaration deduplication, and nesting flattening.
2. Implement constant folding and calc-expression canonicalization.
3. Implement the color-mix polyfill behavior used by v4.3.3.
4. Implement the required `@property` fallback/polyfill behavior.
5. Gate optional polyfills through MoonBit compile options matching the needed
   subset of upstream flags.
6. Add byte-for-byte differential cases before enabling each optimization.

### Relevant resources

- Upstream:
  - `src/ast.ts`
  - `src/constant-fold-declaration.ts`
  - `src/canonicalize-calc-expressions.ts`
  - polyfill sections of `src/index.test.ts`
- MoonBit: `css_ast.mbt`, future optimizer file.

## 14. Implement exact property and variant sorting

### Goal

Remove ad-hoc numeric ordering and match Tailwind deterministically for mixed
candidate lists, stacked variants, arbitrary values, and equal-property rules.

### High-level implementation

1. Port the upstream property-order table.
2. Compute variant order from the registered variant graph.
3. Port breakpoint comparison by unit, value, and fallback lexical ordering.
4. Track candidate property indices and declaration counts using the upstream
   comparison rules.
5. Add differential permutations: every fixture should produce identical CSS
   regardless of candidate discovery order.

### Relevant resources

- MoonBit: ordering logic in `compiler.mbt`
- Upstream:
  - `src/property-order.ts`
  - `src/sort.ts`
  - `src/sort.test.ts`
  - `src/utils/compare-breakpoints.ts`
  - ordering tests in `src/variants.test.ts`

## 15. Port the remaining upstream tests and add fuzz/property testing

### Goal

Turn the upstream test suite, minus explicit exclusions, into the acceptance
suite for the MoonBit implementation.

### High-level implementation

1. Port tests by subsystem into focused `*_test.mbt` and `*_wbtest.mbt` files.
2. Preserve invalid-input and error-message coverage.
3. Use the JS oracle for compile snapshots instead of manually copying large
   expected CSS blocks.
4. Add parser round-trip properties, candidate permutation properties, and
   incremental-build equivalence properties.
5. Add regression fixtures for every discovered drift.
6. Record excluded JS config/plugin tests in the compatibility manifest.

### Relevant resources

- All `src/*.test.ts` files in the v4.3.3 package
- Current MoonBit test files in the repository root
- Commands:
  - `moon test --target native -v`
  - `node tools/diff/compare.mjs`

## 16. Add source-map support if required by the final `compile` contract

### Goal

Decide and implement the source-map portion of compatibility only after the AST
and import pipeline preserve stable source spans.

### High-level implementation

1. Confirm the desired MoonBit `compile` options/result contract.
2. Preserve source IDs and spans through imports, substitutions, generated
   nodes, optimization, and rendering.
3. Port line tables and translation maps.
4. Emit decoded maps or a MoonBit-native equivalent without adding a JS API
   façade.
5. Add multi-file import and generated-utility mapping tests.

### Relevant resources

- Upstream: `src/source-maps/`, source-map tests, `DecodedSourceMap` in
  `src/index.ts`
- MoonBit: `SourceSpan` in `css_ast.mbt`
- This step can remain deferred if the agreed public `compile` contract returns
  CSS only.

### Decision (step 1 outcome): deferred by contract

The agreed public MoonBit surface is exactly `compile(css) -> Compiler` and
`Compiler::build(Array[String]) -> String`, which returns CSS only. Upstream's
`buildSourceMap()`/`DecodedSourceMap` are only produced for the JavaScript
`compile(css, { from })` result, which is intentionally not modeled here (see
`UPSTREAM.md` and the scope note at the top of this plan). No public API
consumes a source map, so emitting one would be dead, untestable surface.

The AST groundwork the later steps depend on is already in place: every
`CssNode` carries a `SourceSpan`, and imports thread each file's base through
`Context` nodes, so real byte spans can be recorded by the parser if the
contract ever grows a source-map result. Until the contract requires it, this
step stays deferred rather than shipping an unused subsystem. If it is later
required: record real spans in `parse_css`, thread them through the substitution
and optimization passes (which already rebuild nodes span-by-span), and add a
`buildSourceMap`-style method plus multi-file import and generated-utility
mapping tests.

## 17. Run the final compatibility, performance, and release audit

### Goal

Declare compatibility only when the supported CSS-only compiler surface is
measurably stable and documented.

### High-level implementation

1. Run every non-excluded upstream fixture through the differential harness.
2. Test incremental builds against fresh compilers for equivalence.
3. Benchmark large candidate sets, parser-heavy stylesheets, and repeated
   builds; remove accidental quadratic paths.
4. Validate native, wasm-gc, and JS MoonBit backends even though no JS
   compatibility layer is exposed.
5. Run formatting, warning-enabled checks, tests, documentation tests, and
   `moon info`.
6. Freeze the v4.3.3 compatibility manifest and document known exclusions.
7. Review the public API so the package exposes the requested compile surface
   without leaking internal AST/parser types unnecessarily.

### Relevant resources

- `README.mbt.md`
- `UPSTREAM.md`
- `pkg.generated.mbti`
- Final commands:

  ```sh
  moon fmt
  moon check --target native --warn-list +unnecessary_annotation
  moon check --target wasm-gc --warn-list +unnecessary_annotation
  moon check --target js --warn-list +unnecessary_annotation
  moon test --target native -v
  node tools/diff/compare.mjs
  moon info
  ```
