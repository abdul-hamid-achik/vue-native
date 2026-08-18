import assert from 'node:assert/strict'
import { test } from 'node:test'
import {
  APP_SHELL_FIXTURE_PATH,
  APP_SHELL_LABEL,
  APP_SHELL_ROOT_LABEL,
  APP_SHELL_TEXT,
  collectAppShellFixtureErrors,
  loadAppShellFixture,
} from '../app-shell-fixture.mjs'

test('app-shell fixture is a standalone bridge IIFE with stable test ids', () => {
  const source = loadAppShellFixture()
  assert.match(APP_SHELL_FIXTURE_PATH, /fixtures\/app-shell\/vue-native-bundle\.js$/)
  assert.equal(collectAppShellFixtureErrors(source).length, 0)
  assert.match(source, /__VN_flushOperations/)
  assert.match(source, new RegExp(APP_SHELL_ROOT_LABEL))
  assert.match(source, new RegExp(APP_SHELL_LABEL))
  assert.match(source, new RegExp(APP_SHELL_TEXT))
})
