import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(fileURLToPath(new URL('..', import.meta.url)))

export const APP_SHELL_FIXTURE_PATH = join(root, 'fixtures', 'app-shell', 'vue-native-bundle.js')
export const APP_SHELL_ROOT_LABEL = 'app-shell-root'
export const APP_SHELL_LABEL = 'app-shell-label'
export const APP_SHELL_TEXT = 'app-shell-ok'

export function loadAppShellFixture() {
  if (!existsSync(APP_SHELL_FIXTURE_PATH)) {
    throw new Error(`App-shell fixture missing at ${APP_SHELL_FIXTURE_PATH}`)
  }
  return readFileSync(APP_SHELL_FIXTURE_PATH, 'utf8')
}

export function collectAppShellFixtureErrors(source = loadAppShellFixture()) {
  const errors = []
  if (!source.includes('__VN_flushOperations')) {
    errors.push('fixture must call __VN_flushOperations')
  }
  if (!source.includes(APP_SHELL_ROOT_LABEL)) {
    errors.push(`fixture must declare ${APP_SHELL_ROOT_LABEL}`)
  }
  if (!source.includes(APP_SHELL_LABEL)) {
    errors.push(`fixture must declare ${APP_SHELL_LABEL}`)
  }
  if (!source.includes(APP_SHELL_TEXT)) {
    errors.push(`fixture must declare ${APP_SHELL_TEXT}`)
  }
  if (/\bimport\s+|require\s*\(/.test(source)) {
    errors.push('fixture must be a standalone IIFE without import/require')
  }
  return errors
}

export function repoRootFrom(url = import.meta.url) {
  return resolve(dirname(fileURLToPath(url)), '..')
}
