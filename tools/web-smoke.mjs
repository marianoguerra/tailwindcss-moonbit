// Smoke test for the showcase site's compiler module.
//
// Runs the *same* instantiation the browser uses (web/site/js/wasm.js) against
// both artifacts, so a broken wasm-gc string boundary or a missing host import
// fails here rather than in a browser tab:
//
//   node tools/web-smoke.mjs            # wasm-gc, then the js fallback
//   node tools/web-smoke.mjs --js-only  # skip wasm-gc
//
// Build the artifacts first (`just build-web`, `just build-web-fallback`).
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const jsOnly = process.argv.includes('--js-only')
const wasmArtifact = join(root, '_build/wasm-gc/release/build/marianoguerra/tailwindcss-web/ffi/ffi.wasm')
const jsArtifact = join(root, '_build/js/release/build/marianoguerra/tailwindcss-web/ffi/ffi.js')
const bundlePath = join(root, 'web/site/assets/margaui-bundle.json')

const { instantiateWasm, loadJsFallback, supportsJsStringBuiltins } = await import(
  pathToFileURL(join(root, 'web/site/js/wasm.js')).href
)

let failures = 0

function check(label, condition, detail = '') {
  if (condition) {
    console.log(`  ok   ${label}`)
  } else {
    failures += 1
    console.log(`  FAIL ${label}${detail ? ` — ${detail}` : ''}`)
  }
}

// An inline theme keeps this test independent of the generated margaui assets;
// the margaui graph is exercised separately below when it has been generated.
const INLINE_CSS = '@theme { --spacing: 0.25rem; } @tailwind utilities;\n'

function exercise(backend, exports) {
  console.log(`\n${backend}`)

  const info = JSON.parse(exports.build_info())
  check('build_info reports versions', typeof info.compiler === 'string' && !!info.html, JSON.stringify(info))

  // A bare table fragment: the classes survive only because the scanner wraps
  // the input in <template> before parsing.
  const scan = JSON.parse(
    exports.scan_html_json('<tr class="hover"><td class="p-2">cell</td></tr>'),
  )
  check('scan finds table-fragment classes', scan.ok && scan.candidates.join(' ') === 'hover p-2', JSON.stringify(scan.candidates))
  check('scan reports counts', scan.counts.elements === 2 && scan.counts.classAttrs === 2, JSON.stringify(scan.counts))
  check('scan reports a timing', typeof scan.timings.scanUs === 'number')

  // The wrapper must never leak into the candidate list on unfinished input.
  const truncated = JSON.parse(exports.scan_html_json('<div class='))
  check('truncated input yields no candidates', truncated.candidates.length === 0, JSON.stringify(truncated.candidates))

  const compiled = JSON.parse(
    exports.compile_html_json(
      JSON.stringify({
        html: '<div class="flex gap-2"><span class="hidden">x</span></div>',
        css: INLINE_CSS,
        extra_candidates: ['block'],
      }),
    ),
  )
  check('compile succeeds', compiled.ok === true, compiled.error)
  check('compile finds candidates', compiled.candidates.join(' ') === 'flex gap-2 hidden block', JSON.stringify(compiled.candidates))
  check('compile emits CSS for them', /display: flex/.test(compiled.css) && /gap: calc/.test(compiled.css), JSON.stringify(compiled.css.slice(0, 120)))
  check('compile reports output size', compiled.counts.cssChars === compiled.css.length)
  check('compile times every stage', ['scanUs', 'compileUs', 'buildUs', 'totalUs'].every((key) => typeof compiled.timings[key] === 'number'), JSON.stringify(compiled.timings))

  const broken = JSON.parse(
    exports.compile_html_json(JSON.stringify({ html: '<div class="flex">', css: '@import "missing.css";' })),
  )
  check('a bad request reports ok:false', broken.ok === false && typeof broken.error === 'string', JSON.stringify(broken))

  // Handles cross the boundary as plain integers, so this also proves numeric
  // arguments survive the wasm-gc ABI alongside strings.
  const loaded = JSON.parse(exports.bundle_load(JSON.stringify({ css: INLINE_CSS })))
  check('bundle_load returns a handle', loaded.ok === true && Number.isInteger(loaded.bundle), JSON.stringify(loaded))
  const cold = JSON.parse(exports.compile_html(loaded.bundle, '<div class="flex gap-2">'))
  check('compile_html uses the handle', cold.ok === true && /display: flex/.test(cold.css), cold.error)
  const shrunk = JSON.parse(exports.compile_html(loaded.bundle, '<div class="flex">'))
  check('cold output shrinks when a class is removed', !/gap: calc/.test(shrunk.css))
  const opened = JSON.parse(exports.compiler_open(loaded.bundle))
  check('compiler_open reports its graph parse', opened.ok === true && typeof opened.timings.compileUs === 'number', opened.error)
  const warm = JSON.parse(exports.compiler_build_html(opened.compiler, '<div class="flex">'))
  check('warm build skips the graph parse', warm.ok === true && warm.timings.compileUs === undefined, JSON.stringify(warm.timings))
  exports.compiler_close(opened.compiler)
  exports.bundle_free(loaded.bundle)
  check('freed handles are rejected', JSON.parse(exports.compile_html(loaded.bundle, '')).ok === false)

  if (!existsSync(bundlePath)) {
    console.log('  skip margaui bundle (run `just web-assets` to generate it)')
    return
  }

  // The real thing: margaui's whole import graph, compiled the way the site does.
  const margaui = JSON.parse(exports.bundle_load(readFileSync(bundlePath, 'utf8')))
  check('margaui bundle loads', margaui.ok === true, margaui.error)
  if (!margaui.ok) return
  const real = JSON.parse(
    exports.compile_html(
      margaui.bundle,
      '<button class="btn btn-primary">Go</button><div class="card">c</div>',
    ),
  )
  check('margaui bundle compiles', real.ok === true, real.error)
  check('margaui bundle emits component CSS', /\.btn\b/.test(real.css ?? ''), `${(real.css ?? '').length} chars`)
  if (real.ok) {
    console.log(
      `  info margaui graph: ${real.counts.imports} imports / ${real.counts.importChars} chars in` +
        ` -> ${real.counts.cssChars} chars out` +
        ` (scan ${(real.timings.scanUs / 1000).toFixed(2)}ms,` +
        ` compile ${(real.timings.compileUs / 1000).toFixed(2)}ms,` +
        ` build ${(real.timings.buildUs / 1000).toFixed(2)}ms)`,
    )
  }
  exports.bundle_free(margaui.bundle)
}

if (!jsOnly) {
  if (!existsSync(wasmArtifact)) {
    console.error(`missing ${wasmArtifact} — run \`just build-web\``)
    process.exit(1)
  }
  if (!supportsJsStringBuiltins()) {
    console.log('\nwasm-gc: SKIPPED — this engine lacks JS String Builtins')
  } else {
    exercise('wasm-gc', await instantiateWasm(readFileSync(wasmArtifact)))
  }
}

if (!existsSync(jsArtifact)) {
  console.error(`missing ${jsArtifact} — run \`just build-web-fallback\``)
  process.exit(1)
}
exercise('js (fallback)', await loadJsFallback(pathToFileURL(jsArtifact).href))

console.log(failures === 0 ? '\nall checks passed' : `\n${failures} check(s) failed`)
process.exit(failures === 0 ? 0 : 1)
