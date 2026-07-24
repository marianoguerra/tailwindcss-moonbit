// Environment metadata capture — recorded in results.json so a number is always
// interpretable against the machine and toolchain that produced it.
import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import os from 'node:os'
import { join } from 'node:path'

function tryExec(command, args) {
  try {
    return execFileSync(command, args, { encoding: 'utf8' }).trim()
  } catch {
    return null
  }
}

export function captureEnv(root) {
  const cpus = os.cpus() ?? []
  let oracleVersion = null
  try {
    oracleVersion = JSON.parse(
      readFileSync(
        join(root, 'tools/oracle/node_modules/tailwindcss/package.json'),
        'utf8',
      ),
    ).version
  } catch {
    // leave null
  }
  return {
    // ISO timestamp; callers may prefer to stamp their own.
    timestamp: new Date().toISOString(),
    node: process.version,
    moon: tryExec('moon', ['version']),
    uname: tryExec('uname', ['-a']),
    platform: `${os.platform()} ${os.release()}`,
    cpu: cpus[0]?.model ?? 'unknown',
    cpuCount: cpus.length,
    totalMemGB: Math.round((os.totalmem() / 1024 ** 3) * 10) / 10,
    gitCommit: tryExec('git', ['-C', root, 'rev-parse', 'HEAD']),
    gitDirty: tryExec('git', ['-C', root, 'status', '--porcelain']) ? true : false,
    tailwindcssOracleVersion: oracleVersion,
  }
}
