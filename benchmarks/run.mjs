// Benchmark orchestrator.
//
// Runs the target x workload matrix, gates correctness before timing, pools
// samples across trials, computes robust statistics, and writes
// benchmarks/results/results.{json,md}.
//
//   node benchmarks/run.mjs                          # full suite
//   node benchmarks/run.mjs --workload stress,margaui --trials 5
//   node benchmarks/run.mjs --targets native,js,original --no-cold
//   node benchmarks/run.mjs --warmup 20 --iters 200  # override manifest budget
//
// PRIMARY metric = warm steady-state, in-process (median/min µs per compile),
// with process/VM startup excluded (each runner warms up, then times N fresh
// compile()+build() iterations with a monotonic clock). SECONDARY metric = cold
// end-to-end per-invocation time for the real CLI surfaces (the native
// cmd/tailwindcss exe and the oracle compile.mjs).
import { execFileSync } from 'node:child_process'
import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { captureEnv } from './lib/env.mjs'
import { normalized, similarity } from './lib/normalize.mjs'
import { run, runJson } from './lib/spawn.mjs'
import { summarize } from './lib/stats.mjs'
import { loadManifest, toOracleRequest, workloadsDir } from './lib/workloads.mjs'
import { emitMoonbit, timeMoonbit } from './runners/moonbit.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const opts = parseArgs(process.argv.slice(2))

// ---- target definitions -----------------------------------------------------
// Each warm target: emit(workload) -> {ok,css} for the gate; time(workload,w,i)
// -> {ok,samples_us,outLen}. `oracle` is the reference for the gate.
const ALL_TARGETS = {
  native: {
    label: 'tw-mb native',
    emit: (wl) => emitMoonbit(root, 'native', reqPath(wl)),
    time: (wl, w, i) => timeMoonbit(root, 'native', reqPath(wl), w, i),
  },
  js: {
    label: 'tw-mb js',
    emit: (wl) => emitMoonbit(root, 'js', reqPath(wl)),
    time: (wl, w, i) => timeMoonbit(root, 'js', reqPath(wl), w, i),
  },
  'wasm-gc': {
    label: 'tw-mb wasm-gc',
    emit: (wl) => emitMoonbit(root, 'wasm-gc', reqPath(wl)),
    time: (wl, w, i) => timeMoonbit(root, 'wasm-gc', reqPath(wl), w, i),
  },
  original: {
    label: 'tailwindcss 4.3.3',
    emit: (wl) => oracleEmit(wl),
    time: (wl, w, i) => oracleTime(wl, w, i),
  },
}
const TARGET_ORDER = ['native', 'js', 'wasm-gc', 'original']

// The committed canonical request.json — read directly by both the MoonBit bench
// exe (--reqfile) and the oracle runner (which adapts imports->files internally).
function reqPath(wl) {
  return join(workloadsDir(root), wl.id, 'request.json')
}
function oracleEmit(wl) {
  const r = run('node', [
    join(root, 'benchmarks/runners/oracle-bench.mjs'),
    reqPath(wl),
    '--emit',
  ])
  return r.ok ? { ok: true, css: r.stdout } : { ok: false, error: r.stderr }
}
function oracleTime(wl, warmup, iters) {
  const r = runJson('node', [
    join(root, 'benchmarks/runners/oracle-bench.mjs'),
    reqPath(wl),
    String(warmup),
    String(iters),
  ])
  return r.ok ? r.json : { ok: false, error: r.stderr }
}

// ---- build artifacts --------------------------------------------------------
function buildArtifacts(targets) {
  console.log('Building release artifacts...')
  const moonTargets = targets.filter((t) => t !== 'original')
  for (const t of moonTargets) {
    process.stdout.write(`  moon build --release --target ${t} benchmarks/bench ... `)
    execFileSync('moon', ['build', '--release', '--target', t, 'benchmarks/bench'], {
      cwd: root,
      stdio: ['ignore', 'ignore', 'inherit'],
    })
    console.log('ok')
  }
  if (opts.cold) {
    process.stdout.write('  moon build --release cmd/tailwindcss ... ')
    execFileSync('moon', ['build', '--release', 'cmd/tailwindcss'], {
      cwd: root,
      stdio: ['ignore', 'ignore', 'inherit'],
    })
    console.log('ok')
  }
}

