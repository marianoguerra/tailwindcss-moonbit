// Fills the "How it works" and "Benchmarks" panels with live numbers.
//
// The explanation is in index.html; this only substitutes the measurements from
// the most recent compile, so the walkthrough describes what just happened
// instead of what usually happens.
import { humanBytes, humanCount, humanUs } from './format.js'

export function createHowItWorks(rootEl) {
  const slots = new Map()
  for (const element of rootEl.querySelectorAll('[data-hiw]')) {
    slots.set(element.dataset.hiw, element)
  }

  function set(name, text) {
    const element = slots.get(name)
    if (element) element.textContent = text
  }

  return {
    describeCompiler({ backend, info, bundle, artifactBytes }) {
      set('backend', backend)
      set('compilerVersion', info.compiler)
      set('htmlVersion', info.html)
      set('imports', humanCount(bundle.imports))
      set('importBytes', humanBytes(bundle.importChars))
      set('bundleBytes', humanBytes(bundle.bytes))
      set('bundleLoad', humanUs(bundle.loadMs * 1000))
      if (artifactBytes) set('artifactBytes', humanBytes(artifactBytes))
    },

    describeResult(result) {
      set('elements', humanCount(result.counts.elements))
      set('classAttrs', humanCount(result.counts.classAttrs))
      set('candidates', humanCount(result.counts.candidates))
      set('scanUs', humanUs(result.timings.scanUs))
      set('compileUs', humanUs(result.timings.compileUs ?? 0))
      set('buildUs', humanUs(result.timings.buildUs ?? 0))
      set('outBytes', humanBytes(result.cssBytes ?? 0))
    },
  }
}

/**
 * Render the committed benchmark snapshot.
 *
 * Shown as measured, including where this compiler loses: on the margaui graph
 * the wasm-gc build is a little slower than tailwindcss itself, and only the
 * native build is ahead. A benchmark table that only ever flattered us would not
 * be worth reading.
 */
export async function renderBenchmarks(tableEl, noteEl, url = 'assets/benchmarks.json') {
  const data = await fetch(url)
    .then((response) => (response.ok ? response.json() : null))
    .catch(() => null)
  if (!data) {
    noteEl.textContent = 'No benchmark snapshot was committed with this build.'
    return null
  }

  const label = (target) =>
    target === 'original' ? `tailwindcss ${data.source.oracle ?? ''}`.trim() : `tw-mb ${target}`
  const targets = [...new Set(data.workloads.flatMap((workload) => Object.keys(workload.targets)))]
  const order = ['native', 'wasm-gc', 'js', 'original']
  targets.sort((a, b) => order.indexOf(a) - order.indexOf(b))

  const head = ['workload', 'candidates', ...targets.map(label)]
  const rows = data.workloads.map((workload) => [
    workload.id,
    humanCount(workload.candidates),
    ...targets.map((target) =>
      workload.targets[target] ? humanUs(workload.targets[target].medianUs) : '—',
    ),
  ])

  tableEl.innerHTML = ''
  const thead = tableEl.appendChild(document.createElement('thead'))
  const headRow = thead.appendChild(document.createElement('tr'))
  for (const cell of head) {
    const th = headRow.appendChild(document.createElement('th'))
    th.textContent = cell
  }
  const tbody = tableEl.appendChild(document.createElement('tbody'))
  for (const row of rows) {
    const tr = tbody.appendChild(document.createElement('tr'))
    for (const cell of row) {
      const td = tr.appendChild(document.createElement('td'))
      td.textContent = cell
    }
  }

  const when = data.source.timestamp ? data.source.timestamp.slice(0, 10) : 'unknown date'
  noteEl.textContent =
    `Warm medians per compile, ${data.source.trials ?? '?'} trials on ${data.source.cpu ?? 'unknown CPU'}` +
    ` (${when}). Each iteration builds a fresh compiler. Your browser's number above is measured the same way.`
  return data
}
