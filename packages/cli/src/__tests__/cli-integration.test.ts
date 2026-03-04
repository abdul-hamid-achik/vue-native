/**
 * CLI command tests
 *
 * Tests for the vue-native generate command
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { existsSync, mkdirSync, rmSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { execSync } from 'node:child_process'

/**
 * Create a temporary test directory
 */
function createTestDir(name: string): string {
  const testDir = join(process.cwd(), 'test-output', 'cli', name)
  if (existsSync(testDir)) {
    rmSync(testDir, { recursive: true })
  }
  mkdirSync(testDir, { recursive: true })
  return testDir
}

/**
 * Write test SFC file
 */
function writeTestSFC(dir: string, filename: string, content: string): void {
  const appDir = join(dir, 'app')
  if (!existsSync(appDir)) {
    mkdirSync(appDir, { recursive: true })
  }
  const appFilepath = join(appDir, filename)
  writeFileSync(appFilepath, content, 'utf-8')
}

describe('CLI Command Tests', () => {
  let testDir: string

  beforeEach(() => {
    testDir = createTestDir('cli-test')
  })

  afterEach(() => {
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true })
    }
  })

  describe('vue-native generate', () => {
    it('should generate code successfully', () => {
      const sfc = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        class TestModule: NativeModule {
          var moduleName: String { "Test" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Test.vue', sfc)

      // Run generate command
      const output = execSync('bunx vue-native generate', {
        cwd: testDir,
        encoding: 'utf-8',
        stdio: 'pipe',
      })

      expect(output).toContain('Vue Native Code Generator')
      expect(output).toContain('Found 1 <native> block')
      expect(output).toContain('Validation passed')
      expect(output).toContain('Generation complete')
    })

    it('should show validation errors', () => {
      const invalidSFC = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        // Invalid: missing class
        </native>
      `

      writeTestSFC(testDir, 'Invalid.vue', invalidSFC)

      try {
        execSync('bunx vue-native generate', {
          cwd: testDir,
          encoding: 'utf-8',
          stdio: 'pipe',
        })
        // Should not reach here
        expect(true).toBe(false)
      } catch (error: any) {
        expect(error.stdout).toContain('Validation failed')
        expect(error.status).toBe(1)
      }
    })

    it('should handle custom output directories', () => {
      const sfc = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        class TestModule: NativeModule {
          var moduleName: String { "Test" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Test.vue', sfc)

      const customDir = join(testDir, 'custom', 'output')

      const output = execSync(
        `bunx vue-native generate --ios-output ${customDir}`,
        {
          cwd: testDir,
          encoding: 'utf-8',
          stdio: 'pipe',
        },
      )

      expect(output).toContain('Generation complete')
      expect(existsSync(join(customDir, 'TestModule.swift'))).toBe(true)
    })

    it('should clean generated files with --clean', () => {
      const sfc = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        class TestModule: NativeModule {
          var moduleName: String { "Test" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Test.vue', sfc)

      // Generate first
      execSync('bunx vue-native generate', {
        cwd: testDir,
        encoding: 'utf-8',
        stdio: 'pipe',
      })

      // Clean and regenerate
      const output = execSync('bunx vue-native generate --clean', {
        cwd: testDir,
        encoding: 'utf-8',
        stdio: 'pipe',
      })

      expect(output).toContain('Cleaning generated files')
      expect(output).toContain('Generation complete')
    })

    it('should handle no native blocks gracefully', () => {
      const sfc = `
        <template>
          <VView><VText>No native blocks</VText></VView>
        </template>
        
        <script setup lang="ts">
        import { ref } from 'vue'
        </script>
      `

      writeTestSFC(testDir, 'NoNative.vue', sfc)

      const output = execSync('bunx vue-native generate', {
        cwd: testDir,
        encoding: 'utf-8',
        stdio: 'pipe',
      })

      expect(output).toContain('No <native> blocks found')
    })

    it('should respect --no-typescript flag', () => {
      const sfc = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        class TestModule: NativeModule {
          var moduleName: String { "Test" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Test.vue', sfc)

      const output = execSync('bunx vue-native generate --no-typescript', {
        cwd: testDir,
        encoding: 'utf-8',
        stdio: 'pipe',
      })

      expect(output).toContain('Generation complete')
      // Should not generate TypeScript files
      expect(existsSync(join(testDir, 'app', 'generated', 'useTestModule.ts'))).toBe(false)
    })

    it('should show warnings for cross-platform inconsistency', () => {
      const sfc = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        class TestModule: NativeModule {
          var moduleName: String { "IOSModule" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
        <native platform="android">
        class TestModule: NativeModule {
          override val moduleName: String = "AndroidModule"
          override fun invoke(method: String, args: List<Any?>, callback: (Any?, String?) -> Unit) {
            callback(null, null)
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Test.vue', sfc)

      const output = execSync('bunx vue-native generate', {
        cwd: testDir,
        encoding: 'utf-8',
        stdio: 'pipe',
      })

      expect(output).toContain('warning')
    })
  })

  describe('CLI Help', () => {
    it('should show help for generate command', () => {
      const output = execSync('bunx vue-native generate --help', {
        encoding: 'utf-8',
        stdio: 'pipe',
      })

      expect(output).toContain('Generate native code from <native> blocks')
      expect(output).toContain('--root')
      expect(output).toContain('--watch')
      expect(output).toContain('--clean')
      expect(output).toContain('--ios-output')
      expect(output).toContain('--android-output')
    })
  })
})
