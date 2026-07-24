// Ergonomic JavaScript wrapper around the MoonBit Tailwind compiler.
//
// It expects the compiled MoonBit ESM module next to this file as `./ffi.js`
// (see ./README.md for the build + copy step). The wrapper adds no runtime
// dependencies.

import { compile_css_json } from './ffi.js'

/**
 * Compile a Tailwind v4 stylesheet in memory.
 *
 * @param {object} request
 * @param {string} request.input        Entry CSS source.
 * @param {string[]} [request.candidates=[]]  Utility class names to generate.
 * @param {Object<string,string>} [request.imports={}]
 *        In-memory map of path -> stylesheet content used to resolve `@import`.
 *        There is no filesystem access, so every `@import` must be listed here.
 * @param {string} [request.base='']    Base directory for resolving relative imports.
 * @param {string} [request.from]       Path of the entry stylesheet (for import resolution).
 * @param {number} [request.polyfills=3]
 *        Bitmask: 0=none, 1=@property, 2=color-mix, 3=all.
 * @returns {{ css: string }}
 * @throws {Error} if compilation fails.
 */
export function compile({
  input,
  candidates = [],
  imports = {},
  base = '',
  from,
  polyfills = 3,
} = {}) {
  if (typeof input !== 'string') {
    throw new TypeError('compile: `input` (CSS string) is required')
  }
  const request = { css: input, candidates, imports, base, polyfills }
  if (from !== undefined) request.from = from

  const result = JSON.parse(compile_css_json(JSON.stringify(request)))
  if (!result.ok) {
    throw new Error(`tailwindcss: ${result.error}`)
  }
  return { css: result.css }
}

export default compile
