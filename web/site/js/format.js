// Number and byte formatting for the stats bar.
//
// The whole point of the stats bar is that a visitor can trust it, so these
// deliberately keep three significant figures instead of rounding to something
// prettier, and byte counts are measured, never estimated.

const KB = 1024
const MB = KB * 1024

/** 0 B · 947 B · 12.3 KB · 1.21 MB */
export function humanBytes(bytes) {
  if (!Number.isFinite(bytes)) return '—'
  if (bytes < KB) return `${bytes} B`
  if (bytes < MB) return `${trim(bytes / KB)} KB`
  return `${trim(bytes / MB)} MB`
}

/** 412 µs · 3.71 ms · 24.1 ms · 1.24 s */
export function humanMs(ms) {
  if (!Number.isFinite(ms)) return '—'
  if (ms < 1) return `${Math.round(ms * 1000)} µs`
  if (ms < 1000) return `${trim(ms)} ms`
  return `${trim(ms / 1000)} s`
}

/** Same, for a microsecond input — what the compiler reports. */
export function humanUs(us) {
  return humanMs(us / 1000)
}

/** 1,234 */
export function humanCount(value) {
  return Number(value).toLocaleString('en-US')
}

/** Three significant figures, without a trailing `.0`. */
function trim(value) {
  const digits = value >= 100 ? 0 : value >= 10 ? 1 : 2
  return value.toFixed(digits).replace(/\.0+$/, '')
}

/** UTF-8 byte length — what a server would actually send. */
export function byteLength(text) {
  return new TextEncoder().encode(text).length
}

/**
 * Gzipped byte length, or null where CompressionStream is unavailable.
 *
 * This is the number that makes the output-size story concrete: a 60 KB
 * stylesheet is ~10 KB over the wire.
 */
export async function gzipSize(text) {
  if (typeof CompressionStream === 'undefined') return null
  try {
    const stream = new Blob([text]).stream().pipeThrough(new CompressionStream('gzip'))
    return (await new Response(stream).arrayBuffer()).byteLength
  } catch {
    return null
  }
}

/** "accordion-using-details.html" -> "Accordion using details" */
export function humanize(name) {
  const base = name.replace(/\.html$/, '').replace(/[-_]+/g, ' ')
  return base.charAt(0).toUpperCase() + base.slice(1)
}
