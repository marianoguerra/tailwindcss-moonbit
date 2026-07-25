// Boot and render loop.
//
// Structure follows margaui's editor (debounced CodeMirror updates, tab toggling,
// a shadow-root preview) with two differences that matter:
//
//   - class extraction happens in MoonBit, not in a JS regex here;
//   - the preview's <style> nodes are created once and rewritten, instead of
//     re-creating the shadow tree on every keystroke.
import { CodeMirror, setCodeMirrorPath } from './code-editor.js'
import { createCompiler } from './compiler.js'
import { KITCHEN_SINK_ID, loadExamples, populateSelect } from './examples.js'
import { byteLength } from './format.js'
import { createHowItWorks, renderBenchmarks } from './howitworks.js'
import { createStats } from './stats.js'
import { adoptableThemeCss, createThemeSwitcher } from './theme.js'

const DEBOUNCE_MS = 150

// Big enough for the kitchen-sink example, small enough that a pasted novel
// cannot lock the tab up in the parser.
const MAX_INPUT_CHARS = 512_000

const WELCOME = `<!-- Edit anything: the CSS on the right is compiled from scratch,
     in your browser, by a Tailwind compiler written in MoonBit. -->
<div class="card bg-base-100 w-80 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Hello from MoonBit</h2>
    <p class="text-sm opacity-70">
      Every class you type is extracted by a WHATWG HTML parser, then compiled.
    </p>
    <div class="card-actions justify-end">
      <button class="btn btn-primary btn-sm">Primary</button>
      <button class="btn btn-ghost btn-sm">Ghost</button>
    </div>
  </div>
</div>

<table class="table table-zebra w-72">
  <tbody>
    <!-- A bare row keeps its classes here; a plain document parse would drop it. -->
    <tr class="hover">
      <td class="font-mono text-xs">table-zebra</td>
      <td><span class="badge badge-primary badge-sm">ok</span></td>
    </tr>
  </tbody>
</table>
`

const params = new URLSearchParams(location.search)
const boot = document.getElementById('boot')
const bootStatus = document.getElementById('boot-status')

const setStatus = (message) => {
  bootStatus.textContent = message
}

if (params.has('vim')) CodeMirror.isVimMode = true

setCodeMirrorPath('../vendor/codemirror/codemirror.js')
customElements.define('code-editor', CodeMirror)

const htmlInput = document.getElementById('html-input')
const cssOutput = document.getElementById('css-output')
cssOutput.readonly = true
if (params.has('dark')) {
  htmlInput.dark = true
  cssOutput.dark = true
}

const stats = createStats({
  sizeEl: document.getElementById('stat-size'),
  classesEl: document.getElementById('stat-classes'),
  timeEl: document.getElementById('stat-time'),
  detailEl: document.getElementById('stat-detail'),
  statusEl: document.getElementById('bench-out'),
})
const howItWorks = createHowItWorks(document.getElementById('how-root'))

let compiler
try {
  compiler = await createCompiler({ onProgress: setStatus })
} catch (error) {
  setStatus(`could not start: ${error.message}`)
  boot.querySelector('.loading')?.remove()
  throw error
}

// The wire size of the compiler itself, for the "how it works" panel. A HEAD is
// enough and it is already cached, so this costs nothing visible.
const artifactBytes = await contentLength(
  compiler.backend === 'wasm-gc' ? 'assets/twffi.wasm' : 'assets/twffi.js',
)
howItWorks.describeCompiler({
  backend: compiler.backend,
  info: compiler.info,
  bundle: compiler.bundle,
  artifactBytes,
})

setStatus('loading examples')
const examples = await loadExamples()
const exampleSelect = document.getElementById('example-select')
populateSelect(exampleSelect, examples)

const themeSwitcher = await createThemeSwitcher({
  selectEl: document.getElementById('theme-select'),
  initial: params.get('theme') ?? 'light',
  onChange: (_name, css) => {
    styleTheme.textContent = adoptableThemeCss(css)
    previewRoot.dataset.theme = themeSwitcher.current
  },
})

// ---- preview ---------------------------------------------------------------

// Built once. Adopted stylesheets are ordered *before* a shadow tree's own
// <style> elements, so an adopted theme would lose to the compiled sheet's
// `:host` theme block; two ordered <style> nodes make the winner explicit.
const previewFrame = document.getElementById('preview-frame')
const shadow = previewFrame.attachShadow({ mode: 'open' })
const styleTw = shadow.appendChild(document.createElement('style'))
const styleTheme = shadow.appendChild(document.createElement('style'))
const previewRoot = shadow.appendChild(document.createElement('div'))
previewRoot.style.cssText = 'display:flex;flex-wrap:wrap;align-items:start;gap:1rem;padding:2rem'
styleTheme.textContent = adoptableThemeCss(themeSwitcher.css)
previewRoot.dataset.theme = themeSwitcher.current

// ---- tabs ------------------------------------------------------------------

const tabs = [...document.querySelectorAll('.ed-tab')]
const panels = new Map(
  tabs.map((tab) => [tab.dataset.panel, document.getElementById(`ed-panel-${tab.dataset.panel}`)]),
)
for (const tab of tabs) {
  tab.addEventListener('click', () => {
    for (const other of tabs) other.setAttribute('aria-selected', String(other === tab))
    for (const [name, panel] of panels) panel.classList.toggle('ed-hidden', name !== tab.dataset.panel)
  })
}

// ---- render loop -----------------------------------------------------------

let currentCode = ''
let rev = 0
let lastCss = ''
let lastCandidateKey = null
let debounceTimer = null
let rendering = false
let pending = false

const warmToggle = document.getElementById('mode-warm')
warmToggle.checked = params.has('warm')

