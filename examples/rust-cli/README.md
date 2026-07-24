# `twc` — Tailwind compiler CLI, powered by the tw-mb **WASM component**

A small Rust CLI demo that compiles Tailwind CSS v4 utility classes to stdout by
calling the [`marianoguerra/tailwindcss`](../../) MoonBit compiler built as a
**WebAssembly Component**. All the compilation happens inside the wasm module;
the Rust program is just the host (arg parsing + JSON request + `wasmtime`).

```
$ twc --css '@theme{--spacing:.25rem;}@tailwind utilities;' flex p-4
:root, :host {
  --spacing: .25rem;
}
.flex {
  display: flex;
}
.p-4 {
  padding: calc(var(--spacing) * 4);
}
```

## Why a component (and not a plain `.wasm`)?

MoonBit's `String`/`Bytes` have **no stable linear-memory ABI**, so a raw
`compile_css(String, String) -> String` export can't be driven from a generic
wasm host. The supported way to pass strings across the boundary is the
[WebAssembly Component Model](https://component-model.bytecodealliance.org/):
a WIT interface ([`wit/world.wit`](wit/world.wit)) + `wit-bindgen`-generated
MoonBit glue, assembled into a component with `wasm-tools`, and consumed in Rust
via `wasmtime`'s `component::bindgen!`.

The component simply re-exports the existing, already-tested
[`ffi`](../../ffi/lib.mbt) functions (`compile_css` / `compile_css_json`).

## Prerequisites

- Rust / Cargo (host)
- [MoonBit](https://www.moonbitlang.com/) `moon` toolchain (builds the wasm)
- [`wasm-tools`](https://github.com/bytecodealliance/wasm-tools) (assembles the component)
- [`wit-bindgen`](https://github.com/bytecodealliance/wit-bindgen) with the
  `moonbit` generator — **only** needed if you change `wit/world.wit`

## Build

Two steps: build the wasm component, then build the Rust CLI.

```sh
./build-component.sh      # -> tw-compiler.component.wasm
cargo build --release     # -> target/release/twc
```

`build-component.sh` runs `moon build --target wasm --release`, then
`wasm-tools component embed --encoding utf16` (MoonBit strings are UTF-16) and
`wasm-tools component new`. The CLI finds the component via the
`TW_COMPILER_WASM` env var, defaulting to the sibling
`tw-compiler.component.wasm`.

## Usage

```
twc [options] <class>...

  <class>...            utility class names to generate (e.g. flex p-4 hover:bg-black)
  --bundle <file>       JSON {path:content} import map (see "Bundles" below)
  --css <string>        entry stylesheet source (default: `@import "tailwindcss";`)
  --css-file <file>     read the entry stylesheet from a file
  --polyfills <0..3>    0=none 1=@property 2=color-mix 3=all (default 3)
  --from <path>         logical path of the entry stylesheet (default input.css)
  -h, --help            show this help
```

### Inline (no imports)

```sh
twc --css '@theme{--spacing:.25rem;--color-black:#000;}@tailwind utilities;' \
    flex p-4 hover:bg-black
```

### Bundles (resolving `@import`)

There is no filesystem access inside the wasm, so any `@import` must be supplied
as an in-memory map. Produce one with tw-mb's native CLI, which walks the
`@import` graph on disk and emits a JSON `{path: content}` map (the imported
files only — the entry is passed separately):

```sh
# from the repo root
moon run ./cmd/tailwindcss --target native -- \
    bundle -i examples/rust-cli/demo/entry.css -o examples/rust-cli/demo/bundle.json
```

Then compile against it (the sample [`demo/`](demo/) files are included):

```sh
twc --bundle demo/bundle.json --css-file demo/entry.css --from entry.css \
    p-2 hover:bg-black text-white
```

The generated CSS is byte-identical to the native `tailwindcss` CLI for the same
input and candidates.

## Layout

```
wit/world.wit          the component interface (WIT)
component/             MoonBit component module (wit-bindgen glue + impl.mbt)
build-component.sh     wasm build pipeline -> tw-compiler.component.wasm
src/main.rs            the Rust host CLI
demo/                  sample stylesheet + bundle.json
```
