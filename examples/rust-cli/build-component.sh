#!/usr/bin/env bash
# Build the tw-mb Tailwind compiler into a WebAssembly Component that the Rust
# CLI (see ./src/main.rs) loads via wasmtime.
#
# Pipeline:
#   1. moon build --target wasm         -> a core wasm module (gen.wasm) whose
#                                          exports match the WIT world.
#   2. wasm-tools component embed        -> embed the WIT (utf16, MoonBit strings
#                                          are UTF-16) into the core module.
#   3. wasm-tools component new          -> lift the core module into a component.
#
# Regenerating the MoonBit glue from wit/world.wit (only needed if the WIT
# changes) is a separate one-off step, kept out of this script so the checked-in
# component/ implementation is not clobbered:
#   wit-bindgen moonbit wit/world.wit --out-dir component --derive-error
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

core="component/_build/wasm/release/build/gen/gen.wasm"
out="tw-compiler.component.wasm"

echo ">> moon build --target wasm --release"
( cd component && moon build --target wasm --release )

echo ">> wasm-tools component embed (utf16)"
wasm-tools component embed wit "$core" --encoding utf16 -o core.embed.wasm

echo ">> wasm-tools component new"
wasm-tools component new core.embed.wasm -o "$out"
rm -f core.embed.wasm

echo ">> component interface:"
wasm-tools component wit "$out"

echo ">> wrote $here/$out"
