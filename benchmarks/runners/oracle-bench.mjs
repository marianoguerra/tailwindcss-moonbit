// Warm in-process runner for the ORIGINAL tailwindcss@4.3.3 (the baseline).
//
// Run as a subprocess (one fresh process per workload/trial, for isolation):
//   node benchmarks/runners/oracle-bench.mjs <request.json> <warmup> <iters>
//   node benchmarks/runners/oracle-bench.mjs <request.json> --emit
//
// It reuses tools/oracle/compile.mjs's resolution model (an in-memory `files`
// map + posix path normalization) and, like every other runner, times a FRESH
// `compile()` + `build()` per iteration (upstream `build` also accumulates
// candidates). Timing uses performance.now(), directly comparable to the js
// backend. The request is read from a file, so there is no argv-size limit.
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import { dirname, join, posix } from 'node:path'
import { performance } from 'node:perf_hooks'
import { fileURLToPath, pathToFileURL } from 'node:url'

// Resolve `tailwindcss` from tools/oracle/node_modules regardless of this
// script's location or the cwd (ESM bare-specifier resolution is module-relative).
const root = join(dirname(fileURLToPath(import.meta.url)), '../..')
const oracleRequire = createRequire(join(root, 'tools/oracle/package.json'))
// Resolve the package's ESM entry (`exports["."].import`) explicitly — plain
// require.resolve picks the CJS "require" build, whose `compile` is not a usable
// named ESM export.
const pkgJsonPath = oracleRequire.resolve('tailwindcss/package.json')
const pkg = JSON.parse(readFileSync(pkgJsonPath, 'utf8'))
const esmEntry = pkg.exports?.['.']?.import ?? pkg.module ?? pkg.main
const { compile } = await import(
  pathToFileURL(join(dirname(pkgJsonPath), esmEntry)).href
)

const requestPath = process.argv[2]
const emit = process.argv.includes('--emit')
const warmup = emit ? 0 : Number(process.argv[3] ?? 5)
const iters = emit ? 1 : Number(process.argv[4] ?? 50)

const request = JSON.parse(readFileSync(requestPath, 'utf8'))
// Canonical request uses `imports`; the oracle model calls it `files`.
const files = new Map(
  Object.entries(request.imports ?? request.files ?? {}).map(([path, content]) => [
    posix.normalize(path),
    content,
  ]),
)
const base = request.base ?? ''
const candidates = request.candidates ?? []

async function compileOnce() {
  const compiler = await compile(request.css, {
    base,
    async loadStylesheet(id, from) {
      const path = posix.normalize(posix.join(from, id))
      if (!files.has(path)) throw new Error(`Missing oracle stylesheet: ${path}`)
      return {
        content: files.get(path),
        path,
        base: posix.dirname(path) === '.' ? '' : posix.dirname(path),
      }
    },
  })
  return compiler.build(candidates)
}

let sink = 0 // dead-code-elimination guard

if (emit) {
  process.stdout.write(await compileOnce())
} else {
  for (let i = 0; i < warmup; i += 1) sink += (await compileOnce()).length
  const samples = []
  let outLen = 0
  for (let i = 0; i < iters; i += 1) {
    const t0 = performance.now()
    const css = await compileOnce()
    const t1 = performance.now()
    samples.push((t1 - t0) * 1000) // ms -> microseconds
    outLen = css.length
    sink += css.length
  }
  if (sink < 0) console.error('unreachable') // keep `sink` observable
  process.stdout.write(JSON.stringify({ ok: true, samples_us: samples, outLen }))
}
