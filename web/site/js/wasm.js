// Loading the MoonBit compiler module.
//
// The primary artifact is the wasm-gc build. It is linked with
// `use-js-builtin-string`, so a MoonBit `String` *is* a JS string: the exported
// functions take and return strings directly, with no marshalling layer. That
// requires two compile options the browser must be told about:
//
//   builtins: ['js-string']        -> satisfies the `wasm:js-string` imports
//                                    (length, charCodeAt, equals, concat,
//                                    fromCodePoint, fromCharCodeArray)
//   importedStringConstants: '_'   -> satisfies the ~4500 `(import "_" "...")`
//                                    string-constant globals in the binary
//
// Without JS String Builtins (Chrome <130, Firefox <134, Safari <18.4) the wasm
// module cannot be instantiated at all, so `loadJsFallback` pulls the js-backend
// build instead. Same export names, same JSON contracts, ~1.3x the transfer size.
//
// This module deliberately takes bytes rather than URLs so the node smoke test
// can exercise the exact same instantiation the browser uses.

/** Compile options required by the wasm-gc artifact. */
export const COMPILE_OPTIONS = {
  builtins: ['js-string'],
  importedStringConstants: '_',
}

/**
 * Host functions the module imports.
 *
 * `moonbitlang/core/bench`'s clock is an import on wasm targets, which is what
 * lets the compiler time its own stages instead of trusting the caller. The
 * timestamp is opaque to MoonBit (`externref`), so a plain number is fine.
 */
export const HOST_IMPORTS = {
  __moonbit_time_unstable: {
    instant_now: () => performance.now(),
    instant_elapsed_as_secs_f64: (started) => (performance.now() - started) / 1000,
  },
}

/** Whether this engine can run the wasm-gc artifact. */
export function supportsJsStringBuiltins() {
  try {
    // The smallest possible module: a bare header. Compiling it with the options
    // throws on engines that do not recognise them.
    new WebAssembly.Module(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0]), COMPILE_OPTIONS)
    return true
  } catch {
    return false
  }
}

/**
 * Instantiate the wasm-gc artifact from bytes.
 *
 * @param {BufferSource} bytes
 * @returns {Promise<Record<string, Function>>} the module's exports
 */
export async function instantiateWasm(bytes) {
  const { instance } = await WebAssembly.instantiate(bytes, HOST_IMPORTS, COMPILE_OPTIONS)
  return instance.exports
}

/**
 * Instantiate the wasm-gc artifact from a URL, streaming when the server sends
 * `application/wasm` and falling back to a buffered compile when it does not.
 *
 * @param {string} url
 * @returns {Promise<Record<string, Function>>} the module's exports
 */
export async function loadWasm(url) {
  const response = await fetch(url)
  if (!response.ok) {
    throw new Error(`failed to fetch ${url}: ${response.status} ${response.statusText}`)
  }
  if (response.headers.get('content-type') === 'application/wasm') {
    const { instance } = await WebAssembly.instantiateStreaming(
      response,
      HOST_IMPORTS,
      COMPILE_OPTIONS,
    )
    return instance.exports
  }
  return instantiateWasm(await response.arrayBuffer())
}

/**
 * Load the js-backend fallback module, which needs no imports or compile options.
 *
 * The URL is resolved against the document rather than this module, so callers
 * can pass the same page-relative path they pass for the wasm artifact —
 * `import()` would otherwise resolve it relative to js/.
 *
 * @param {string} url
 * @returns {Promise<Record<string, Function>>} the module's exports
 */
export async function loadJsFallback(url) {
  const base = typeof document === 'undefined' ? import.meta.url : document.baseURI
  return await import(new URL(url, base).href)
}
