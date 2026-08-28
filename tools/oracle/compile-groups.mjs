// Compiles a list of independent groups with the pinned oracle, one fresh
// compiler per group. `build()` is cumulative, so groups that are meant to be
// independent must not share a compiler — that is why this exists next to
// compile.mjs, whose `builds` mode deliberately shares one.
//
//   node tools/oracle/compile-groups.mjs <groups.json> <outputs.json>
//
// Used by tools/upstream/compare.mjs.
import { readFile, writeFile } from 'node:fs/promises'
import { compile } from 'tailwindcss'

const groups = JSON.parse(await readFile(process.argv[2], 'utf8'))
const outputs = []
for (const group of groups) {
  const compiler = await compile(group.css, { base: '' })
  outputs.push(compiler.build(group.candidates))
}
await writeFile(process.argv[3], JSON.stringify(outputs))
