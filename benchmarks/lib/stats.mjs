// Robust summary statistics over a raw sample array (microseconds per compile).
//
// We report median and min as the headline (both robust to GC pauses and
// scheduler noise, which only ever inflate a sample), plus mean/stddev/p95 for
// distribution shape and ops/sec derived from the median.

function sorted(samples) {
  return [...samples].sort((a, b) => a - b)
}

function quantile(sortedSamples, q) {
  // Nearest-rank on the already-sorted array.
  if (sortedSamples.length === 0) return NaN
  const rank = Math.ceil(q * sortedSamples.length)
  const index = Math.min(Math.max(rank - 1, 0), sortedSamples.length - 1)
  return sortedSamples[index]
}

export function summarize(samples) {
  const n = samples.length
  if (n === 0) {
    return { n: 0 }
  }
  const s = sorted(samples)
  const min = s[0]
  const max = s[n - 1]
  const mean = samples.reduce((a, b) => a + b, 0) / n
  const median =
    n % 2 === 1
      ? s[(n - 1) / 2]
      : (s[n / 2 - 1] + s[n / 2]) / 2
  const variance =
    n > 1 ? samples.reduce((a, b) => a + (b - mean) ** 2, 0) / (n - 1) : 0
  const stddev = Math.sqrt(variance)
  const p95 = quantile(s, 0.95)
  return {
    n,
    min_us: min,
    max_us: max,
    mean_us: mean,
    median_us: median,
    stddev_us: stddev,
    p95_us: p95,
    // Steady-state throughput implied by the median single-compile time.
    ops_per_sec: median > 0 ? 1e6 / median : Infinity,
  }
}
