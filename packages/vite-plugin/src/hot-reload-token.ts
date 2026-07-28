import { randomBytes } from 'node:crypto'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

/**
 * Directory (relative to the project root) where the dev hot-reload token is
 * persisted, inside node_modules so it is never committed.
 */
const TOKEN_DIR = join('node_modules', '.vue-native')
const TOKEN_FILE = 'hot-reload-token'

/**
 * Read the persisted hot-reload token for a project, generating and persisting
 * a fresh random one if none exists.
 *
 * The token is a build-time shared secret embedded into the JS bundle (via the
 * `__HOT_RELOAD_TOKEN__` define) and validated by `vue-native dev` when the dev
 * server is exposed to the network (`--lan`). Persisting it across sessions lets
 * an already-built app authenticate to a freshly started dev server.
 */
export function getHotReloadToken(root: string): string {
  const dir = join(root, TOKEN_DIR)
  const file = join(dir, TOKEN_FILE)
  try {
    const existing = readFileSync(file, 'utf8').trim()
    if (existing.length >= 32) return existing
  } catch {
    // Missing/unreadable token file — generate a new one below.
  }
  const token = randomBytes(32).toString('hex')
  try {
    mkdirSync(dir, { recursive: true })
    writeFileSync(file, token, 'utf8')
  } catch {
    // Best effort: even if persistence fails, return the token for this session.
  }
  return token
}
