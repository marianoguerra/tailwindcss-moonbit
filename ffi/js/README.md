# JavaScript / Wasm library

An ergonomic, dependency-free wrapper around the MoonBit Tailwind compiler for
JS and Wasm hosts (Node, browsers, bundlers). It compiles Tailwind v4 CSS fully
in memory — no filesystem access — so any `@import` is resolved from an
in-memory `{ path: content }` map you provide.

## Build

The wrapper (`index.mjs`) imports the compiled MoonBit module as a peer file
`./ffi.js`. Build one of the supported backends and copy it next to the wrapper:

```sh
# JS backend (Node / browsers / bundlers)
moon build --target js ffi --release
cp _build/js/release/build/ffi/ffi.js ffi/js/ffi.js

# or the wasm-gc backend (GC-capable Wasm host)
moon build --target wasm-gc ffi --release
# load _build/wasm-gc/release/build/ffi/ffi.wasm with your Wasm runtime
```

The exported functions are `compile_css_json` (structured, recommended) and
`compile_css` (inline CSS only, legacy).

## Usage

```js
import { compile } from './index.mjs'

const { css } = compile({
  input: '@import "base.css"; @tailwind utilities;',
  candidates: ['flex', 'hover:bg-black'],
  imports: { 'base.css': '@theme { --color-black: #000; }' },
  from: 'input.css',
  polyfills: 3, // 0=none, 1=@property, 2=color-mix, 3=all
})

console.log(css)
```

`compile` throws on failure. Candidate discovery is the caller's
responsibility: pass the class names you want generated in `candidates` (this
library does not scan content files).

## Raw export

If you prefer to skip the wrapper, call the export directly. It takes a JSON
request string and returns a JSON result string:

```js
import { compile_css_json } from './ffi.js'

const result = JSON.parse(compile_css_json(JSON.stringify({
  css: '@theme { --color-black: #000; } @tailwind utilities;',
  candidates: ['flex'],
})))
// { ok: true, css: "..." }  |  { ok: false, error: "..." }
```
