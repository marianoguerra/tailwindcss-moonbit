// Stubs for the upstream vitest harness.
//
// The upstream test file is executed, not parsed: `run()` records the arguments
// it is handed instead of compiling anything, so importing the file yields every
// candidate list upstream asserts on — including the ones built by loops and
// spreads, which no regex over the source would recover.
export const tests = []
let current = null

const RESULT = Symbol('run-result')

function define(name, fn) {
  tests.push({ name, fn })
}

export function test(name, fn) {
  define(name, fn)
}
test.only = define
test.skip = () => {}
test.each = () => () => {}

export function describe(name, fn) {
  fn()
}
describe.each = () => () => {}

export const vi = {
  fn: (implementation = () => {}) => implementation,
  spyOn: () => ({ mockImplementation: () => {}, mockRestore: () => {} }),
  restoreAllMocks: () => {},
}

// Upstream asserts a compiled result either with an inline snapshot (the
// candidates produce CSS) or with `.toEqual('')` (the candidates are rejected).
// Both land on the record `run()` returned, which is how a group learns which
// kind of assertion it belongs to.
function matchers(value) {
  const mark = (kind) => {
    if (value && value[RESULT]) value.expect = kind
  }
  const api = {
    toMatchInlineSnapshot: () => mark('output'),
    toMatchSnapshot: () => mark('output'),
    toEqual: (expected) => mark(expected === '' ? 'empty' : 'other'),
    toBe: (expected) => mark(expected === '' ? 'empty' : 'other'),
    toContain: () => mark('other'),
    toThrow: () => {},
    toThrowError: () => {},
  }
  api.not = api
  api.resolves = api
  api.rejects = api
  return api
}

export function expect(value) {
  return matchers(value)
}
expect.soft = expect
expect.extend = () => {}

export async function run(candidates, input = '@tailwind utilities;', options = {}) {
  const record = { [RESULT]: true, candidates, input, options, expect: null }
  current.runs.push(record)
  return record
}

export async function compileCss(css, options = {}) {
  return run([], css, options)
}

export function pretty(input) {
  return input
}

// Reached only by tests that drive the compiler directly; those are recorded as
// unportable rather than silently producing an empty case.
export function compile() {
  throw new Error('test drives compile() directly')
}

export const isValidFunctionalUtilityName = () => true
export const isValidStaticUtilityName = () => true

export function setCurrent(record) {
  current = record
}
