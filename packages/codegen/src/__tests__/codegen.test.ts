import { describe, it, expect } from 'vitest'
import { generateCode } from '../codegen'
import { generateSwiftFile, generateSwiftRegistration } from '../generators/swift'
import { generateKotlinFile, generateKotlinRegistration } from '../generators/kotlin'
import { generateTypeScriptFile } from '../generators/typescript'
import type { NativeBlock } from '@thelacanians/vue-native-sfc-parser'

describe('Code Generator', () => {
  const mockSwiftBlock: NativeBlock = {
    platform: 'ios',
    language: 'swift',
    content: `
class HapticsModule: NativeModule {
  var moduleName: String { "Haptics" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    switch method {
    case "vibrate":
      let style = args[0] as? String ?? "medium"
      vibrate(style: style)
      callback(nil, nil)
    default:
      callback(nil, "Unknown method")
    }
  }
  
  func vibrate(style: String) {
    // Implementation
  }
}
    `.trim(),
    sourceFile: '/test/TestComponent.vue',
    componentName: 'TestComponent',
    attributes: { platform: 'ios' },
    startLine: 10,
    endLine: 30,
  }

  const mockKotlinBlock: NativeBlock = {
    platform: 'android',
    language: 'kotlin',
    content: `
class HapticsModule: NativeModule {
  override val moduleName: String = "Haptics"
  
  override fun invoke(method: String, args: List<Any?>, callback: (Any?, String?) -> Unit) {
    when (method) {
      "vibrate" -> {
        val style = args[0] as? String ?: "medium"
        vibrate(style)
        callback(null, null)
      }
      else -> callback(null, "Unknown method")
    }
  }
  
  fun vibrate(style: String) {
    // Implementation
  }
}
    `.trim(),
    sourceFile: '/test/TestComponent.vue',
    componentName: 'TestComponent',
    attributes: { platform: 'android' },
    startLine: 10,
    endLine: 30,
  }

  describe('generateSwiftFile', () => {
    it('should generate Swift module file', () => {
      const file = generateSwiftFile(mockSwiftBlock)

      expect(file.platform).toBe('ios')
      expect(file.language).toBe('swift')
      expect(file.content).toContain('class HapticsModule: NativeModule')
      expect(file.content).toContain('var moduleName: String { "Haptics" }')
      expect(file.content).toContain('Auto-Generated Code')
      expect(file.outputPath).toContain('GeneratedModules/HapticsModule.swift')
    })

    it('should include custom output directory', () => {
      const file = generateSwiftFile(mockSwiftBlock, {
        iosOutputDir: 'custom/ios/output',
      })

      expect(file.outputPath).toContain('custom/ios/output/HapticsModule.swift')
    })

    it('should exclude header when includeHeader is false', () => {
      const file = generateSwiftFile(mockSwiftBlock, {
        includeHeader: false,
      })

      expect(file.content).not.toContain('Auto-Generated Code')
    })

    it('should use fallback class name when not found', () => {
      const block: NativeBlock = {
        ...mockSwiftBlock,
        content: 'class TestComponentModule: NativeModule { }',
      }

      const file = generateSwiftFile(block)
      expect(file.content).toContain('class TestComponentModule: NativeModule')
    })
  })

  describe('generateKotlinFile', () => {
    it('should generate Kotlin module file', () => {
      const file = generateKotlinFile(mockKotlinBlock)

      expect(file.platform).toBe('android')
      expect(file.language).toBe('kotlin')
      expect(file.content).toContain('class HapticsModule: NativeModule')
      expect(file.content).toContain('override val moduleName: String = "Haptics"')
      expect(file.content).toContain('Auto-Generated Code')
      expect(file.content).toContain('package com.vuenative.core.GeneratedModules')
      expect(file.outputPath).toContain('GeneratedModules/HapticsModule.kt')
    })

    it('should include custom output directory', () => {
      const file = generateKotlinFile(mockKotlinBlock, {
        androidOutputDir: 'custom/android/output',
      })

      expect(file.outputPath).toContain('custom/android/output/HapticsModule.kt')
    })
  })

  describe('generateTypeScriptFile', () => {
    it('should generate TypeScript composable file', () => {
      const file = generateTypeScriptFile([mockSwiftBlock], 'TestComponent')

      expect(file.platform).toBe('ios')
      expect(file.language).toBe('typescript')
      expect(file.content).toContain('export function useTestComponent()')
      expect(file.content).toContain('export interface TestComponentModule')
      expect(file.content).toContain('NativeBridge.invokeNativeModule')
      expect(file.outputPath).toContain('generated/useTestComponent.ts')
    })

    it('should generate type-safe interface', () => {
      const file = generateTypeScriptFile([mockSwiftBlock], 'TestComponent')

      expect(file.content).toContain('interface TestComponentModule')
      expect(file.content).toContain('vibrate(')
    })

    it('should throw when no blocks found for component', () => {
      expect(() => {
        generateTypeScriptFile([], 'NonExistent')
      }).toThrow('No native blocks found')
    })
  })

  describe('generateSwiftRegistration', () => {
    it('should generate Swift registration code', () => {
      const registration = generateSwiftRegistration([mockSwiftBlock])

      expect(registration).toContain('registerGeneratedModules()')
      expect(registration).toContain('register("Haptics", module: HapticsModule())')
    })

    it('should handle multiple modules', () => {
      const block2: NativeBlock = {
        ...mockSwiftBlock,
        content: `
class CameraModule: NativeModule {
  var moduleName: String { "Camera" }
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {}
}
        `.trim(),
        componentName: 'Camera',
      }

      const registration = generateSwiftRegistration([mockSwiftBlock, block2])

      expect(registration).toContain('register("Haptics", module: HapticsModule())')
      expect(registration).toContain('register("Camera", module: CameraModule())')
    })
  })

  describe('generateKotlinRegistration', () => {
    it('should generate Kotlin registration code', () => {
      const registration = generateKotlinRegistration([mockKotlinBlock])

      expect(registration).toContain('registerGeneratedModules()')
      expect(registration).toContain('register("Haptics", HapticsModule())')
    })
  })

  describe('generateCode', () => {
    it('should generate all files for multiple blocks', () => {
      const blocks: NativeBlock[] = [mockSwiftBlock, mockKotlinBlock]

      const result = generateCode(blocks)

      expect(result.files.length).toBeGreaterThan(0)
      expect(result.stats.swiftFiles).toBeGreaterThan(0)
      expect(result.stats.kotlinFiles).toBeGreaterThan(0)
      expect(result.stats.typescriptFiles).toBeGreaterThan(0)
      expect(result.errors).toHaveLength(0)
    })

    it('should respect generateSwift option', () => {
      const blocks: NativeBlock[] = [mockSwiftBlock]

      const result = generateCode(blocks, {
        generateSwift: false,
      })

      expect(result.stats.swiftFiles).toBe(0)
    })

    it('should respect generateKotlin option', () => {
      const blocks: NativeBlock[] = [mockKotlinBlock]

      const result = generateCode(blocks, {
        generateKotlin: false,
      })

      expect(result.stats.kotlinFiles).toBe(0)
    })

    it('should respect generateTypeScript option', () => {
      const blocks: NativeBlock[] = [mockSwiftBlock]

      const result = generateCode(blocks, {
        generateTypeScript: false,
      })

      expect(result.stats.typescriptFiles).toBe(0)
    })

    it('should group blocks by component for TypeScript generation', () => {
      const block2: NativeBlock = {
        ...mockSwiftBlock,
        componentName: 'TestComponent', // Same component
      }

      const result = generateCode([mockSwiftBlock, block2])

      // Should generate one composable for the component
      expect(result.stats.typescriptFiles).toBe(1)
    })

    it('should handle macOS blocks', () => {
      const macosBlock: NativeBlock = {
        ...mockSwiftBlock,
        platform: 'macos',
      }

      const result = generateCode([macosBlock])

      // macOS blocks generate Swift files (module + registration)
      expect(result.stats.swiftFiles).toBeGreaterThanOrEqual(1)
      expect(result.files.some(f => f.platform === 'macos' || f.sourceBlock.platform === 'macos')).toBe(true)
    })
  })

  describe('Method extraction', () => {
    it('should extract method signatures from Swift', () => {
      const block: NativeBlock = {
        ...mockSwiftBlock,
        content: `
class TestModule: NativeModule {
  var moduleName: String { "Test" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    switch method {
    case "fetch":
      fetch(url: args[0] as! String, timeout: args[1] as? Int ?? 30)
    case "save":
      save(data: args[0] as! String)
    default:
      callback(nil, "Unknown")
    }
  }
  
  func fetch(url: String, timeout: Int) { }
  func save(data: String) { }
}
        `.trim(),
      }

      const result = generateCode([block])

      // TypeScript should include both methods
      const tsFile = result.files.find(f => f.language === 'typescript')
      expect(tsFile).toBeDefined()
      expect(tsFile!.content).toContain('fetch(')
      expect(tsFile!.content).toContain('save(')
    })

    it('should extract method signatures from Kotlin', () => {
      const block: NativeBlock = {
        ...mockKotlinBlock,
        content: `
class TestModule: NativeModule {
  override val moduleName: String = "Test"

  override fun invoke(method: String, args: List<Any?>, callback: (Any?, String?) -> Unit) {
    when (method) {
      "fetch" -> fetch(args[0] as String)
      "save" -> save(args[0] as String)
      else -> callback(null, "Unknown")
    }
  }

  fun fetch(url: String) { }
  fun save(data: String) { }
}
        `.trim(),
      }

      const result = generateCode([block])

      const tsFile = result.files.find(f => f.language === 'typescript')
      expect(tsFile).toBeDefined()
      expect(tsFile!.content).toContain('fetch(')
      expect(tsFile!.content).toContain('save(')
    })
  })
})
