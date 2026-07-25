// The editor's view of the MoonBit compiler.
//
// Everything expensive happens once at startup: load the module, then hand it
// the margaui bundle (~280 KB of CSS across 78 files) and keep the handle. After
// that a keystroke only crosses the boundary as `(handle, html)` and comes back
// as a JSON reply — no re-parsing of the bundle, no marshalling layer.
//
// Two compile modes, and the difference matters:
//
//   compile(html)             a fresh Compiler each time. The import graph is
//                             re-read, so output tracks the input exactly and
//                             shrinks again when a class is deleted. This is the
//                             default because the size the editor reports has to
//                             be the size of *this* HTML.
//   incremental.build(html)   one long-lived Compiler. The graph parse is paid
//                             once, but `Compiler::build` accumulates candidates,
//                             so deleted classes keep their rules forever.
import { loadJsFallback, loadWasm, supportsJsStringBuiltins } from './wasm.js'

const EXPORTS = [
  'build_info',
  'bundle_load',
  'bundle_free',
  'compile_html',
  'compile_html_json',
  'scan_html_json',
  'compiler_open',
  'compiler_build_html',
  'compiler_close',
]

export async function createCompiler({
  wasmUrl = 'assets/twffi.wasm',
  jsFallbackUrl = 'assets/twffi.js',
  bundleUrl = 'assets/margaui-bundle.json',
  onProgress = () => {},
} = {}) {
  let backend = 'wasm-gc'
  let exports
  if (supportsJsStringBuiltins()) {
    onProgress('loading compiler (wasm-gc)')
    exports = await loadWasm(wasmUrl)
  } else {
    // No JS String Builtins: the wasm-gc module cannot be instantiated here, so
    // fall back to the js build. Same exports, same contracts, larger download —
    // which is why it is fetched only when it is actually needed.
    backend = 'js'
    onProgress('loading compiler (js fallback)')
    exports = await loadJsFallback(jsFallbackUrl)
  }
  for (const name of EXPORTS) {
    if (typeof exports[name] !== 'function') {
      throw new Error(`compiler module is missing ${name}() — stale artifact?`)
    }
  }

  const info = JSON.parse(exports.build_info())

  onProgress('loading margaui')
  const response = await fetch(bundleUrl)
  if (!response.ok) {
    throw new Error(`failed to fetch ${bundleUrl}: ${response.status}`)
  }
  // Handed over as raw text: parsing 280 KB of JSON in MoonBit is part of what
  // the bundle handle exists to do once, and doing it in JS first would only add
  // a second parse.
  const bundleText = await response.text()
  const bundleBytes = new TextEncoder().encode(bundleText).length

  const wallStart = performance.now()
  const loaded = expect(exports.bundle_load(bundleText))
  const bundleWallMs = performance.now() - wallStart
  const bundle = loaded.bundle

  let warmHandle = null

  function expect(reply) {
    const parsed = JSON.parse(reply)
    if (parsed.ok !== true) {
      throw new Error(parsed.error ?? 'compiler returned an unknown failure')
    }
    return parsed
  }

  /** Time a call in JS as well, so the marshalling gap stays visible. */
  function timed(call) {
    const started = performance.now()
    const reply = call()
    const wallMs = performance.now() - started
    return { ...expect(reply), wallMs }
  }

  return {
    backend,
    info,
    bundle: {
      imports: loaded.counts.imports,
      importChars: loaded.counts.importChars,
      cssChars: loaded.counts.cssChars,
      bytes: bundleBytes,
      loadMs: bundleWallMs,
    },

    /** Candidates only — microseconds, for deciding whether a compile is needed. */
    scan(html) {
      return timed(() => exports.scan_html_json(html))
    },

    /** Fresh compiler, exact output. */
    compile(html) {
      return timed(() => exports.compile_html(bundle, html))
    },

    /**
     * Compile `runs` times and report the median and minimum, yielding between
     * iterations so the page stays responsive.
     *
     * A single measurement is not worth showing: `performance.now()` is clamped
     * (5 µs, coarser under some privacy settings) and the first call pays JIT
     * warm-up. The median of ten is a number a visitor can compare.
     */
    async benchmark(html, runs = 10) {
      const samples = []
      for (let index = 0; index < runs; index += 1) {
        samples.push(this.compile(html).timings.totalUs)
        await new Promise((resolve) => setTimeout(resolve, 0))
      }
      const sorted = [...samples].sort((a, b) => a - b)
      return {
        runs,
        samples,
        medianUs: sorted[Math.floor(sorted.length / 2)],
        minUs: sorted[0],
      }
    },

    incremental: {
      open() {
        if (warmHandle !== null) return null
        const opened = timed(() => exports.compiler_open(bundle))
        warmHandle = opened.compiler
        return opened
      },
      build(html) {
        if (warmHandle === null) throw new Error('incremental compiler is not open')
        return timed(() => exports.compiler_build_html(warmHandle, html))
      },
      close() {
        if (warmHandle === null) return
        exports.compiler_close(warmHandle)
        warmHandle = null
      },
      get isOpen() {
        return warmHandle !== null
      },
    },

    dispose() {
      this.incremental.close()
      exports.bundle_free(bundle)
    },
  }
}