// ---- warm matrix ------------------------------------------------------------
function runWarm(workloads, targets) {
  const cells = {} // cells[workloadId][target] = { correct, stats, error, outLen }
  for (const wl of workloads) {
    cells[wl.id] = {}
    // Correctness gate: reference = oracle.
    const ref = ALL_TARGETS.original.emit(wl)
    const refCss = ref.ok ? ref.css : null
    const warmup = opts.warmup ?? wl.warmup
    const iters = opts.iters ?? wl.iters
    for (const target of targets) {
      const def = ALL_TARGETS[target]
      process.stdout.write(`  ${wl.id.padEnd(8)} ${def.label.padEnd(18)} `)
      // Gate (skip comparing the reference to itself). 'exact' = byte-identical
      // after normalization; 'approx' = >= threshold line overlap (cosmetic
      // diffs on large libraries), still timed but flagged; below threshold =
      // genuine breakage, skipped.
      let gate = 'exact'
      let score = 1
      if (target !== 'original') {
        const emit = def.emit(wl)
        if (!emit.ok) {
          console.log(`GATE-ERR (${(emit.error || '').split('\n')[0].slice(0, 60)})`)
          cells[wl.id][target] = { gate: 'error', error: emit.error }
          continue
        }
        if (refCss === null) {
          cells[wl.id][target] = { gate: 'no-reference' }
          console.log('SKIP (oracle emit failed)')
          continue
        }
        const exact = normalized(emit.css) === normalized(refCss)
        score = exact ? 1 : similarity(emit.css, refCss)
        gate = exact ? 'exact' : score >= opts.threshold ? 'approx' : 'diff'
        if (gate === 'diff') {
          console.log(`DIFF (${(score * 100).toFixed(1)}% < ${(opts.threshold * 100).toFixed(0)}%) — not timed`)
          cells[wl.id][target] = { gate: 'diff', score, diff: true }
          continue
        }
      } else {
        gate = ref.ok ? 'exact' : 'error'
      }
      // Time across trials, pooling samples.
      const samples = []
      let outLen = 0
      let failed = null
      for (let trial = 0; trial < opts.trials; trial += 1) {
        const res = def.time(wl, warmup, iters)
        if (!res || !res.ok) {
          failed = res?.error || 'timing failed'
          break
        }
        samples.push(...res.samples_us)
        outLen = res.outLen
      }
      if (failed) {
        console.log(`RUN-ERR (${String(failed).split('\n')[0].slice(0, 60)})`)
        cells[wl.id][target] = { gate, score, error: failed }
        continue
      }
      const stats = summarize(samples)
      cells[wl.id][target] = { gate, score, stats, outLen }
      const flag = gate === 'approx' ? ` ~${(score * 100).toFixed(1)}%` : ''
      console.log(
        `median ${fmtUs(stats.median_us)}  min ${fmtUs(stats.min_us)}  (${stats.ops_per_sec.toFixed(0)} ops/s, n=${stats.n})${flag}`,
      )
    }
  }
  return cells
}

// ---- cold matrix (secondary) ------------------------------------------------
// Real CLI surfaces only: native cmd/tailwindcss exe (minimal-CSS workloads,
// which need no on-disk import graph) and the oracle compile.mjs (all workloads).
function runCold(workloads) {
  mkdirSync(join(root, 'benchmarks/results'), { recursive: true })
  const nativeExe = join(
    root,
    '_build/native/release/build/cmd/tailwindcss/tailwindcss.exe',
  )
  const cold = {}
  for (const wl of workloads) {
    cold[wl.id] = {}
    const needsImports = Object.keys(wl.request.imports ?? {}).length > 0
    // native CLI
    if (!needsImports && existsSync(nativeExe)) {
      cold[wl.id].native = minWall(opts.coldTrials, () =>
        run(nativeExe, [
          '-i',
          join(workloadsDir(root), wl.id, 'input.css'),
          '-c',
          join(workloadsDir(root), wl.id, 'candidates.txt'),
          '-o',
          join(root, 'benchmarks/results/.cold-out.css'),
        ]),
      )
    } else {
      cold[wl.id].native = { na: true, reason: needsImports ? 'needs on-disk imports' : 'no exe' }
    }
    // oracle compile.mjs — write an oracle-shaped request to a temp file.
    const oracleReq = join(root, 'benchmarks/results/.cold-oracle-req.json')
    writeFileSync(oracleReq, JSON.stringify(toOracleRequest(wl.request)))
    cold[wl.id].original = minWall(opts.coldTrials, () =>
      run('node', [join(root, 'tools/oracle/compile.mjs'), oracleReq, join(root, 'benchmarks/results/.cold-out.css')]),
    )
    console.log(
      `  ${wl.id.padEnd(8)} cold  native ${fmtCold(cold[wl.id].native)}  original ${fmtCold(cold[wl.id].original)}`,
    )
  }
  // Drop the throwaway scratch files the cold invocations wrote.
  for (const f of ['.cold-out.css', '.cold-oracle-req.json']) {
    rmSync(join(root, 'benchmarks/results', f), { force: true })
  }
  return cold
}

