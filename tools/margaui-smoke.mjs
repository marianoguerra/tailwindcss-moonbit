// Smoke test for the single-function margaui build (web/margaui).
//
// The point of that build is that it can do nothing but map classes to CSS, so
// this checks the boundary as well as the output: the module must import nothing
// from the host and export nothing but `css`.
//
//   node tools/margaui-smoke.mjs
//
// Build it first (`just build-margaui`).
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const artifact = join(root, '_build/wasm-gc/release/build/marianoguerra/tailwindcss-web/margaui/margaui.wasm')
const COMPILE_OPTIONS = { builtins: ['js-string'], importedStringConstants: '_' }

let failures = 0

function check(label, condition, detail = '') {
  if (condition) {
    console.log(`  ok   ${label}`)
  } else {
    failures += 1
    console.log(`  FAIL ${label}${detail ? ` — ${detail}` : ''}`)
  }
}

if (!existsSync(artifact)) {
  console.error(`missing ${artifact} — run \`just build-margaui\``)
  process.exit(1)
}

const module = new WebAssembly.Module(readFileSync(artifact), COMPILE_OPTIONS)
const imports = WebAssembly.Module.imports(module)
const exportNames = WebAssembly.Module.exports(module).map((entry) => entry.name)
check('imports nothing from the host', imports.length === 0, JSON.stringify(imports))
check('exports only css', exportNames.join(',') === 'css', exportNames.join(','))

// An empty import object: anything the module needed would fail right here.
const { css } = new WebAssembly.Instance(module, {}).exports

const button = css('btn btn-primary')
check('emits margaui components', button.includes('.btn-primary'))
// Match selectors, not declarations: margaui's base layer already says
// `display: flex` and `text-decoration-line: underline` on its own.
check('emits tailwind utilities', css('underline').includes('.underline {'))
check('accepts newlines and repeated spaces', css('  flex\n\nhidden ') === css('flex hidden'))

// The parsed graph is cached between calls; the output must not be.
css('flex hidden underline')
check('a repeated call is identical', css('btn btn-primary') === button)
check('deleted classes disappear', !css('btn').includes('.underline {'))

console.log(failures === 0 ? '\nall checks passed' : `\n${failures} check(s) failed`)
process.exit(failures === 0 ? 0 : 1)
