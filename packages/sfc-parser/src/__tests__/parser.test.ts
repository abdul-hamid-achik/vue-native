import { describe, it, expect } from 'vitest'
import { parseSFC, getNativeBlocks, groupBlocksByComponent, groupBlocksByPlatform } from '../parser'
import type { NativeBlock } from '../types'

describe('SFC Parser', () => {
  describe('parseSFC', () => {
    it('should parse SFC with no native blocks', () => {
      const source = `
        <template>
          <VView>
            <VText>Hello World</VText>
          </VView>
        </template>

        <script setup lang="ts">
        import { ref } from 'vue'
        const count = ref(0)
        </script>
      `

      const result = parseSFC(source, { sourceFile: '/test/Component.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(0)
      expect(result.descriptor).toBeDefined()
    })

    it('should extract iOS native block with platform attribute', () => {
      const source = `
        <template>
          <VView>{{ message }}</VView>
        </template>

        <script setup lang="ts">
        const message = 'Hello'
        </script>

        <native platform="ios">
        class TestModule: NativeModule {
          var moduleName: String { "Test" }
          
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/TestComponent.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(1)

      const block = result.nativeBlocks[0]
      expect(block.platform).toBe('ios')
      expect(block.language).toBe('swift')
      expect(block.componentName).toBe('TestComponent')
      expect(block.content).toContain('class TestModule: NativeModule')
      expect(block.startLine).toBeDefined()
      expect(block.endLine).toBeDefined()
    })

    it('should extract Android native block with kotlin language', () => {
      const source = `
        <template>
          <VView>{{ message }}</VView>
        </template>

        <native platform="android">
        class TestModule: NativeModule {
          override val moduleName: String = "Test"
          
          override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
            callback(null, null)
          }
        }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/TestComponent.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(1)

      const block = result.nativeBlocks[0]
      expect(block.platform).toBe('android')
      expect(block.language).toBe('kotlin')
      expect(block.content).toContain('class TestModule: NativeModule')
    })

    it('should extract macOS native block', () => {
      const source = `
        <template>
          <VView>{{ message }}</VView>
        </template>

        <native platform="macos">
        class TestModule: NativeModule {
          var moduleName: String { "Test" }
          
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            callback(nil, nil)
          }
        }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/TestComponent.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(1)

      const block = result.nativeBlocks[0]
      expect(block.platform).toBe('macos')
      expect(block.language).toBe('swift')
    })

    it('should extract multiple native blocks for different platforms', () => {
      const source = `
        <template>
          <VView>{{ message }}</VView>
        </template>

        <native platform="ios">
        class IosModule: NativeModule { }
        </native>

        <native platform="android">
        class AndroidModule: NativeModule { }
        </native>

        <native platform="macos">
        class MacosModule: NativeModule { }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/MultiPlatform.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(3)

      const platforms = result.nativeBlocks.map(b => b.platform)
      expect(platforms).toContain('ios')
      expect(platforms).toContain('android')
      expect(platforms).toContain('macos')
    })

    it('should error when platform is missing', () => {
      const source = `
        <template>
          <VView>Test</VView>
        </template>

        <native>
        class TestModule: NativeModule { }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/NoPlatform.vue' })

      expect(result.errors).toHaveLength(1)
      expect(result.errors[0].message).toContain('must specify a valid platform')
    })

    it('should error when language does not match platform', () => {
      const source = `
        <template>
          <VView>Test</VView>
        </template>

        <native platform="android" lang="swift">
        class TestModule: NativeModule { }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/WrongLanguage.vue' })

      expect(result.errors).toHaveLength(1)
      expect(result.errors[0].message).toContain('Invalid language')
    })

    it('should handle empty native block gracefully', () => {
      // Empty native blocks are skipped by the SFC parser
      const source = `
        <template>
          <VView>Test</VView>
        </template>

        <native platform="ios"></native>
      `

      const result = parseSFC(source, { sourceFile: '/test/Empty.vue' })

      // The SFC parser either skips empty blocks or includes them with empty content
      // Our extractor should handle both cases gracefully
      expect(result.nativeBlocks.filter(b => b.content.trim() === '')).toHaveLength(0)
    })

    it('should handle ios shorthand attribute', () => {
      const source = `
        <template>
          <VView>Test</VView>
        </template>

        <native ios>
        class TestModule: NativeModule { }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/Shorthand.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(1)
      expect(result.nativeBlocks[0].platform).toBe('ios')
    })

    it('should handle android shorthand attribute', () => {
      const source = `
        <template>
          <VView>Test</VView>
        </template>

        <native android>
        class TestModule: NativeModule { }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/Shorthand.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(1)
      expect(result.nativeBlocks[0].platform).toBe('android')
      expect(result.nativeBlocks[0].language).toBe('kotlin')
    })

    it('should handle swift explicit language attribute', () => {
      const source = `
        <template>
          <VView>Test</VView>
        </template>

        <native platform="ios" lang="swift">
        class TestModule: NativeModule { }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/ExplicitLang.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(1)
      expect(result.nativeBlocks[0].language).toBe('swift')
    })

    it('should preserve attributes from native block', () => {
      const source = `
        <template>
          <VView>Test</VView>
        </template>

        <native platform="ios" custom-attr="value" another-attr="123">
        class TestModule: NativeModule { }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/Attrs.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(1)
      expect(result.nativeBlocks[0].attributes['custom-attr']).toBe('value')
      expect(result.nativeBlocks[0].attributes['another-attr']).toBe('123')
    })

    it('should extract correct source location', () => {
      const source = `
<template>
  <VView>Test</VView>
</template>

<script setup>
</script>

<native platform="ios">
class TestModule: NativeModule { }
</native>
`.trim()

      const result = parseSFC(source, { sourceFile: '/test/Loc.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(1)
      expect(result.nativeBlocks[0].startLine).toBeGreaterThan(1)
      expect(result.nativeBlocks[0].endLine).toBeGreaterThan(result.nativeBlocks[0].startLine!)
    })

    it('should handle complex Swift code with closures', () => {
      const source = `
        <template>
          <VView>Test</VView>
        </template>

        <native platform="ios">
        class ComplexModule: NativeModule {
          var moduleName: String { "Complex" }
          
          func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
            switch method {
            case "fetch":
              URLSession.shared.dataTask(with: URL(string: args[0] as! String)!) { data, response, error in
                if let error = error {
                  callback(nil, error.localizedDescription)
                } else if let data = data {
                  callback(String(data: data, encoding: .utf8), nil)
                }
              }.resume()
            default:
              callback(nil, "Unknown method")
            }
          }
        }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/Complex.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(1)
      expect(result.nativeBlocks[0].content).toContain('URLSession.shared.dataTask')
      expect(result.nativeBlocks[0].content).toContain('@escaping')
    })

    it('should handle complex Kotlin code with lambdas', () => {
      const source = `
        <template>
          <VView>Test</VView>
        </template>

        <native platform="android">
        class ComplexModule: NativeModule {
          override val moduleName: String = "Complex"
          
          override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
            when (method) {
              "fetch" -> {
                val url = args[0] as? String ?: return callback(null, "Invalid URL")
                java.net.URL(url).openStream().use {
                  callback(it.readText(), null)
                }
              }
              else -> callback(null, "Unknown method")
            }
          }
        }
        </native>
      `

      const result = parseSFC(source, { sourceFile: '/test/Complex.vue' })

      expect(result.errors).toHaveLength(0)
      expect(result.nativeBlocks).toHaveLength(1)
      expect(result.nativeBlocks[0].content).toContain('java.net.URL')
      expect(result.nativeBlocks[0].content).toContain('use {')
    })
  })

  describe('getNativeBlocks', () => {
    it('should filter by platform', () => {
      const source = `
        <template><VView/></template>
        <native platform="ios">class IosModule: NativeModule { }</native>
        <native platform="android">class AndroidModule: NativeModule { }</native>
        <native platform="macos">class MacosModule: NativeModule { }</native>
      `

      const result = parseSFC(source, { sourceFile: '/test/Filter.vue' })

      const allBlocks = getNativeBlocks({
        sfcs: [result],
        allNativeBlocks: result.nativeBlocks,
        errors: [],
      })
      expect(allBlocks).toHaveLength(3)

      const iosBlocks = getNativeBlocks({
        sfcs: [result],
        allNativeBlocks: result.nativeBlocks,
        errors: [],
      }, 'ios')
      expect(iosBlocks).toHaveLength(1)
      expect(iosBlocks[0].platform).toBe('ios')
    })
  })

  describe('groupBlocksByComponent', () => {
    it('should group blocks by component name', () => {
      const blocks: NativeBlock[] = [
        { platform: 'ios', language: 'swift', content: 'class A: NativeModule { }', sourceFile: '/test/A.vue', componentName: 'ComponentA', attributes: {} },
        { platform: 'android', language: 'kotlin', content: 'class A: NativeModule { }', sourceFile: '/test/A.vue', componentName: 'ComponentA', attributes: {} },
        { platform: 'ios', language: 'swift', content: 'class B: NativeModule { }', sourceFile: '/test/B.vue', componentName: 'ComponentB', attributes: {} },
      ]

      const grouped = groupBlocksByComponent(blocks)

      expect(grouped.size).toBe(2)
      expect(grouped.get('ComponentA')).toHaveLength(2)
      expect(grouped.get('ComponentB')).toHaveLength(1)
    })
  })

  describe('groupBlocksByPlatform', () => {
    it('should group blocks by platform', () => {
      const blocks: NativeBlock[] = [
        { platform: 'ios', language: 'swift', content: 'class A: NativeModule { }', sourceFile: '/test/A.vue', componentName: 'ComponentA', attributes: {} },
        { platform: 'android', language: 'kotlin', content: 'class A: NativeModule { }', sourceFile: '/test/A.vue', componentName: 'ComponentA', attributes: {} },
        { platform: 'macos', language: 'swift', content: 'class A: NativeModule { }', sourceFile: '/test/A.vue', componentName: 'ComponentA', attributes: {} },
      ]

      const grouped = groupBlocksByPlatform(blocks)

      expect(grouped.size).toBe(3)
      expect(grouped.get('ios')).toHaveLength(1)
      expect(grouped.get('android')).toHaveLength(1)
      expect(grouped.get('macos')).toHaveLength(1)
    })
  })
})
