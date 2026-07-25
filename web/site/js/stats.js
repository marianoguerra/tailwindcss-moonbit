// The stats bar: what came out, and what it cost.
//
// Timings come from the compiler itself (MoonBit reads the clock around each
// stage) and are shown next to the JS wall-clock for the same call, so the gap —
// JSON marshalling, mostly — is visible instead of hidden. Sizes are measured
// with TextEncoder and CompressionStream, not estimated.
import { byteLength, gzipSize, humanBytes, humanCount, humanUs } from './format.js'

export function createStats({ sizeEl, classesEl, timeEl, detailEl, statusEl }) {
  let token = 0

  return {
    /**
     * @param result   a compile or warm-build reply, with `counts`/`timings`
     * @param options  `cached` when the candidate set was unchanged and no
     *                 compile ran; `backend`/`bundle` for the trailing context
     */
    async render(result, { cached = false, backend = '', bundle = null } = {}) {
      const css = result.css ?? ''
      const bytes = byteLength(css)
      sizeEl.textContent = humanBytes(bytes)
      classesEl.textContent = `${humanCount(result.counts.candidates)} ${
        result.counts.candidates === 1 ? 'class' : 'classes'
      }`
      timeEl.textContent = cached ? 'cached' : humanUs(result.timings.totalUs)
      timeEl.classList.toggle('ed-muted', cached)

      const stages = [`scan ${humanUs(result.timings.scanUs)}`]
      if (typeof result.timings.compileUs === 'number') {
        stages.push(`compile ${humanUs(result.timings.compileUs)}`)
      }
      if (typeof result.timings.buildUs === 'number') {
        stages.push(`build ${humanUs(result.timings.buildUs)}`)
      }
      const parts = [stages.join(' · ')]
      if (!cached) {
        parts.push(
          `MoonBit ${humanUs(result.timings.totalUs)} · wall ${humanUs((result.wallMs ?? 0) * 1000)}`,
        )
      } else {
        parts.push('candidates unchanged — no recompile')
      }
      if (bundle) {
        parts.push(
          `${backend} · ${humanCount(bundle.imports)} imports / ${humanBytes(bundle.importChars)} in`,
        )
      }
      detailEl.textContent = parts.join('   |   ')

      // Gzip is async, so it lands a beat later; a stale result must not overwrite
      // a newer one.
      const mine = ++token
      const gz = await gzipSize(css)
      if (mine === token && gz !== null) {
        sizeEl.textContent = `${humanBytes(bytes)} (${humanBytes(gz)} gz)`
      }
    },

    /** Show the median/min of a `compiler.benchmark()` run. */
    renderBenchmark(bench) {
      statusEl.textContent =
        `median ${humanUs(bench.medianUs)} · min ${humanUs(bench.minUs)} · n=${bench.runs}`
    },

    status(message) {
      statusEl.textContent = message
    },

    fail(message) {
      sizeEl.textContent = '—'
      timeEl.textContent = 'error'
      detailEl.textContent = message
    },
  }
}
