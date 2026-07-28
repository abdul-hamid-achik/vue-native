import { randomBytes } from 'node:crypto'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const TOKEN_DIR = join('node_modules', '.vue-native')
const TOKEN_FILE = 'hot-reload-token'

/**
 * Read the persisted hot-reload token for a project, generating and persisting
 * a fresh random one if none exists.
 *
 * Mirrors `getHotReloadToken` in `@thelacanians/vue-native-vite-plugin`: the
 * vite build embeds this token into the bundle (`__HOT_RELOAD_TOKEN__`) and the
 * dev server validates it when exposed to the network (`--lan`). Keeping the
 * read-or-generate logic identical in both packages means whichever runs first
 * persists the token and the other reads the same value.
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
