// Regenerates tools/upstream/cases.json from the pinned upstream test file.
//
//   node tools/upstream/extract.mjs
//
// The source file is downloaded once into tools/upstream/vendor/ (gitignored)
// at the commit tools/diff/features.json pins. cases.json is committed, so the
// comparison runner never needs the network.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

const here = import.meta.dirname
const root = resolve(here, '../..')
const manifest = JSON.parse(
  readFileSync(join(root, 'tools/diff/features.json'), 'utf8'),
)
const commit = manifest.upstream.commit
const sourcePath = 'packages/tailwindcss/src/utilities.test.ts'
const vendor = join(here, 'vendor')
const vendored = join(vendor, 'utilities.test.ts')

if (!existsSync(vendored)) {
  const url = `https://raw.githubusercontent.com/tailwindlabs/tailwindcss/${commit}/${sourcePath}`
  process.stderr.write(`fetching ${sourcePath} @ ${commit.slice(0, 10)}\n`)
  const response = await fetch(url)
  if (!response.ok) {
    console.error(`failed to fetch upstream tests: ${response.status}`)
    process.exit(1)
  }
  mkdirSync(vendor, { recursive: true })
  writeFileSync(vendored, await response.text())
}

// Point the upstream imports at the stub harness, then import the file so its
// `test()` calls register. Node strips the TypeScript annotations natively.
const source = readFileSync(vendored, 'utf8')
const stripped = source.replace(
  /^import \{[^}]*\} from '(vitest|\.|\.\/test-utils\/run|\.\/utilities)'\n/gm,
  '',
)
const generated = join(vendor, 'utilities.generated.ts')
writeFileSync(
  generated,
  `import { describe, expect, test, vi, run, compileCss, compile,\n` +
    `  isValidFunctionalUtilityName, isValidStaticUtilityName } from '../harness.mjs'\n` +
    stripped,
)

const harness = await import('./harness.mjs')
await import(pathToFileURL(generated).href)

const tests = []
const unportable = []
for (const entry of harness.tests) {
  const record = { name: entry.name, runs: [] }
  harness.setCurrent(record)
  try {
    await entry.fn()
  } catch (error) {
    unportable.push({ name: entry.name, reason: String(error?.message ?? error) })
    continue
  }
  const groups = record.runs
    .filter((group) => group.expect === 'output' || group.expect === 'empty')
    .filter((group) => Object.keys(group.options ?? {}).length === 0)
    .map((group) => ({
      css: group.input,
      candidates: group.candidates,
      expect: group.expect,
    }))
  if (groups.length === 0) {
    unportable.push({ name: entry.name, reason: 'no assertable run() call' })
    continue
  }
  tests.push({ name: record.name, groups })
}

writeFileSync(
  join(here, 'cases.json'),
  `${JSON.stringify(
    {
      upstream: { commit, path: sourcePath },
      generatedBy: 'tools/upstream/extract.mjs',
      tests,
      unportable,
    },
    null,
    2,
  )}\n`,
)

const groups = tests.flatMap((entry) => entry.groups)
console.log(`tests: ${tests.length} (unportable: ${unportable.length})`)
console.log(
  `groups: ${groups.length} (${groups.filter((g) => g.expect === 'output').length} expect CSS, ` +
    `${groups.filter((g) => g.expect === 'empty').length} expect rejection)`,
)
console.log(`candidates: ${groups.reduce((total, g) => total + g.candidates.length, 0)}`)