function setEditorCode(code) {
  currentCode = code
  htmlInput.code = code
  htmlInput.rev = ++rev
}

/**
 * Compile and paint.
 *
 * Cheap path first: `scan` costs microseconds, so if the candidate set is
 * unchanged — which is every keystroke that edits text rather than a class — the
 * stylesheet is reused and only the markup is re-rendered.
 */
async function render() {
  if (rendering) {
    pending = true
    return
  }
  rendering = true
  try {
    const html = currentCode
    if (html.length > MAX_INPUT_CHARS) {
      stats.fail(`input over ${MAX_INPUT_CHARS.toLocaleString()} characters — not compiling`)
      previewRoot.innerHTML = html
      return
    }

    const warm = warmToggle.checked
    if (warm && !compiler.incremental.isOpen) compiler.incremental.open()
    if (!warm && compiler.incremental.isOpen) {
      compiler.incremental.close()
      lastCandidateKey = null
    }

    const scan = compiler.scan(html)
    const key = scan.candidates.join(' ')
    let result
    let cached = false
    if (key === lastCandidateKey && lastCss !== '') {
      result = { ...scan, css: lastCss, wallMs: scan.wallMs }
      cached = true
    } else {
      result = warm ? compiler.incremental.build(html) : compiler.compile(html)
      lastCandidateKey = key
      lastCss = result.css
      styleTw.textContent = result.css
      cssOutput.code = result.css
      cssOutput.rev = ++rev
    }

    previewRoot.innerHTML = html
    renderCandidates(scan.candidates, result.css)
    await stats.render(result, {
      cached,
      backend: compiler.backend,
      bundle: compiler.bundle,
    })
    // A cached render measured no compile, so leave the walkthrough showing the
    // last real one rather than filling it with zeroes.
    if (!cached) {
      howItWorks.describeResult({ ...result, cssBytes: byteLength(result.css ?? '') })
    }
  } catch (error) {
    stats.fail(error.message)
    console.error(error)
  } finally {
    rendering = false
    if (pending) {
      pending = false
      render()
    }
  }
}

const chipsEl = document.getElementById('candidate-chips')

function renderCandidates(candidates, css) {
  chipsEl.innerHTML = ''
  for (const candidate of [...candidates].sort()) {
    const chip = document.createElement('span')
    chip.className = 'ed-chip'
    chip.textContent = candidate
    // A candidate the compiler emitted nothing for never appears in the output.
    // Escaping makes an exact match unreliable, so this is a substring probe: it
    // is a hint in the UI, not a claim.
    if (!css.includes(candidate.replace(/[:./[\]]/g, '\\$&')) && !css.includes(candidate)) {
      chip.dataset.unused = 'true'
      chip.title = 'no CSS was generated for this class'
    }
    chipsEl.appendChild(chip)
  }
}

htmlInput.addEventListener('code-editor-update', (event) => {
  currentCode = event.detail.code
  clearTimeout(debounceTimer)
  debounceTimer = setTimeout(render, DEBOUNCE_MS)
})

warmToggle.addEventListener('change', () => {
  lastCandidateKey = null
  syncUrl('warm', warmToggle.checked)
  render()
})

// ---- controls --------------------------------------------------------------

document.getElementById('load-btn').addEventListener('click', () => {
  const example = examples.byId.get(exampleSelect.value)
  if (!example) return
  setEditorCode(example.html)
  syncUrl('example', example.id === KITCHEN_SINK_ID ? null : example.id)
  render()
})

document.getElementById('bench-btn').addEventListener('click', async (event) => {
  const button = event.currentTarget
  button.disabled = true
  stats.status('running…')
  try {
    stats.renderBenchmark(await compiler.benchmark(currentCode, 10))
  } finally {
    button.disabled = false
  }
})

document.getElementById('css-copy').addEventListener('click', async (event) => {
  await navigator.clipboard.writeText(lastCss)
  const button = event.currentTarget
  const label = button.textContent
  button.textContent = 'Copied'
  setTimeout(() => {
    button.textContent = label
  }, 1200)
})

document.getElementById('css-download').addEventListener('click', () => {
  const url = URL.createObjectURL(new Blob([lastCss], { type: 'text/css' }))
  const link = document.createElement('a')
  link.href = url
  link.download = 'margaui.css'
  link.click()
  URL.revokeObjectURL(url)
})

const editorDark = document.getElementById('editor-dark')
editorDark.checked = htmlInput.dark
editorDark.addEventListener('change', () => {
  htmlInput.dark = editorDark.checked
  cssOutput.dark = editorDark.checked
})

const editorVim = document.getElementById('editor-vim')
editorVim.checked = CodeMirror.isVimMode
editorVim.addEventListener('change', () => {
  CodeMirror.isVimMode = editorVim.checked
  htmlInput.refresh()
  cssOutput.refresh()
  syncUrl('vim', editorVim.checked)
})

document.getElementById('theme-select').addEventListener('change', (event) => {
  syncUrl('theme', event.currentTarget.value)
})

function syncUrl(key, value) {
  const url = new URL(location.href)
  if (value === false || value === null) url.searchParams.delete(key)
  else url.searchParams.set(key, value === true ? '' : value)
  history.replaceState(null, '', url)
}

async function contentLength(url) {
  try {
    const response = await fetch(url, { method: 'HEAD' })
    const length = response.headers.get('content-length')
    return length ? Number(length) : null
  } catch {
    return null
  }
}

// ---- go --------------------------------------------------------------------

renderBenchmarks(document.getElementById('bench-table'), document.getElementById('bench-note'))

const requested = params.get('example')
const initial = requested ? examples.byId.get(requested) : null
if (initial) exampleSelect.value = initial.id
setEditorCode(initial ? initial.html : WELCOME)
await render()

boot.hidden = true
