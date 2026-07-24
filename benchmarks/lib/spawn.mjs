// Thin wrapper over spawnSync for driving subprocess-based runners.
import { spawnSync } from 'node:child_process'

// Run a command, returning { ok, status, stdout, stderr }. maxBuffer is bumped
// so large emitted CSS (full-import / margaui) is never truncated.
export function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    encoding: 'utf8',
    maxBuffer: 256 * 1024 * 1024,
    ...options,
  })
  if (result.error) {
    return { ok: false, status: null, stdout: '', stderr: String(result.error) }
  }
  return {
    ok: result.status === 0,
    status: result.status,
    stdout: result.stdout ?? '',
    stderr: result.stderr ?? '',
  }
}

// Run a command whose stdout contains exactly one JSON object (possibly preceded
// by build/warning noise on stderr). Extracts the last `{...}` line and parses
// it. Returns { ok, json?, raw, stderr }.
export function runJson(command, args, options = {}) {
  const result = run(command, args, options)
  if (!result.ok) {
    return { ok: false, json: null, raw: result.stdout, stderr: result.stderr }
  }
  const line = result.stdout
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l.startsWith('{') && l.endsWith('}'))
    .at(-1)
  if (!line) {
    return {
      ok: false,
      json: null,
      raw: result.stdout,
      stderr: `${result.stderr}\nno JSON object on stdout`,
    }
  }
  try {
    return { ok: true, json: JSON.parse(line), raw: result.stdout, stderr: result.stderr }
  } catch (error) {
    return {
      ok: false,
      json: null,
      raw: result.stdout,
      stderr: `${result.stderr}\nJSON parse failed: ${error}`,
    }
  }
}
