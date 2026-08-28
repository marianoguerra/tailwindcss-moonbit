// Runs every group in cases.json through both compilers and compares them.
//
//   just build-cli && node tools/upstream/compare.mjs
//
// A test passes when every one of its groups matches. baseline.json records the
// tests known to diverge; the run fails when a test outside the baseline breaks,
// and also when a baseline test starts passing, so the baseline cannot rot.
import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'

const here = import.meta.dirname
const root = resolve(here, '../..')
const cases = JSON.parse(readFileSync(join(here, 'cases.json'), 'utf8'))
const baselinePath = join(here, 'baseline.json')
const baseline = JSON.parse(readFileSync(baselinePath, 'utf8'))
const binary = join(
  root,
  '_build/native/release/build/marianoguerra/tailwindcss/cmd/tailwindcss/tailwindcss.exe',
)
const options = parseArguments(process.argv.slice(2))

if (!existsSync(binary)) {
  console.error(`missing native CLI at ${binary}\nrun \`just build-cli\` first`)
  process.exit(2)
}

function usage(message) {
  if (message) console.error(message)
  console.error(
    'usage: node tools/upstream/compare.mjs [--filter SUBSTRING] [--verbose] [--report] [--update-baseline]',
  )
  process.exit(message ? 2 : 0)
}

function parseArguments(args) {
  const parsed = { filter: null, verbose: false, update: false, report: false }
  for (let index = 0; index < args.length; index += 1) {
    switch (args[index]) {
      case '--filter':
        if (!args[index + 1]) usage('--filter requires a substring')
        parsed.filter = args[(index += 1)]
        break
      case '--verbose':
        parsed.verbose = true
        break
      case '--report':
        parsed.report = true
        break
      case '--update-baseline':
        parsed.update = true
        break
      case '--help':
      case '-h':
        usage()
        break
      default:
        usage(`unknown argument: ${args[index]}`)
    }
  }
  return parsed
}

// Every divergence has one of four shapes, and which one it is says what to do
// about it: a missing utility, an over-accepted candidate, a wrong value, or a
// stylesheet this compiler refuses outright.
function classify(failure) {
  const upstream = normalized(failure.reference)
  const ours = normalized(failure.ours)
  if (ours.startsWith('!!')) return 'input rejected by this compiler'
  if (ours === '') return 'not implemented'
  if (upstream === '') return 'accepted, upstream rejects'
  return 'different output'
}