function minWall(trials, fn) {
  let best = Infinity
  for (let i = 0; i < trials; i += 1) {
    const t0 = process.hrtime.bigint()
    const r = fn()
    const t1 = process.hrtime.bigint()
    if (!r.ok) return { error: r.stderr || 'failed' }
    const us = Number(t1 - t0) / 1000
    if (us < best) best = us
  }
  return { min_us: best }
}

// ---- reporting --------------------------------------------------------------
function fmtUs(us) {
  if (us == null || Number.isNaN(us)) return '—'
  if (us >= 1000) return `${(us / 1000).toFixed(2)}ms`
  return `${us.toFixed(1)}µs`
}
function fmtCold(c) {
  if (c?.na) return `n/a`
  if (c?.error) return 'ERR'
  return fmtUs(c.min_us)
}
function cell(cells, wid, t) {
  const c = cells[wid]?.[t]
  if (!c) return '—'
  if (c.diff) return `DIFF <sub>${(c.score * 100).toFixed(1)}%</sub>`
  if (c.error) return 'ERR'
  if (!c.stats) return '—'
  const approx = c.gate === 'approx' ? '≈' : ''
  return `${approx}${fmtUs(c.stats.median_us)} <br><sub>±${fmtUs(c.stats.stddev_us)} · ${c.stats.ops_per_sec.toFixed(0)}/s</sub>`
}

