# `ffi` — callable JS / Wasm entry point

This package links the `marianoguerra/tailwindcss` compiler into a standalone,
callable module for non-native hosts. It exports two functions:

```
compile_css(css : String, candidates : String) -> String
compile_css_json(request : String) -> String
```

- `compile_css` — `css` is the input stylesheet source and `candidates` is a
  newline-separated list of class names. It runs fully in memory with no
  filesystem access and no `imports` map, so every `@import` is unresolvable
  here: provide inline input, e.g.
  `@theme { --spacing: 0.25rem; } @tailwind utilities;`. Returns the generated
  CSS; on a compile error the return value is a `/* … */` CSS comment, so the
  host always gets a string and never a throw.
- `compile_css_json` — the structured entry point: a JSON request
  `{css, candidates, imports, base, from, polyfills}` in, `{"ok":true,"css":…}`
  or `{"ok":false,"error":…}` out. `imports` is a path → content map, which is
  how a whole `@import` graph is compiled without a filesystem; the CLI's
  `bundle` mode produces one. See the doc comments in `lib.mbt`.

Both run through `compile_sync`, so they need no async runtime and work on every
backend here.

## Targets

`supported_targets = "-all+js+wasm+wasm-gc"` — native is covered by the
`cmd/tailwindcss` CLI instead.

## Build

Build outputs are namespaced by module, because `moon.work` makes this repo a
workspace (the showcase site in `web/` is the second module):

```sh
moon build --release --target js       # -> _build/js/release/build/marianoguerra/tailwindcss/ffi/ffi.js  (ESM)
moon build --release --target wasm-gc  # -> _build/wasm-gc/release/build/marianoguerra/tailwindcss/ffi/ffi.wasm
moon build --release --target wasm     # -> _build/wasm/release/build/marianoguerra/tailwindcss/ffi/ffi.wasm
just build-npm                         # js build, copied to ffi/js/ffi.js for the npm package
```

## Use from Node (js target)

```js
import { compile_css } from "./_build/js/release/build/marianoguerra/tailwindcss/ffi/ffi.js";

const css = "@theme { --spacing: 0.25rem; } @tailwind utilities;";
const out = compile_css(css, "flex\np-4\nmx-2\nhidden");
console.log(out);
```

`ffi/js/` wraps that build as the `@marianoguerra/tailwindcss` npm package, with
a friendlier `compile({ input, candidates, imports })` signature.

## Use from a browser (wasm-gc)

The `wasm-gc` artifact here exports MoonBit strings as `(array (mut i16))`, which
JavaScript cannot construct — so it is meant for hosts that speak that ABI (the
WASM component in `examples/rust-cli/`, for instance), not for a bare browser
`instantiate`. For browsers, either use the `js` artifact, or link with
`use-js-builtin-string` so `String` becomes a real JS string: `web/ffi` does
exactly that and `web/site/js/wasm.js` shows the host side. See
[`web/README.md`](../web/README.md).
