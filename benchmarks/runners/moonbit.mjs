// Runner for the three MoonBit backends (native, js, wasm-gc).
//
// Each spawns the single `benchmarks/bench` executable via `moon run --release
// --target <t>`. The bench exe does warmup + timed iterations IN-PROCESS with a
// portable monotonic clock and prints the raw per-iteration sample array, so
// process/VM startup is excluded from the samples — the warm steady-state metric.
//
// The request is passed by FILE PATH (`--reqfile`), read inside the exe via
// moonbitlang/x/fs, which works on native, js, and wasm-gc under moonrun. This
// avoids inlining the (up to ~290 KB) request into argv.
import { run, runJson } from '../lib/spawn.mjs'

function moonArgs(target, pre, requestPath) {
  return [
    'run',
    '--release',
    '--target',
    target,
    'benchmarks/bench',
    '--',
    ...pre,
    '--reqfile',
    requestPath,
  ]
}

// Warm timing: returns { ok, samples_us:[...], outLen } or { ok:false, error }.
export function timeMoonbit(root, target, requestPath, warmup, iters) {
  const result = runJson(
    'moon',
    moonArgs(target, [String(warmup), String(iters)], requestPath),
    { cwd: root },
  )
  if (!result.ok) {
    return { ok: false, error: result.stderr || 'runner failed', raw: result.raw }
  }
  return result.json
}

// Single compile for the correctness gate: returns the generated CSS string.
export function emitMoonbit(root, target, requestPath) {
  const result = run('moon', moonArgs(target, ['--emit'], requestPath), { cwd: root })
  if (!result.ok) return { ok: false, error: result.stderr }
  return { ok: true, css: result.stdout }
}