function writeReports(env, workloads, targets, cells, cold) {
  const resultsDir = join(root, 'benchmarks/results')
  mkdirSync(resultsDir, { recursive: true })
  const json = {
    env,
    config: { targets, trials: opts.trials, coldTrials: opts.coldTrials, cold: opts.cold },
    workloads: workloads.map((w) => ({
      id: w.id,
      candidateCount: w.request.candidates.length,
      cssVariant: Object.keys(w.request.imports ?? {}).length ? 'full-import' : 'minimal',
      warmup: opts.warmup ?? w.warmup,
      iters: opts.iters ?? w.iters,
    })),
    warm: cells,
    cold: opts.cold ? cold : null,
  }
  writeFileSync(join(resultsDir, 'results.json'), JSON.stringify(json, null, 2))

  const lines = []
  lines.push('# tw-mb benchmark results', '')
  lines.push(`_${env.timestamp}_`, '')
  lines.push('## Environment', '')
  lines.push(`- CPU: ${env.cpu} (${env.cpuCount} cores)`)
  lines.push(`- OS: ${env.platform}`)
  lines.push(`- node ${env.node}, moon \`${(env.moon || '').split('\n')[0]}\``)
  lines.push(`- git \`${(env.gitCommit || '').slice(0, 12)}\`${env.gitDirty ? ' (dirty)' : ''}, tailwindcss oracle ${env.tailwindcssOracleVersion}`)
  lines.push(`- trials: ${opts.trials} (samples pooled)`, '')
  lines.push('## Warm steady-state — median per compile (primary)', '')
  lines.push('Each cell: median <br><sub>±stddev · compiles/sec</sub>. Startup/VM cost excluded.', '')
  const cols = targets.map((t) => ALL_TARGETS[t].label)
  lines.push(`| workload | candidates | ${cols.join(' | ')} |`)
  lines.push(`|---|--:|${targets.map(() => '---').join('|')}|`)
  for (const wl of workloads) {
    const variant = Object.keys(wl.request.imports ?? {}).length ? '¹' : ''
    lines.push(
      `| \`${wl.id}\`${variant} | ${wl.request.candidates.length} | ${targets.map((t) => cell(cells, wl.id, t)).join(' | ')} |`,
    )
  }
  lines.push('', '¹ full-import entry (`@import "tailwindcss"`); others use `@tailwind utilities;`. margaui uses its bundled component graph.', '')
  // Speedup vs original
  lines.push('## Speedup vs tailwindcss 4.3.3 (median warm, ×)', '')
  lines.push(`| workload | ${targets.filter((t) => t !== 'original').map((t) => ALL_TARGETS[t].label).join(' | ')} |`)
  lines.push(`|---|${targets.filter((t) => t !== 'original').map(() => '--:').join('|')}|`)
  for (const wl of workloads) {
    const base = cells[wl.id]?.original?.stats?.median_us
    const row = targets
      .filter((t) => t !== 'original')
      .map((t) => {
        const m = cells[wl.id]?.[t]?.stats?.median_us
        return base && m ? `${(base / m).toFixed(2)}×` : '—'
      })
    lines.push(`| \`${wl.id}\` | ${row.join(' | ')} |`)
  }
  lines.push('')
  if (opts.cold && cold) {
    lines.push('## Cold end-to-end — min per invocation (secondary)', '')
    lines.push('Full process launch → one compile → exit (includes runtime startup). Real CLI surfaces only.', '')
    lines.push('| workload | tw-mb native (CLI) | tailwindcss 4.3.3 (compile.mjs) |')
    lines.push('|---|--:|--:|')
    for (const wl of workloads) {
      lines.push(`| \`${wl.id}\` | ${fmtCold(cold[wl.id]?.native)} | ${fmtCold(cold[wl.id]?.original)} |`)
    }
    lines.push('')
  }
  lines.push('## Notes', '')
  lines.push('- Every timed iteration compiles a **fresh** compiler (`Compiler::build` accumulates candidates).')
  lines.push(`- Correctness gate vs tailwindcss 4.3.3 (normalized): exact match times normally; **≈** = ≥${(opts.threshold * 100).toFixed(0)}% line overlap (cosmetic diffs only — banner omitted, rules merged), still timed; **DIFF** = below threshold, not timed.`)
  lines.push('- Run on a quiet machine; prefer median/min. Regenerate fixtures with `node benchmarks/generate.mjs`.')
  writeFileSync(join(resultsDir, 'results.md'), lines.join('\n') + '\n')
  console.log(`\nWrote benchmarks/results/results.json and results.md`)
}

// ---- args -------------------------------------------------------------------
function parseArgs(argv) {
  const o = { trials: 3, coldTrials: 5, cold: true, threshold: 0.95, workloads: null, targets: null, warmup: null, iters: null }
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i]
    if (a === '--no-cold') o.cold = false
    else if (a === '--trials') o.trials = Number(argv[++i])
    else if (a === '--cold-trials') o.coldTrials = Number(argv[++i])
    else if (a === '--threshold') o.threshold = Number(argv[++i])
    else if (a === '--warmup') o.warmup = Number(argv[++i])
    else if (a === '--iters') o.iters = Number(argv[++i])
    else if (a === '--workload') o.workloads = argv[++i].split(',')
    else if (a === '--targets') o.targets = argv[++i].split(',')
    else {
      console.error(`unknown argument: ${a}`)
      process.exit(2)
    }
  }
  return o
}

// ---- main -------------------------------------------------------------------
let workloads = loadManifest(root)
if (opts.workloads) workloads = workloads.filter((w) => opts.workloads.includes(w.id))
if (workloads.length === 0) {
  console.error('no workloads selected')
  process.exit(2)
}
const targets = opts.targets ?? TARGET_ORDER
for (const t of targets) if (!ALL_TARGETS[t]) { console.error(`unknown target: ${t}`); process.exit(2) }

const env = captureEnv(root)
buildArtifacts(targets)
console.log(`\nWarm matrix (${targets.join(', ')}) x (${workloads.map((w) => w.id).join(', ')}), ${opts.trials} trials:\n`)
const cells = runWarm(workloads, targets)
let cold = null
if (opts.cold) {
  console.log('\nCold matrix (secondary):\n')
  cold = runCold(workloads)
}
writeReports(env, workloads, targets, cells, cold)
