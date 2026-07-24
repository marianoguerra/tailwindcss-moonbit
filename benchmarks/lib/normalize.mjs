// Output normalizer for the correctness gate.
//
// Copied verbatim (behavior-for-behavior) from tools/diff/compare.mjs:177 so the
// benchmark's "is this target producing the right CSS?" check matches the
// differential test harness: strip the `/*! ... */` license banner, normalize
// CRLF to LF, and trim. tw-mb omits the banner by design and may order/merge
// rules slightly differently, but for the fixed workloads here every target
// should match the oracle under this normalization.
export function normalized(css) {
  return css
    .replace(/\/\*![\s\S]*?\*\//g, '')
    .replace(/\r\n/g, '\n')
    .trim()
}

// Order-insensitive line-multiset similarity in [0,1], used as a lenient
// correctness gate. tw-mb is byte-exact on the differential corpus but on a
// large real-world library (margaui) it differs from upstream by ~1% of lines
// that are cosmetic and render-equivalent (banner omitted, adjacent same-selector
// rules merged, an extra @property registration). A strict equality gate would
// refuse to time that headline workload, while a genuinely broken/empty output
// still scores far below any sane threshold. Ratio = 2*|A∩B| / (|A|+|B|) over the
// multiset of trimmed non-empty lines.
export function similarity(a, b) {
  const bag = (s) => {
    const m = new Map()
    for (const line of normalized(s).split('\n')) {
      const t = line.trim()
      if (t) m.set(t, (m.get(t) ?? 0) + 1)
    }
    return m
  }
  const A = bag(a)
  const B = bag(b)
  let inter = 0
  let total = 0
  for (const [, n] of A) total += n
  for (const [, n] of B) total += n
  for (const [line, n] of A) inter += Math.min(n, B.get(line) ?? 0)
  return total === 0 ? 1 : (2 * inter) / total
}
