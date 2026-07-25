// Workload fixture generator.
//
// Writes the committed fixtures under benchmarks/workloads/<id>/ that every
// runner consumes, plus manifest.json. Fixtures are DETERMINISTIC (sorted) so
// re-running produces byte-identical output and the committed corpus is stable.
//
//   node benchmarks/generate.mjs                # cases.json tiers + full-import bundle
//   node benchmarks/generate.mjs --with-margaui # also (re)build the margaui tier
//
// The margaui tier is derived from an external checkout (default
// /home/mariano/src/margaui, override with MARGAUI_DIR) but its OUTPUT is
// committed, so the benchmark itself never needs that checkout.
import { execFileSync } from 'node:child_process'
import {
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const workloadsDir = join(root, 'benchmarks/workloads')
const withMargaui = process.argv.includes('--with-margaui')
const margauiDir = process.env.MARGAUI_DIR ?? '/home/mariano/src/margaui'

const MINIMAL_CSS = '@tailwind utilities;\n'
const FULL_IMPORT_CSS = '@import "tailwindcss";\n'

// ---- candidate material from the differential corpus ------------------------

const cases = JSON.parse(
  readFileSync(join(root, 'tools/diff/cases.json'), 'utf8'),
)
function caseCandidates(testCase) {
  if (testCase.candidates) return testCase.candidates
  if (testCase.builds) {
    return [...new Set(testCase.builds.flatMap((b) => b.candidates))]
  }
  return []
}
function candidatesOf(name) {
  const testCase = cases.find((c) => c.name === name)
  if (!testCase) throw new Error(`case not found: ${name}`)
  return caseCandidates(testCase)
}
// All unique candidates across the corpus, sorted for determinism.
const allUnique = [
  ...new Set(cases.flatMap(caseCandidates)),
].sort((a, b) => a.localeCompare(b))

// ---- same-variant tier ------------------------------------------------------
//
// Many candidates sharing ONE breakpoint variant, so each one renders its own
// `@media (width >= 48rem)` wrapper and the optimizer sees a single long run of
// adjacent same-key at-rules. That is the shape opt 23 de-quadratified, and no
// other tier exercises it: `stress` has 440 candidates spread over many
// different variants, so its runs are short. Real Tailwind codebases lean on a
// handful of breakpoints, which is exactly this shape.
//
// Arbitrary values keep every candidate distinct (so none is deduplicated away)
// while keeping the generated declaration trivial — the tier measures the merge
// path, not utility matching.
const SAME_VARIANT_COUNT = 1500
const sameVariantCandidates = Array.from(
  { length: SAME_VARIANT_COUNT },
  (_, i) => `md:p-[${i + 1}px]`,
)

// ---- full-import bundle (the parser-heavy entry) ----------------------------
//
// The oracle's tailwindcss index.css is already a flattened 950-line stylesheet
// (no @import), so the "resolve @import \"tailwindcss\"" graph is a single entry:
// { "tailwindcss": <index.css> }. Both tw-mb (MemoryStylesheetLoader) and the
// oracle (files map) resolve the bare "tailwindcss" specifier from this key.
function buildTailwindBundle() {
  const indexCss = readFileSync(
    join(root, 'tools/oracle/node_modules/tailwindcss/index.css'),
    'utf8',
  )
  const bundle = { tailwindcss: indexCss }
  const sharedDir = join(workloadsDir, '_shared')
  mkdirSync(sharedDir, { recursive: true })
  writeFileSync(
    join(sharedDir, 'tailwindcss-bundle.json'),
    JSON.stringify(bundle),
  )
  return bundle
}

// ---- fixture writer ---------------------------------------------------------

function writeWorkload(id, { css, candidates, imports, from, source }) {
  const dir = join(workloadsDir, id)
  mkdirSync(dir, { recursive: true })
  const request = {
    css,
    candidates,
    imports: imports ?? {},
    base: '',
    polyfills: 3,
  }
  if (from) request.from = from
  writeFileSync(join(dir, 'request.json'), JSON.stringify(request, null, 0))
  writeFileSync(join(dir, 'input.css'), css)
  writeFileSync(join(dir, 'candidates.txt'), candidates.join('\n') + '\n')
  writeFileSync(
    join(dir, 'meta.json'),
    JSON.stringify(
      {
        id,
        candidateCount: candidates.length,
        cssVariant:
          imports && Object.keys(imports).length ? 'full-import' : 'minimal',
        source,
      },
      null,
      2,
    ) + '\n',
  )
  return candidates.length
}

// ---- margaui tier -----------------------------------------------------------

function extractClasses(html) {
  const classes = new Set()
  for (const match of html.matchAll(/class\s*=\s*["']([^"']*)["']/g)) {
    for (const cls of match[1].split(/\s+/)) {
      if (cls) classes.add(cls)
    }
  }
  return classes
}

function buildMargaui() {
  if (!existsSync(margauiDir)) {
    console.warn(`! margaui checkout not found at ${margauiDir}; skipping tier.`)
    return null
  }
  const dir = join(workloadsDir, 'margaui')
  mkdirSync(dir, { recursive: true })
  // Bundle the whole @import graph from disk via the native CLI's `bundle` mode.
  const nativeExe = join(
    root,
    '_build/native/release/build/marianoguerra/tailwindcss/cmd/tailwindcss/tailwindcss.exe',
  )
  if (!existsSync(nativeExe)) {
    execFileSync('moon', ['build', '--release', 'cmd/tailwindcss'], {
      cwd: root,
      stdio: 'inherit',
    })
  }
  const entryCss = readFileSync(join(margauiDir, 'entry.css'), 'utf8')
  // margaui's entry does `@import "tailwindcss" source(none)`, a bare specifier
  // the filesystem loader cannot resolve. Bundle a temp copy (in the same dir,
  // so relative "./src/*.css" keys are unchanged) with that line removed, then
  // inject the oracle's flattened tailwindcss under the "tailwindcss" key — so
  // tw-mb and the oracle both compile an identical, self-contained graph.
  const tmpEntry = join(margauiDir, '.__bench_entry.css')
  const entryNoTw = entryCss.replace(/^.*@import\s+["']tailwindcss["'].*$\n?/m, '')
  writeFileSync(tmpEntry, entryNoTw)
  let imports
  try {
    const res = execFileSync(nativeExe, ['bundle', '-i', tmpEntry], {
      cwd: root,
      encoding: 'utf8',
      maxBuffer: 256 * 1024 * 1024,
    })
    imports = JSON.parse(res)
  } finally {
    rmSync(tmpEntry, { force: true })
  }
  imports.tailwindcss = readFileSync(
    join(root, 'tools/oracle/node_modules/tailwindcss/index.css'),
    'utf8',
  )
  writeFileSync(join(dir, 'imports.json'), JSON.stringify(imports))
  // Candidates = classes used across margaui's example pages.
  const examplesDir = join(margauiDir, 'examples')
  const classes = new Set()
  for (const file of readdirSync(examplesDir).filter((f) => f.endsWith('.html'))) {
    for (const cls of extractClasses(readFileSync(join(examplesDir, file), 'utf8'))) {
      classes.add(cls)
    }
  }
  const candidates = [...classes].sort((a, b) => a.localeCompare(b))
  const count = writeWorkload('margaui', {
    css: entryCss,
    candidates,
    imports,
    from: 'entry.css',
    source: `margaui examples/*.html (${margauiDir})`,
  })
  return count
}

// ---- drive ------------------------------------------------------------------

const bundle = buildTailwindBundle()

const written = []
written.push([
  'empty',
  writeWorkload('empty', {
    css: MINIMAL_CSS,
    candidates: [],
    source: 'none (pure compile/setup overhead)',
  }),
])
written.push([
  'one',
  writeWorkload('one', {
    css: MINIMAL_CSS,
    candidates: ['flex'],
    source: 'literal',
  }),
])
written.push([
  'few',
  writeWorkload('few', {
    css: MINIMAL_CSS,
    candidates: candidatesOf('static display'),
    source: 'cases.json "static display"',
  }),
])
written.push([
  'many',
  writeWorkload('many', {
    css: MINIMAL_CSS,
    candidates: candidatesOf('border background SVG and color utility families'),
    source: 'cases.json "border background SVG and color utility families"',
  }),
])
written.push([
  'a-lot',
  writeWorkload('a-lot', {
    css: FULL_IMPORT_CSS,
    candidates: candidatesOf(
      'stateful transform filter effect gradient transition and interaction utilities',
    ),
    imports: bundle,
    from: 'input.css',
    source: 'cases.json largest case (81) + full tailwindcss entry',
  }),
])
written.push([
  'stress',
  writeWorkload('stress', {
    css: FULL_IMPORT_CSS,
    candidates: allUnique,
    imports: bundle,
    from: 'input.css',
    source: 'union of all unique cases.json candidates + full tailwindcss entry',
  }),
])

written.push([
  'variants',
  writeWorkload('variants', {
    css: FULL_IMPORT_CSS,
    candidates: sameVariantCandidates,
    imports: bundle,
    from: 'input.css',
    source: `${SAME_VARIANT_COUNT} candidates sharing one breakpoint variant (md:p-[Npx])`,
  }),
])

let margauiCount = null
if (withMargaui) {
  margauiCount = buildMargaui()
  if (margauiCount !== null) written.push(['margaui', margauiCount])
}

// ---- manifest ---------------------------------------------------------------
//
// Per-workload iteration budget: tiny tiers need many iterations to be
// measurable and to let V8 warm; heavy tiers need fewer. warmup is generous for
// JIT/GC settling; the orchestrator can override via --iters/--warmup/--trials.
const ITER_BUDGET = {
  empty: { warmup: 50, iters: 3000 },
  one: { warmup: 50, iters: 3000 },
  few: { warmup: 50, iters: 2000 },
  many: { warmup: 30, iters: 800 },
  'a-lot': { warmup: 20, iters: 300 },
  stress: { warmup: 15, iters: 150 },
  variants: { warmup: 5, iters: 40 },
  margaui: { warmup: 10, iters: 60 },
}
const order = [
  'empty',
  'one',
  'few',
  'many',
  'a-lot',
  'stress',
  'variants',
  'margaui',
]
const manifest = {
  defaults: { warmup: 20, iters: 200, trials: 3 },
  workloads: order
    .filter((id) => existsSync(join(workloadsDir, id, 'request.json')))
    .map((id) => ({
      id,
      ...ITER_BUDGET[id],
    })),
}
writeFileSync(
  join(root, 'benchmarks/manifest.json'),
  JSON.stringify(manifest, null, 2) + '\n',
)

console.log('Generated workloads:')
for (const [id, count] of written) console.log(`  ${id.padEnd(8)} ${count} candidates`)
if (withMargaui && margauiCount === null) {
  console.log('  margaui  (skipped — no checkout)')
} else if (!withMargaui) {
  console.log('  margaui  (skipped — pass --with-margaui to build it)')
}
console.log(`Manifest: ${manifest.workloads.map((w) => w.id).join(', ')}`)
