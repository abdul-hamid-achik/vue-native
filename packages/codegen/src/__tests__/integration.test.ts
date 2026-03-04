/**
 * Integration tests for Vue Native <native> blocks code generation
 *
 * These tests verify the complete pipeline from SFC parsing to code generation
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { existsSync, mkdirSync, rmSync, writeFileSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { parseDirectory } from '@thelacanians/vue-native-sfc-parser'
import { generateCode, validateNativeBlocks } from '@thelacanians/vue-native-codegen'

/**
 * Create a temporary test directory
 */
function createTestDir(name: string): string {
  const testDir = join(process.cwd(), 'test-output', name)
  if (existsSync(testDir)) {
    rmSync(testDir, { recursive: true })
  }
  mkdirSync(testDir, { recursive: true })
  return testDir
}

/**
 * Write test SFC file
 */
function writeTestSFC(dir: string, filename: string, content: string): string {
  const filepath = join(dir, filename)
  const appDir = join(dir, 'app')
  if (!existsSync(appDir)) {
    mkdirSync(appDir, { recursive: true })
  }
  const appFilepath = join(appDir, filename)
  writeFileSync(appFilepath, content, 'utf-8')
  return appFilepath
}

describe('Integration Tests', () => {
  let testDir: string

  beforeEach(() => {
    testDir = createTestDir('integration-test')
  })

  afterEach(() => {
    if (existsSync(testDir)) {
      rmSync(testDir, { recursive: true })
    }
  })

  describe('End-to-End Code Generation', () => {
    it('should generate all files from valid SFC', () => {
      const sfc = `
        <template>
          <VView><VText>Test</VText></VView>
        </template>
        
        <native platform="ios">
        class TestModule: NativeModule {
          var moduleName: String { "Test" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
        
        <native platform="android">
        class TestModule: NativeModule {
          override val moduleName: String = "Test"
          override fun invoke(method: String, args: List<Any?>, callback: (Any?, String?) -> Unit) {
            callback(null, null)
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Test.vue', sfc)

      // Parse
      const parseResult = parseDirectory('app', { root: testDir })

      expect(parseResult.errors).toHaveLength(0)
      expect(parseResult.allNativeBlocks.length).toBe(2)

      // Validate
      const validation = validateNativeBlocks(parseResult.allNativeBlocks)
      expect(validation.isValid).toBe(true)

      // Generate
      const codegen = generateCode(parseResult.allNativeBlocks, {
        root: testDir,
        iosOutputDir: join(testDir, 'native', 'ios', 'GeneratedModules'),
        androidOutputDir: join(testDir, 'native', 'android', 'GeneratedModules'),
        typescriptOutputDir: join(testDir, 'app', 'generated'),
      })

      expect(codegen.errors).toHaveLength(0)
      expect(codegen.stats.swiftFiles).toBeGreaterThan(0)
      expect(codegen.stats.kotlinFiles).toBeGreaterThan(0)
      expect(codegen.stats.typescriptFiles).toBeGreaterThan(0)
    })

    it('should handle multiple components', () => {
      const sfc1 = `
        <template><VView>Component 1</VView></template>
        <native platform="ios">
        class Module1: NativeModule {
          var moduleName: String { "Module1" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
      `

      const sfc2 = `
        <template><VView>Component 2</VView></template>
        <native platform="ios">
        class Module2: NativeModule {
          var moduleName: String { "Module2" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Component1.vue', sfc1)
      writeTestSFC(testDir, 'Component2.vue', sfc2)

      const parseResult = parseDirectory('app', { root: testDir })

      expect(parseResult.allNativeBlocks.length).toBe(2)

      const codegen = generateCode(parseResult.allNativeBlocks)

      expect(codegen.stats.swiftFiles).toBe(2)
      expect(codegen.stats.typescriptFiles).toBe(2)
    })

    it('should generate compilable Swift code', () => {
      const sfc = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        class CompilableModule: NativeModule {
          var moduleName: String { "Compilable" }
          
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            switch method {
            case "test":
              testMethod()
              callback("success", nil)
            default:
              callback(nil, "Unknown method")
            }
          }
          
          func testMethod() {
            let value = 42
            print("Test: \\(value)")
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Compilable.vue', sfc)
      const parseResult = parseDirectory('app', { root: testDir })
      const codegen = generateCode(parseResult.allNativeBlocks)

      expect(codegen.errors).toHaveLength(0)

      // Check generated Swift has proper syntax
      const swiftFile = codegen.files.find(f => f.language === 'swift')
      expect(swiftFile).toBeDefined()
      expect(swiftFile!.content).toContain('class CompilableModule: NativeModule')
      expect(swiftFile!.content).toContain('var moduleName: String { "Compilable" }')
      expect(swiftFile!.content).toContain('func invoke(')
    })

    it('should generate compilable Kotlin code', () => {
      const sfc = `
        <template><VView>Test</VView></template>
        <native platform="android">
        class CompilableModule: NativeModule {
          override val moduleName: String = "Compilable"
          
          override fun invoke(method: String, args: List<Any?>, callback: (Any?, String?) -> Unit) {
            when (method) {
              "test" -> {
                testMethod()
                callback("success", null)
              }
              else -> callback(null, "Unknown method")
            }
          }
          
          fun testMethod() {
            val value = 42
            println("Test: $value")
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Compilable.vue', sfc)
      const parseResult = parseDirectory('app', { root: testDir })
      const codegen = generateCode(parseResult.allNativeBlocks)

      expect(codegen.errors).toHaveLength(0)

      // Check generated Kotlin has proper syntax
      const kotlinFile = codegen.files.find(f => f.language === 'kotlin')
      expect(kotlinFile).toBeDefined()
      expect(kotlinFile!.content).toContain('class CompilableModule: NativeModule')
      expect(kotlinFile!.content).toContain('override val moduleName: String = "Compilable"')
      expect(kotlinFile!.content).toContain('override fun invoke(')
    })
  })

  describe('Validation Integration', () => {
    it('should catch validation errors before generation', () => {
      const invalidSFC = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        // Invalid: missing class declaration
        func test() {}
        </native>
      `

      writeTestSFC(testDir, 'Invalid.vue', invalidSFC)
      const parseResult = parseDirectory('app', { root: testDir })

      const validation = validateNativeBlocks(parseResult.allNativeBlocks)

      expect(validation.isValid).toBe(false)
      expect(validation.errors.length).toBeGreaterThan(0)
    })

    it('should stop generation on validation errors', () => {
      const invalidSFC = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        class InvalidModule {
          // Missing: NativeModule conformance
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Invalid.vue', invalidSFC)
      const parseResult = parseDirectory('app', { root: testDir })
      const codegen = generateCode(parseResult.allNativeBlocks)

      // Should have validation errors and no files generated
      expect(codegen.errors.length).toBeGreaterThan(0)
      expect(codegen.files).toHaveLength(0)
    })

    it('should allow generation with warnings', () => {
      const sfcWithWarnings = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        class WarningModule: NativeModule {
          var moduleName: String { "Warning" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            // No error handling - will generate warning
            callback(nil, nil)
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Warning.vue', sfcWithWarnings)
      const parseResult = parseDirectory('app', { root: testDir })
      const codegen = generateCode(parseResult.allNativeBlocks)

      // Should generate files even with warnings
      expect(codegen.files.length).toBeGreaterThan(0)
    })
  })

  describe('Cross-Platform Consistency', () => {
    it('should warn about inconsistent module names', () => {
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
      const parseResult = parseDirectory('app', { root: testDir })
      const validation = validateNativeBlocks(parseResult.allNativeBlocks)

      expect(validation.warnings.length).toBeGreaterThan(0)
      expect(validation.warnings.some(w => w.message.includes('module names'))).toBe(true)
    })

    it('should generate consistent TypeScript interfaces', () => {
      const sfc = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        class ConsistentModule: NativeModule {
          var moduleName: String { "Consistent" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            switch method {
            case "method1": method1()
            case "method2": method2()
            }
            callback(nil, nil)
          }
          func method1() {}
          func method2() {}
        }
        </native>
        <native platform="android">
        class ConsistentModule: NativeModule {
          override val moduleName: String = "Consistent"
          override fun invoke(method: String, args: List<Any?>, callback: (Any?, String?) -> Unit) {
            when (method) {
              "method1" -> method1()
              "method2" -> method2()
            }
            callback(null, null)
          }
          fun method1() {}
          fun method2() {}
        }
        </native>
      `

      writeTestSFC(testDir, 'Test.vue', sfc)
      const parseResult = parseDirectory('app', { root: testDir })
      const codegen = generateCode(parseResult.allNativeBlocks)

      const tsFile = codegen.files.find(f => f.language === 'typescript')
      expect(tsFile).toBeDefined()
      expect(tsFile!.content).toContain('method1(')
      expect(tsFile!.content).toContain('method2(')
    })
  })

  describe('Performance', () => {
    it('should parse and generate within time budget', () => {
      const sfc = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        class PerformanceModule: NativeModule {
          var moduleName: String { "Performance" }
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
      `

      writeTestSFC(testDir, 'Performance.vue', sfc)

      const start = performance.now()

      const parseResult = parseDirectory('app', { root: testDir })
      const codegen = generateCode(parseResult.allNativeBlocks)

      const duration = performance.now() - start

      // Should complete in under 100ms for single file
      expect(duration).toBeLessThan(100)
      expect(codegen.files.length).toBeGreaterThan(0)
    })

    it('should handle multiple files efficiently', () => {
      // Create 10 SFC files
      for (let i = 0; i < 10; i++) {
        const sfc = `
          <template><VView>Test ${i}</VView></template>
          <native platform="ios">
          class Module${i}: NativeModule {
            var moduleName: String { "Module${i}" }
            func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
              callback(nil, nil)
            }
          }
          </native>
        `
        writeTestSFC(testDir, `Test${i}.vue`, sfc)
      }

      const start = performance.now()

      const parseResult = parseDirectory('app', { root: testDir })
      const codegen = generateCode(parseResult.allNativeBlocks)

      const duration = performance.now() - start

      // Should complete in under 500ms for 10 files
      expect(duration).toBeLessThan(500)
      expect(codegen.stats.swiftFiles).toBe(10)
      expect(codegen.stats.typescriptFiles).toBe(10)
    })
  })

  describe('Error Recovery', () => {
    it('should recover from invalid SFC', () => {
      // Write invalid SFC first
      const invalidSFC = `
        <template><VView>Test</VView></template>
        <native platform="ios">
        // Invalid
        </native>
      `
      writeTestSFC(testDir, 'Test.vue', invalidSFC)

      let parseResult = parseDirectory('app', { root: testDir })
      expect(parseResult.allNativeBlocks.length).toBe(0)

      // Fix the SFC
      const validSFC = `
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
      writeTestSFC(testDir, 'Test.vue', validSFC)

      parseResult = parseDirectory('app', { root: testDir })
      const codegen = generateCode(parseResult.allNativeBlocks)

      expect(codegen.files.length).toBeGreaterThan(0)
    })
  })
})