function normalized(css) {
  return css
    .replace(/\/\*![\s\S]*?\*\//g, '')
    .replace(/\r\n/g, '\n')
    .trim()
}

if (options.update && options.filter) {
  usage('--update-baseline rewrites the whole ledger; it cannot be filtered')
}

const tests = options.filter
  ? cases.tests.filter((test) => test.name.includes(options.filter))
  : cases.tests
if (tests.length === 0) usage('filter selected no tests')

const work = mkdtempSync(join(tmpdir(), 'tailwindcss-upstream-'))
const flat = []
for (const test of tests) {
  for (const [index, group] of test.groups.entries()) {
    flat.push({ test: test.name, index, ...group })
  }
}

writeFileSync(join(work, 'groups.json'), JSON.stringify(flat))
const oraclePath = join(work, 'oracle.json')
const oracle = spawnSync(
  'node',
  [join(root, 'tools/oracle/compile-groups.mjs'), join(work, 'groups.json'), oraclePath],
  { cwd: root, encoding: 'utf8' },
)
if (oracle.status !== 0) {
  console.error(`oracle failed:\n${oracle.stderr}`)
  console.error('run `just oracle` if tailwindcss is not installed')
  process.exit(1)
}
const reference = JSON.parse(readFileSync(oraclePath, 'utf8'))

mkdirSync(join(work, 'in'), { recursive: true })
const ours = flat.map((group, index) => {
  const input = join(work, 'in', `${index}.css`)
  const candidates = join(work, 'in', `${index}.txt`)
  writeFileSync(input, group.css)
  writeFileSync(candidates, group.candidates.join('\n'))
  const result = spawnSync(binary, ['-i', input, '-c', candidates], {
    cwd: root,
    encoding: 'utf8',
  })
  return result.status === 0 ? (result.stdout ?? '') : `!! ${result.stderr ?? ''}`
})

const failures = new Map()
const extractionErrors = []
const groupStats = { output: { ok: 0, failed: 0 }, empty: { ok: 0, failed: 0 } }
for (const [index, group] of flat.entries()) {
  if (group.expect === 'empty' && normalized(reference[index]) !== '') {
    extractionErrors.push(`${group.test}[${group.index}] expected rejection, oracle emitted CSS`)
  }
  if (normalized(reference[index]) === normalized(ours[index])) {
    groupStats[group.expect].ok += 1
    continue
  }
  groupStats[group.expect].failed += 1
  if (!failures.has(group.test)) failures.set(group.test, [])
  failures.get(group.test).push({ group, reference: reference[index], ours: ours[index] })
}

if (extractionErrors.length > 0) {
  console.error(`extraction is stale — rerun tools/upstream/extract.mjs`)
  for (const error of extractionErrors.slice(0, 5)) console.error(`  ${error}`)
  process.exit(1)
}

const known = new Set(Object.keys(baseline.divergent))
const selected = new Set(tests.map((test) => test.name))
const broke = [...failures.keys()].filter((name) => !known.has(name)).sort()
const fixed = [...known].filter((name) => selected.has(name) && !failures.has(name)).sort()
// A baseline entry naming no test at all means cases.json was re-extracted and
// the ledger was not; only a full run can tell.
const orphaned = options.filter
  ? []
  : [...known].filter((name) => !cases.tests.some((test) => test.name === name)).sort()

if (options.update) {
  const divergent = {}
  for (const name of [...failures.keys()].sort()) {
    const kinds = [...new Set(failures.get(name).map(classify))]
    divergent[name] = kinds.join(' + ')
  }
  writeFileSync(
    baselinePath,
    `${JSON.stringify({ ...baseline, divergent }, null, 2)}\n`,
  )
  console.log(`baseline updated: ${Object.keys(divergent).length} divergent test(s)`)
  process.exit(0)
}

if (options.report) {
  const buckets = new Map()
  for (const [name, list] of failures) {
    for (const failure of list) {
      const kind = classify(failure)
      if (!buckets.has(kind)) buckets.set(kind, [])
      buckets.get(kind).push({ name, failure })
    }
  }
  for (const [kind, list] of [...buckets].sort((a, b) => b[1].length - a[1].length)) {
    const names = [...new Set(list.map((entry) => entry.name))]
    console.log(`\n${kind}: ${list.length} group(s) across ${names.length} test(s)`)
    console.log(`  tests: ${names.slice(0, 12).join(', ')}${names.length > 12 ? ', …' : ''}`)
    const sample = list[0]
    console.log(`  e.g. ${sample.name}: ${sample.failure.group.candidates.slice(0, 6).join(' ')}`)
  }
  console.log()
}

if (options.verbose) {
  for (const name of broke.length > 0 ? broke : [...failures.keys()].sort()) {
    for (const failure of failures.get(name)) {
      console.log(`--- ${name} [group ${failure.group.index}]`)
      console.log(`  candidates: ${failure.group.candidates.join(' ')}`)
      console.log(`  upstream: ${JSON.stringify(normalized(failure.reference))}`)
      console.log(`  ours:     ${JSON.stringify(normalized(failure.ours))}`)
    }
  }
}

const passed = tests.length - failures.size
console.log(
  `upstream utilities.test.ts @ ${cases.upstream.commit.slice(0, 10)}: ` +
    `${passed}/${tests.length} tests match (${flat.length} groups, ` +
    `${flat.reduce((total, group) => total + group.candidates.length, 0)} candidates)`,
)
console.log(
  `  groups producing CSS: ${groupStats.output.ok}/${groupStats.output.ok + groupStats.output.failed} match`,
)
console.log(
  `  groups upstream rejects: ${groupStats.empty.ok}/${groupStats.empty.ok + groupStats.empty.failed} match`,
)
console.log(`known divergences: ${[...failures.keys()].filter((name) => known.has(name)).length}`)

for (const name of broke) console.log(`not ok - ${name}`)
for (const name of fixed) console.log(`now passing (drop from baseline) - ${name}`)
for (const name of orphaned) console.log(`baseline names no such test - ${name}`)
if (broke.length > 0 || fixed.length > 0 || orphaned.length > 0) {
  console.error(
    `${broke.length} regression(s), ${fixed.length + orphaned.length} stale baseline entr(ies); ` +
      'rerun with --verbose, or --update-baseline once reviewed',
  )
  process.exit(1)
}
console.log('no regressions against the recorded baseline')
