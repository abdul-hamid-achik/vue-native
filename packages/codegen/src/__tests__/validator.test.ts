import { describe, it, expect } from 'vitest'
import { validateNativeBlocks, formatValidationErrors, getDiagnostics } from '../validator'
import type { NativeBlock } from '@thelacanians/vue-native-sfc-parser'

describe('Validator', () => {
  describe('validateNativeBlocks', () => {
    it('should pass valid Swift module', () => {
      const block: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Test" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    callback(nil, nil)
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
        startLine: 10,
        endLine: 20,
      }

      const result = validateNativeBlocks([block])

      expect(result.isValid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })

    it('should pass valid Kotlin module', () => {
      const block: NativeBlock = {
        platform: 'android',
        language: 'kotlin',
        content: `
class TestModule: NativeModule {
  override val moduleName: String = "Test"
  
  override fun invoke(method: String, args: List<Any?>, callback: (Any?, String?) -> Unit) {
    callback(null, null)
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
        startLine: 10,
        endLine: 20,
      }

      const result = validateNativeBlocks([block])

      expect(result.isValid).toBe(true)
      expect(result.errors).toHaveLength(0)
    })

    it('should error when Swift module missing class declaration', () => {
      const block: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
func someFunction() { }
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const result = validateNativeBlocks([block])

      expect(result.isValid).toBe(false)
      expect(result.errors.some(e => e.message.includes('class'))).toBe(true)
    })

    it('should error when Swift module missing moduleName', () => {
      const block: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    callback(nil, nil)
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const result = validateNativeBlocks([block])

      expect(result.isValid).toBe(false)
      expect(result.errors.some(e => e.message.includes('moduleName'))).toBe(true)
    })

    it('should error when Swift module missing invoke method', () => {
      const block: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Test" }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const result = validateNativeBlocks([block])

      expect(result.isValid).toBe(false)
      expect(result.errors.some(e => e.message.includes('invoke'))).toBe(true)
    })

    it('should error when Kotlin module missing moduleName', () => {
      const block: NativeBlock = {
        platform: 'android',
        language: 'kotlin',
        content: `
class TestModule: NativeModule {
  override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
    callback(null, null)
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const result = validateNativeBlocks([block])

      expect(result.isValid).toBe(false)
      expect(result.errors.some(e => e.message.includes('moduleName'))).toBe(true)
    })

    it('should error when unbalanced braces in Swift', () => {
      const block: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Test" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    callback(nil, nil)
  // Missing closing brace
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const result = validateNativeBlocks([block])

      expect(result.isValid).toBe(false)
      expect(result.errors.some(e => e.message.includes('brace'))).toBe(true)
    })

    it('should error when unbalanced braces in Kotlin', () => {
      const block: NativeBlock = {
        platform: 'android',
        language: 'kotlin',
        content: `
class TestModule: NativeModule {
  override val moduleName: String = "Test"
  
  override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
    callback(null, null)
  // Missing closing brace
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const result = validateNativeBlocks([block])

      expect(result.isValid).toBe(false)
      expect(result.errors.some(e => e.message.includes('brace'))).toBe(true)
    })

    it('should error when callback not called', () => {
      const block: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Test" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    // Forgot to call callback
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const result = validateNativeBlocks([block])

      expect(result.isValid).toBe(false)
      expect(result.errors.some(e => e.message.includes('callback'))).toBe(true)
    })

    it('should warn about cross-platform module name inconsistency', () => {
      const iosBlock: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Haptics" }
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    callback(nil, nil)
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const androidBlock: NativeBlock = {
        platform: 'android',
        language: 'kotlin',
        content: `
class TestModule: NativeModule {
  override val moduleName: String = "Vibration"
  override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
    callback(null, null)
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const result = validateNativeBlocks([iosBlock, androidBlock])

      expect(result.warnings.some(w => w.message.includes('module names'))).toBe(true)
    })

    it('should handle multiple blocks', () => {
      const validBlock: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class ValidModule: NativeModule {
  var moduleName: String { "Valid" }
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    callback(nil, nil)
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const invalidBlock: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class InvalidModule: NativeModule {
  // Missing everything
}
        `.trim(),
        sourceFile: '/test/Test2.vue',
        componentName: 'Test2',
        attributes: {},
      }

      const result = validateNativeBlocks([validBlock, invalidBlock])

      expect(result.isValid).toBe(false)
      expect(result.errors.length).toBeGreaterThan(0)
    })
  })

  describe('formatValidationErrors', () => {
    it('should format errors nicely', () => {
      const result = {
        errors: [{
          file: '/test/Test.vue',
          line: 10,
          message: 'Missing moduleName',
        }],
        warnings: [],
        isValid: false,
      }

      const formatted = formatValidationErrors(result)

      expect(formatted).toContain('❌ Errors:')
      expect(formatted).toContain('Test.vue:10')
      expect(formatted).toContain('Missing moduleName')
    })

    it('should format warnings nicely', () => {
      const result = {
        errors: [],
        warnings: [{
          file: '/test/Test.vue',
          line: 15,
          message: 'Consider using nullable types',
        }],
        isValid: true,
      }

      const formatted = formatValidationErrors(result)

      expect(formatted).toContain('⚠️  Warnings:')
      expect(formatted).toContain('Test.vue:15')
    })
  })

  describe('getDiagnostics', () => {
    it('should return correct method count', () => {
      const block: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Test" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    switch method {
    case "method1": method1()
    case "method2": method2()
    case "method3": method3()
    }
    callback(nil, nil)
  }
  
  func method1() { }
  func method2() { }
  func method3() { }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const diagnostics = getDiagnostics(block)

      expect(diagnostics.methodCount).toBe(3)
    })

    it('should detect error handling', () => {
      const blockWithErrorHandling: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Test" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    do {
      try someThrowingFunction()
      callback(nil, nil)
    } catch {
      callback(nil, error.localizedDescription)
    }
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const diagnostics = getDiagnostics(blockWithErrorHandling)

      expect(diagnostics.hasErrorHandling).toBe(true)
    })

    it('should detect missing error handling', () => {
      const blockWithoutErrorHandling: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Test" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    someThrowingFunction()
    callback(nil, nil)
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const diagnostics = getDiagnostics(blockWithoutErrorHandling)

      expect(diagnostics.hasErrorHandling).toBe(false)
    })

    it('should calculate complexity correctly', () => {
      const simpleBlock: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Test" }
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    callback(nil, nil)
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const diagnostics = getDiagnostics(simpleBlock)

      // This block has 10 lines and 4 braces, so it's medium complexity
      expect(diagnostics.complexity).toBe('medium')
    })

    it('should provide suggestions', () => {
      const block: NativeBlock = {
        platform: 'ios',
        language: 'swift',
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Test" }
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    callback(nil, nil)
  }
}
        `.trim(),
        sourceFile: '/test/Test.vue',
        componentName: 'Test',
        attributes: {},
      }

      const diagnostics = getDiagnostics(block)

      expect(diagnostics.suggestions.length).toBeGreaterThan(0)
    })
  })
})
