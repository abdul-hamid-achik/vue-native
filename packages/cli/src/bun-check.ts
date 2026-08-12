import { execFileSync } from 'node:child_process'
import { ConfigError } from './config.js'

/**
 * Verify `bun` is reachable on PATH before spawning it. Without this check,
 * a missing bun surfaces as a raw `spawn bun ENOENT` deep inside a child
 * process — or, in the dev server's case, as a silent hang, since the
 * WebSocket server and its keep-alive interval keep the process alive after
 * the spawn error is merely logged. Throws a ConfigError with the given
 * actionable message instead.
 */
export function ensureBunAvailable(message: string): void {
  try {
    execFileSync('bun', ['--version'], { stdio: 'ignore' })
  } catch {
    throw new ConfigError(message)
  }
}
