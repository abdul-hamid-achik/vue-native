# @thelacanians/vue-native-codegen

Code generator for Vue Native `<native>` blocks. Generates Swift, Kotlin, and TypeScript code from native blocks extracted from Vue Single File Components.

## Installation

```bash
bun add @thelacanians/vue-native-codegen
```

## Usage

### Basic Usage

```ts
import { parseDirectory } from '@thelacanians/vue-native-sfc-parser'
import { generateCode, writeGeneratedFiles } from '@thelacanians/vue-native-codegen'

// Parse SFCs to extract native blocks
const result = parseDirectory('app/', { exclude: ['node_modules', 'dist'] })

// Generate code
const codegen = generateCode(result.allNativeBlocks)

// Write to disk
writeGeneratedFiles(codegen)

console.log(`Generated ${codegen.stats.swiftFiles} Swift files`)
console.log(`Generated ${codegen.stats.kotlinFiles} Kotlin files`)
console.log(`Generated ${codegen.stats.typescriptFiles} TypeScript files`)
```

### With Custom Options

```ts
const codegen = generateCode(result.allNativeBlocks, {
  root: '/path/to/project',
  iosOutputDir: 'native/ios/GeneratedModules',
  androidOutputDir: 'native/android/GeneratedModules',
  typescriptOutputDir: 'src/generated',
  generateSwift: true,
  generateKotlin: true,
  generateTypeScript: true,
  includeHeader: true,
})
```

### Generate Specific File Types

```ts
// Generate only Swift (no Kotlin or TypeScript)
const swiftOnly = generateCode(blocks, {
  generateSwift: true,
  generateKotlin: false,
  generateTypeScript: false,
})

// Generate only TypeScript composables
const tsOnly = generateCode(blocks, {
  generateSwift: false,
  generateKotlin: false,
  generateTypeScript: true,
})
```

### Clean Generated Files

```ts
import { cleanGeneratedFiles } from '@thelacanians/vue-native-codegen'

cleanGeneratedFiles({
  iosOutputDir: 'native/ios/GeneratedModules',
  androidOutputDir: 'native/android/GeneratedModules',
  typescriptOutputDir: 'src/generated',
})
```

## API Reference

### Functions

#### `generateCode(blocks, options)`

Generate code from native blocks.

- **Parameters:**
  - `blocks` (NativeBlock[]) - Array of native blocks
  - `options` (CodegenOptions) - Generation options
- **Returns:** `CodegenResult`

#### `writeGeneratedFiles(result, rootDir)`

Write generated files to disk.

- **Parameters:**
  - `result` (CodegenResult) - Code generation result
  - `rootDir` (string) - Project root directory
- **Returns:** `{ written: number, errors: ParseError[] }`

#### `cleanGeneratedFiles(options, rootDir)`

Clean generated files from output directories.

- **Parameters:**
  - `options` (CodegenOptions) - Generation options
  - `rootDir` (string) - Project root directory

#### `generateSwiftFile(block, options)`

Generate a single Swift file from a native block.

- **Parameters:**
  - `block` (NativeBlock) - Native block
  - `options` (CodegenOptions) - Generation options
- **Returns:** `GeneratedFile`

#### `generateKotlinFile(block, options)`

Generate a single Kotlin file from a native block.

- **Parameters:**
  - `block` (NativeBlock) - Native block
  - `options` (CodegenOptions) - Generation options
- **Returns:** `GeneratedFile`

#### `generateTypeScriptFile(blocks, componentName, options)`

Generate a TypeScript composable file from native blocks.

- **Parameters:**
  - `blocks` (NativeBlock[]) - Native blocks for the component
  - `componentName` (string) - Component name
  - `options` (CodegenOptions) - Generation options
- **Returns:** `GeneratedFile`

#### `generateSwiftRegistration(blocks)`

Generate Swift module registration code.

- **Parameters:**
  - `blocks` (NativeBlock[]) - Swift native blocks
- **Returns:** `string`

#### `generateKotlinRegistration(blocks)`

Generate Kotlin module registration code.

- **Parameters:**
  - `blocks` (NativeBlock[]) - Kotlin native blocks
- **Returns:** `string`

## Types

### `CodegenOptions`

```ts
interface CodegenOptions {
  root?: string
  iosOutputDir?: string
  androidOutputDir?: string
  macosOutputDir?: string
  typescriptOutputDir?: string
  generateTypeScript?: boolean
  generateSwift?: boolean
  generateKotlin?: boolean
  includeHeader?: boolean
}
```

### `CodegenResult`

```ts
interface CodegenResult {
  files: GeneratedFile[]
  errors: ParseError[]
  warnings: ParseError[]
  stats: {
    totalBlocks: number
    swiftFiles: number
    kotlinFiles: number
    typescriptFiles: number
  }
}
```

### `GeneratedFile`

```ts
interface GeneratedFile {
  platform: 'ios' | 'android' | 'macos'
  language: 'swift' | 'kotlin' | 'typescript'
  content: string
  outputPath: string
  sourceBlock: NativeBlock
}
```

## Example Output

### Input: Vue SFC with `<native>` Block

```vue
<template>
  <VView>
    <VText>{{ message }}</VText>
  </VView>
</template>

<script setup lang="ts">
import { useHaptics } from '@/generated/useHaptics'
const { vibrate } = useHaptics()
</script>

<native platform="ios">
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
</native>
```

### Output: Generated Swift File

```swift
// ────────────────────────────────────────────────────────────────────────────────
//  Auto-Generated Code
// ────────────────────────────────────────────────────────────────────────────────
//
//  Generated from: Haptics.vue
//  Component: Haptics
//  Platform: ios
//  Language: Swift
//
//  ⚠️  WARNING: This file is auto-generated. DO NOT EDIT MANUALLY.
//      Changes will be overwritten by the code generator.
//
// ────────────────────────────────────────────────────────────────────────────────

import Foundation
import VueNativeCore

/// Auto-generated native module from Haptics.vue
/// Platform: ios
final class HapticsModule: NativeModule {
    var moduleName: String { "Haptics" }
    
    // User-provided implementation
    class HapticsModule: NativeModule {
      var moduleName: String { "Haptics" }
      
      func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        // ...
      }
    }
}
```

### Output: Generated TypeScript Composable

```typescript
// ────────────────────────────────────────────────────────────────────────────────
//  Auto-Generated Code
// ────────────────────────────────────────────────────────────────────────────────
//
//  Component: Haptics
//  Language: TypeScript
//
//  ⚠️  WARNING: This file is auto-generated. DO NOT EDIT MANUALLY.
//      Changes will be overwritten by the code generator.
//
// ────────────────────────────────────────────────────────────────────────────────

import { NativeBridge } from '../bridge'

/**
 * Type-safe interface for the Haptics native module
 * Auto-generated from <native> blocks in Haptics.vue
 */
export interface HapticsModule {
  vibrate(style: string): Promise<void>
}

/**
 * Composable for using the Haptics native module
 */
export function useHaptics(): HapticsModule {
  return {
    vibrate(style: string) {
      return NativeBridge.invokeNativeModule('Haptics', 'vibrate', [style])
    },
  }
}
```

## License

MIT
