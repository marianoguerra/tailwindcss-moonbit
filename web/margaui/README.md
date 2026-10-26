# margaui-css — Tailwind + margaui as one function

`margaui-css.wasm` is this Tailwind CSS v4 compiler with the
[margaui](https://github.com/marianoguerra/margaui) component library built in.
It exports exactly one function:

```ts
css(classes: string): string
```

Pass whitespace-separated class names; get back the CSS they need. The module
**imports nothing from the host**, so it cannot reach the network, storage, the
DOM, timers or randomness. That is enforced by WebAssembly itself, not by trust
in this code: a module can only affect the outside world through the imports
its host hands it, and this one takes none.

## Use it without the MoonBit toolchain

Every [release](https://github.com/marianoguerra/tailwindcss-moonbit/releases)
carries three files:

| file | what |
|---|---|
| `margaui-css.wasm` | the module, ~600 KB (~180 KB gzipped) |
| `margaui-css.wasm.sha256` | its checksum |
| `demo.html` | a live demo; its source is the integration docs |

The newest module is always at
<https://github.com/marianoguerra/tailwindcss-moonbit/releases/latest/download/margaui-css.wasm>;
pin a version with `/releases/download/vX.Y.Z/margaui-css.wasm`.

### Browser

```js
const bytes = await (await fetch('margaui-css.wasm')).arrayBuffer()
const { instance } = await WebAssembly.instantiate(bytes, {},
  { builtins: ['js-string'], importedStringConstants: '_' })
const css = instance.exports.css

css('btn btn-primary flex')  // -> CSS string
```

### Node

```js
import { readFileSync } from 'node:fs'

const { instance } = await WebAssembly.instantiate(readFileSync('margaui-css.wasm'), {},
  { builtins: ['js-string'], importedStringConstants: '_' })
const css = instance.exports.css
```

The empty `{}` is the import object: there is nothing to supply. The third
argument enables [JS String Builtins](https://github.com/WebAssembly/js-string-builtins),
which make the module's strings real JS strings, so `css` takes and returns them
with no glue:

- `builtins: ['js-string']` provides string operations (length, concat, charCodeAt, …)
- `importedStringConstants: '_'` provides the string literals compiled into the module

### Requirements

JS String Builtins: Chrome 130+, Firefox 134+, Safari 18.4+, Node 24+. Older
engines reject the module at compile time.

## Try the demo

It is live at <https://marianoguerra.github.io/tailwindcss-moonbit/margaui-css/demo.html>,
built from `main`. To run a released copy locally, put `demo.html` and
`margaui-css.wasm` in one folder and serve it (browsers do not let `fetch` read
`file://` URLs):

```sh
python3 -m http.server 8000   # open http://localhost:8000/demo.html
```

View its source for the whole integration, and open the console for the security
checks below.

## Check the sandbox yourself

```js
const module = await WebAssembly.compile(bytes, { builtins: ['js-string'], importedStringConstants: '_' })
WebAssembly.Module.imports(module)  // []  — nothing for a host to provide
WebAssembly.Module.exports(module)  // [{ name: 'css', kind: 'function' }]  — no memory, tables or globals
```

`demo.html` goes further: it reads the raw import section from the bytes and
shows it holds only the six `wasm:js-string` built-ins and string constants,
instantiates with a frozen empty import object, and checks that calls do not
affect each other. Compare its logged SHA-256 with `margaui-css.wasm.sha256`.

## Behaviour

- **Input** is class names separated by spaces or newlines, not HTML. Finding
  classes in your templates is up to you.
- **Unknown classes are ignored**, as in Tailwind; `css('')` returns the base
  styles alone.
- **Output depends only on the input.** The first call parses margaui (~70 ms);
  later calls reuse that parse and take a few milliseconds, but each one renders
  only the classes it was given.
- **Themes are not included.** Add margaui's theme stylesheets yourself.
- Errors come back as a CSS comment (`/* tailwindcss compile error: … */`), so
  `css` always returns a string.

## Building it from source

```sh
just build-margaui   # -> web/margaui/margaui-css.wasm
just margaui-smoke   # checks the boundary and the output
just margaui-demo    # serves this folder at http://localhost:8000/demo.html
just margaui-gen     # re-embed the bundle after `just web-assets` refreshes it
```

| file | what |
|---|---|
| `lib.mbt` | the `css` function |
| `bundle_data.mbt` | the margaui stylesheets as string literals; generated, committed |
| `gen.mjs` | writes `bundle_data.mbt` from `../site/assets/margaui-bundle.json` |
| `demo.html` | the demo page |
| `moon.pkg` | exports only `css`, linked with `use-js-builtin-string` |
