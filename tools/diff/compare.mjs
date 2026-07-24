import { spawnSync } from 'node:child_process'
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
} from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '../..')
const allCases = readJson('cases.json')
const manifest = readJson('features.json')
const work = mkdtempSync(join(tmpdir(), 'tailwindcss-moonbit-diff-'))
const options = parseArguments(process.argv.slice(2))

function readJson(name) {
  return JSON.parse(readFileSync(join(import.meta.dirname, name), 'utf8'))
}

function usage(message) {
  if (message) console.error(message)
  console.error(
    'usage: node tools/diff/compare.mjs [--feature ID] [--mode exact|normalized] [--summary-only]',
  )
  process.exit(message ? 2 : 0)
}

function parseArguments(args) {
  const parsed = { features: [], mode: undefined, summaryOnly: false }
  for (let index = 0; index < args.length; index += 1) {
    switch (args[index]) {
      case '--feature':
        if (!args[index + 1]) usage('--feature requires an ID')
        parsed.features.push(args[index + 1])
        index += 1
        break
      case '--mode':
        if (!['exact', 'normalized'].includes(args[index + 1])) {
          usage('--mode must be exact or normalized')
        }
        parsed.mode = args[index + 1]
        index += 1
        break
      case '--summary-only':
        parsed.summaryOnly = true
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

function validateManifest() {
  const statuses = new Set(['passing', 'partial', 'excluded', 'not-started'])
  const caseNames = new Set(allCases.map((testCase) => testCase.name))
  const ids = new Set()
  let invalid = 0
  for (const feature of manifest.features) {
    if (!feature.id || ids.has(feature.id)) {
      console.error(`invalid or duplicate feature ID: ${feature.id}`)
      invalid += 1
    }
    ids.add(feature.id)
    if (!statuses.has(feature.status)) {
      console.error(`invalid status for ${feature.id}: ${feature.status}`)
      invalid += 1
    }
    if (feature.status === 'excluded' && !feature.reason) {
      console.error(`excluded feature lacks a reason: ${feature.id}`)
      invalid += 1
    }
    if (
      feature.status === 'passing' &&
      feature.differentialCases.length === 0 &&
      !feature.whiteBoxOnly
    ) {
      console.error(`passing feature lacks a differential case: ${feature.id}`)
      invalid += 1
    }
    // A white-box-only feature has no effect on `compile` output, so it cannot
    // have a differential case. It still has to say why, and still has to be
    // covered by a MoonBit test.
    if (feature.whiteBoxOnly) {
      if (!feature.reason) {
        console.error(`white-box-only feature lacks a reason: ${feature.id}`)
        invalid += 1
      }
      if (feature.differentialCases.length > 0) {
        console.error(
          `white-box-only feature declares differential cases: ${feature.id}`,
        )
        invalid += 1
      }
      if (feature.moonbitTests.length === 0) {
        console.error(
          `white-box-only feature lacks a MoonBit test: ${feature.id}`,
        )
        invalid += 1
      }
    }
    for (const name of feature.differentialCases) {
      if (!caseNames.has(name)) {
        console.error(`unknown differential case "${name}" in ${feature.id}`)
        invalid += 1
      }
    }
    for (const path of feature.moonbitTests) {
      if (!existsSync(join(root, path))) {
        console.error(`missing MoonBit test "${path}" in ${feature.id}`)
        invalid += 1
      }
    }
  }
  return { invalid, ids }
}

function printSummary() {
  const counts = Object.groupBy(manifest.features, (feature) => feature.status)
  console.log(
    ['passing', 'partial', 'not-started', 'excluded']
      .map((status) => `${status}: ${counts[status]?.length ?? 0}`)
      .join(', '),
  )
}

function run(command, args, runOptions = {}, validateOutput) {
  const spawn = () =>
    spawnSync(command, args, {
      cwd: root,
      encoding: 'utf8',
      ...runOptions,
    })
  let result = spawn()
  for (
    let attempt = 0;
    validateOutput &&
    result.status === 0 &&
    !validateOutput(result.stdout ?? '') &&
    attempt < 9;
    attempt += 1
  ) {
    result = spawn()
  }
  const outputValid = !validateOutput || validateOutput(result.stdout ?? '')
  return {
    ok: result.status === 0 && outputValid,
    status: result.status,
    stdout: result.stdout ?? '',
    stderr:
      result.status === 0 && !outputValid
        ? `${result.stderr ?? ''}invalid or incomplete process output`
        : (result.stderr ?? ''),
  }
}

function validOracleOutput(stdout, buildCount) {
  if (buildCount === undefined) return stdout.trim() !== ''
  try {
    const outputs = JSON.parse(stdout)
    return (
      Array.isArray(outputs) &&
      outputs.length === buildCount &&
      outputs.every((output) => typeof output === 'string')
    )
  } catch {
    return false
  }
}

function normalized(css) {
  return css
    .replace(/\/\*![\s\S]*?\*\//g, '')
    .replace(/\r\n/g, '\n')
    .trim()
}

function matches(reference, moonbit, mode) {
  return mode === 'exact'
    ? reference === moonbit
    : normalized(reference) === normalized(moonbit)
}

function expectedRejection(testCase, implementation) {
  if (testCase.expect === 'reject') return true
  return testCase.expect?.[implementation] === 'reject'
}

function writeFixture(caseDirectory, testCase) {
  mkdirSync(caseDirectory)
  const input = join(caseDirectory, 'input.css')
  writeFileSync(input, testCase.css)
  for (const [path, content] of Object.entries(testCase.files ?? {})) {
    const target = join(caseDirectory, path)
    mkdirSync(dirname(target), { recursive: true })
    writeFileSync(target, content)
  }
  const builds = testCase.builds ?? [
    { name: 'default', candidates: testCase.candidates },
  ]
  const candidateFiles = builds.map((build, index) => {
    const path = join(caseDirectory, `candidates-${index}.txt`)
    writeFileSync(path, build.candidates.join('\n'))
    return path
  })
  return { input, builds, candidateFiles }
}

function runCase(testCase, index) {
  const caseDirectory = join(work, `${index}`)
  const request = join(work, `${index}.json`)
  const oracleOutput = join(work, `${index}.oracle-output`)
  const { input, builds, candidateFiles } = writeFixture(caseDirectory, testCase)
  const oracleRequest =
    testCase.builds === undefined ? testCase : { ...testCase, builds }
  writeFileSync(request, JSON.stringify(oracleRequest))
  const reference = run(
    'node',
    [join(root, 'tools/oracle/compile.mjs'), request, oracleOutput],
  )
  if (reference.ok) {
    reference.stdout = readFileSync(oracleOutput, 'utf8')
    if (!validOracleOutput(reference.stdout, testCase.builds?.length)) {
      reference.ok = false
      reference.stderr += 'invalid or incomplete oracle output file'
    }
  }
  const separator = `__TAILWIND_MOONBIT_BUILD_${process.pid}_${index}__`
  const moonbit = run('moon', [
    'run',
    '--target',
    'native',
    'cmd/tailwindcss',
    '--',
    '--batch',
    separator,
    input,
    ...candidateFiles,
  ])
  const referenceRejects = expectedRejection(testCase, 'reference')
  const moonbitRejects = expectedRejection(testCase, 'moonbit')
  if (reference.ok === referenceRejects || moonbit.ok === moonbitRejects) {
    return {
      ok: false,
      detail: `unexpected exit (reference=${reference.status}, moonbit=${moonbit.status})`,
      reference,
      moonbit,
    }
  }
  if (!reference.ok && !moonbit.ok) return { ok: true }
  const referenceOutputs = testCase.builds
    ? JSON.parse(reference.stdout)
    : [reference.stdout]
  const moonbitOutputs = moonbit.stdout.split(`\n${separator}\n`)
  const mode = testCase.mode ?? options.mode ?? 'normalized'
  const mismatch = builds.findIndex(
    (_, buildIndex) =>
      !matches(referenceOutputs[buildIndex], moonbitOutputs[buildIndex], mode),
  )
  if (mismatch === -1) return { ok: true }
  return {
    ok: false,
    detail: `build "${builds[mismatch].name}" differs in ${mode} mode`,
    reference: { ...reference, stdout: referenceOutputs[mismatch] },
    moonbit: { ...moonbit, stdout: moonbitOutputs[mismatch] },
  }
}

const validation = validateManifest()
printSummary()
if (validation.invalid > 0) process.exit(1)
if (options.summaryOnly) process.exit(0)

let selectedNames
if (options.features.length > 0) {
  selectedNames = new Set()
  for (const id of options.features) {
    const feature = manifest.features.find((entry) => entry.id === id)
    if (!feature) usage(`unknown feature ID: ${id}`)
    for (const name of feature.differentialCases) selectedNames.add(name)
  }
}
const cases = selectedNames
  ? allCases.filter((testCase) => selectedNames.has(testCase.name))
  : allCases
if (cases.length === 0) {
  console.error('selection contains no differential cases')
  process.exit(2)
}

let failed = 0
for (const [index, testCase] of cases.entries()) {
  const result = runCase(testCase, index)
  if (result.ok) {
    console.log(`ok ${index + 1} - ${testCase.name}`)
    continue
  }
  failed += 1
  console.log(`not ok ${index + 1} - ${testCase.name}: ${result.detail}`)
  writeFileSync(join(work, `${index}.reference.css`), result.reference.stdout)
  writeFileSync(join(work, `${index}.reference.stderr`), result.reference.stderr)
  writeFileSync(join(work, `${index}.moonbit.css`), result.moonbit.stdout)
  writeFileSync(join(work, `${index}.moonbit.stderr`), result.moonbit.stderr)
}

if (failed > 0) {
  console.error(`${failed} drift case(s) failed; artifacts: ${work}`)
  process.exit(1)
}
console.log(`${cases.length} differential cases passed`)
