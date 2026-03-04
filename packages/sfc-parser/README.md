# @thelacanians/vue-native-sfc-parser

Vue Native SFC parser for extracting `<native>` blocks from Vue Single File Components.

## Installation

```bash
bun add @thelacanians/vue-native-sfc-parser
```

## Usage

### Parse a Single File

```ts
import { parseSFCFile } from '@thelacanians/vue-native-sfc-parser'

const result = parseSFCFile('app/components/MyComponent.vue')

console.log(result.nativeBlocks) // Array of extracted <native> blocks
console.log(result.errors) // Parse errors, if any
```

### Parse Multiple Files

```ts
import { parseSFCFiles } from '@thelacanians/vue-native-sfc-parser'

const files = [
  'app/components/ComponentA.vue',
  'app/components/ComponentB.vue',
]

const result = parseSFCFiles(files)
console.log(result.allNativeBlocks) // All blocks from all files
```

### Parse Entire Directory

```ts
import { parseDirectory } from '@thelacanians/vue-native-sfc-parser'

const result = parseDirectory('app/', {
  exclude: ['node_modules', 'dist', '.git'],
})

console.log(result.sfcs) // All parsed SFCs
console.log(result.allNativeBlocks) // All native blocks
```

### Filter by Platform

```ts
import { getNativeBlocks } from '@thelacanians/vue-native-sfc-parser'

const result = parseDirectory('app/')

// Get only iOS blocks
const iosBlocks = getNativeBlocks(result, 'ios')

// Get only Android blocks
const androidBlocks = getNativeBlocks(result, 'android')
```

### Group by Component

```ts
import { groupBlocksByComponent } from '@thelacanians/vue-native-sfc-parser'

const result = parseDirectory('app/')
const grouped = groupBlocksByComponent(result.allNativeBlocks)

// Access blocks for specific component
const componentABlocks = grouped.get('ComponentA')
```

### Group by Platform

```ts
import { groupBlocksByPlatform } from '@thelacanians/vue-native-sfc-parser'

const result = parseDirectory('app/')
const grouped = groupBlocksByPlatform(result.allNativeBlocks)

const iosBlocks = grouped.get('ios')
const androidBlocks = grouped.get('android')
const macosBlocks = grouped.get('macos')
```

## Supported `<native>` Block Syntax

### Platform Attribute (Recommended)

```vue
<template>
  <VView>My Component</VView>
</template>

<script setup lang="ts">
// TypeScript code
</script>

<native platform="ios">
class MyModule: NativeModule {
  var moduleName: String { "MyModule" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    // Implementation
  }
}
</native>

<native platform="android">
class MyModule: NativeModule {
  override val moduleName: String = "MyModule"
  
  override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
    // Implementation
  }
}
</native>
```

### Shorthand Platform Attributes

```vue
<native ios>
// Swift code for iOS
</native>

<native android>
// Kotlin code for Android
</native>

<native macos>
// Swift code for macOS
</native>
```

### Explicit Language Attribute

```vue
<native platform="ios" lang="swift">
// Swift code
</native>

<native platform="android" lang="kotlin">
// Kotlin code
</native>
```

## API Reference

### Functions

#### `parseSFC(source, options)`

Parse SFC source code string.

- **Parameters:**
  - `source` (string) - SFC source code
  - `options.sourceFile` (string) - File path for error reporting
  - `options.parserOptions` (ParserOptions) - Parser options
- **Returns:** `ParsedSFC`

#### `parseSFCFile(filePath, options)`

Parse SFC file from disk.

- **Parameters:**
  - `filePath` (string) - Path to .vue file
  - `options` (ParserOptions) - Parser options
- **Returns:** `ParsedSFC`

#### `parseSFCFiles(filePaths, options)`

Parse multiple SFC files.

- **Parameters:**
  - `filePaths` (string[]) - Array of file paths
  - `options` (ParserOptions) - Parser options
- **Returns:** `ParseResult`

#### `parseDirectory(dirPath, options)`

Parse all SFC files in a directory recursively.

- **Parameters:**
  - `dirPath` (string) - Directory path
  - `options.exclude` (string[]) - Directories to exclude (default: `['node_modules', 'dist', '.git']`)
  - `options` (ParserOptions) - Parser options
- **Returns:** `ParseResult`

#### `getNativeBlocks(result, platform?)`

Get native blocks from parse result, optionally filtered by platform.

- **Parameters:**
  - `result` (ParseResult) - Parse result
  - `platform` ('ios' | 'android' | 'macos') - Optional platform filter
- **Returns:** `NativeBlock[]`

#### `getComponentNativeBlocks(result, componentName)`

Get native blocks for a specific component.

- **Parameters:**
  - `result` (ParseResult) - Parse result
  - `componentName` (string) - Component name
- **Returns:** `NativeBlock[]`

#### `groupBlocksByComponent(blocks)`

Group native blocks by component name.

- **Parameters:**
  - `blocks` (NativeBlock[]) - Native blocks
- **Returns:** `Map<string, NativeBlock[]>`

#### `groupBlocksByPlatform(blocks)`

Group native blocks by platform.

- **Parameters:**
  - `blocks` (NativeBlock[]) - Native blocks
- **Returns:** `Map<'ios' | 'android' | 'macos', NativeBlock[]>`

## Types

### `NativeBlock`

```ts
interface NativeBlock {
  platform: 'ios' | 'android' | 'macos'
  language: 'swift' | 'kotlin'
  content: string
  sourceFile: string
  componentName: string
  startLine?: number
  endLine?: number
  attributes: Record<string, string>
}
```

### `ParsedSFC`

```ts
interface ParsedSFC {
  descriptor: SFCDescriptor
  nativeBlocks: NativeBlock[]
  sourceFile: string
  errors: ParseError[]
}
```

### `ParseResult`

```ts
interface ParseResult {
  sfcs: ParsedSFC[]
  allNativeBlocks: NativeBlock[]
  errors: ParseError[]
}
```

### `ParseError`

```ts
interface ParseError {
  file: string
  message: string
  line?: number
  column?: number
}
```

### `ParserOptions`

```ts
interface ParserOptions {
  root?: string
  includeSourceLocation?: boolean
  validate?: (block: NativeBlock) => ParseError | null
}
```

## License

MIT
