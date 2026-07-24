// Workload registry + loader.
//
// The committed fixtures under benchmarks/workloads/<id>/ are the single source
// of truth. Each holds request.json — the canonical compile request
// {css, candidates, imports, base, from, polyfills} — which every runner consumes
// (the MoonBit bench exe and ffi.js as-is; the oracle via `toOracleRequest`).
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

export function workloadsDir(root) {
  return join(root, 'benchmarks/workloads')
}

// Load the ordered workload list from the manifest, attaching each one's
// canonical request.json and per-workload iteration budget.
export function loadManifest(root) {
  const manifest = JSON.parse(
    readFileSync(join(root, 'benchmarks/manifest.json'), 'utf8'),
  )
  const dir = workloadsDir(root)
  return manifest.workloads.map((w) => {
    const request = JSON.parse(
      readFileSync(join(dir, w.id, 'request.json'), 'utf8'),
    )
    return {
      ...w,
      warmup: w.warmup ?? manifest.defaults.warmup,
      iters: w.iters ?? manifest.defaults.iters,
      request,
    }
  })
}

// Adapt the canonical request to the oracle's compile.mjs shape: it takes an
// import map under `files` (not `imports`) and has no `polyfills`/`from`.
export function toOracleRequest(request) {
  return {
    css: request.css,
    base: request.base ?? '',
    files: request.imports ?? {},
    candidates: request.candidates ?? [],
  }
}
