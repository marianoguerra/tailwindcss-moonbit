// Runner for the three MoonBit backends (native, js, wasm-gc).
//
// Each spawns the single `benchmarks/bench` executable via `moon run --release
// --target <t>`. The bench exe does warmup + timed iterations IN-PROCESS with a
// portable monotonic clock and prints the raw per-iteration sample array, so
// process/VM startup is excluded from the samples — the warm steady-state metric.
//
// The request JSON is passed after a `--req` marker, split into <128 KB chunks
// (Linux MAX_ARG_STRLEN) so even the ~290 KB margaui request fits in argv.
import { run, runJson } from '../lib/spawn.mjs'

const CHUNK = 100_000

function chunk(str) {
  const parts = []
  for (let i = 0; i < str.length; i += CHUNK) parts.push(str.slice(i, i + CHUNK))
  return parts.length ? parts : ['']
}

function moonArgs(target, pre, requestJson) {
  return [
    'run',
    '--release',
    '--target',
    target,
    'benchmarks/bench',
    '--',
    ...pre,
    '--req',
    ...chunk(requestJson),
  ]
}

// Warm timing: returns { ok, samples_us:[...], outLen } or { ok:false, error }.
export function timeMoonbit(root, target, request, warmup, iters) {
  const requestJson = JSON.stringify(request)
  const result = runJson('moon', moonArgs(target, [String(warmup), String(iters)], requestJson), {
    cwd: root,
  })
  if (!result.ok) {
    return { ok: false, error: result.stderr || 'runner failed', raw: result.raw }
  }
  return result.json
}

// Single compile for the correctness gate: returns the generated CSS string.
export function emitMoonbit(root, target, request) {
  const requestJson = JSON.stringify(request)
  const result = run('moon', moonArgs(target, ['--emit'], requestJson), { cwd: root })
  if (!result.ok) return { ok: false, error: result.stderr }
  return { ok: true, css: result.stdout }
}
