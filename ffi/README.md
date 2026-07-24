# `ffi` — callable JS / Wasm entry point

This package links the `mariano/tailwindcss` compiler into a standalone,
callable module for non-native hosts. It exports a single function:

```
compile_css(css : String, candidates : String) -> String
```

- `css` — the input stylesheet source. This runs fully **in memory** with no
  filesystem access, so `@import "tailwindcss"` (and any other `@import`) cannot
  be resolved here. Provide inline input, e.g.
  `@theme { --spacing: 0.25rem; } @tailwind utilities;`.
- `candidates` — a newline-separated list of utility class names to generate.
- returns the generated CSS. On a compile error the return value is a
  `/* ... */` CSS comment (the host always gets a string, never a throw).

## Targets

Supported: **`js`** and **`wasm`** (`supported_targets = "-all+js+wasm"`).

`wasm-gc` is intentionally excluded: driving the compiler's async `compile`
entry point requires `moonbitlang/async`'s `run_async_main`, which the library
provides for native / wasm / js but **not** wasm-gc (its event loop is only a
stub there). The native target is already covered by the `cmd/tailwindcss` CLI.

## Build

```sh
moon build --release --target js     # -> _build/js/release/build/ffi/ffi.js   (ESM)
moon build --release --target wasm   # -> _build/wasm/release/build/ffi/ffi.wasm
```

## Use from Node (js target)

```js
import { compile_css } from "./_build/js/release/build/ffi/ffi.js";

const css = "@theme { --spacing: 0.25rem; } @tailwind utilities;";
const out = compile_css(css, "flex\np-4\nmx-2\nhidden");
console.log(out);
```

The `wasm` artifact exports `compile_css` as well, but its `moonbitlang/async`
event loop pulls in a host-import surface (thread pool, event bus, fs, time),
so it needs a WASI-style host environment rather than a bare browser instantiate.
For browser/Node use, prefer the `js` artifact.
