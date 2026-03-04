# Native Code Blocks

Write Swift and Kotlin code directly in your Vue SFC files. The code generator automatically creates native modules, TypeScript types, and registration code.

## Overview

Native code blocks allow you to write platform-specific native code alongside your Vue components. This is perfect for:

- **High-performance operations** that need direct native access
- **Custom native integrations** not covered by built-in modules
- **Agentic AI interfaces** with native streaming and rendering
- **Code editors** with native syntax highlighting
- **Complex animations** using native animation engines

## Syntax

### Basic Example

```vue
<template>
  <VView class="container">
    <VText>{{ message }}</VText>
    <VButton @press="handleVibrate">Vibrate</VButton>
  </VView>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useHaptics } from '@/generated/useHaptics'

const { vibrate } = useHaptics()
const message = ref('Hello from native code!')

async function handleVibrate() {
  await vibrate('medium')
}
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
      callback(nil, "Unknown method: \(method)")
    }
  }
  
  func vibrate(style: String) {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.prepare()
    generator.impactOccurred()
  }
}
</native>

<native platform="android">
class HapticsModule: NativeModule {
  override val moduleName: String = "Haptics"
  
  override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
    when (method) {
      "vibrate" -> {
        val style = args[0] as? String ?: "medium"
        vibrate(style)
        callback(null, null)
      }
      else -> callback(null, "Unknown method: $method")
    }
  }
  
  fun vibrate(style: String) {
    val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    val duration = when (style) {
      "light" -> 10L
      "medium" -> 20L
      "heavy" -> 40L
      else -> 20L
    }
    vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
  }
}
</native>
```

### Platform-Specific Blocks

Use the `platform` attribute to target specific platforms:

```vue
<!-- iOS only -->
<native platform="ios">
class IosModule: NativeModule {
  var moduleName: String { "IosModule" }
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    // iOS implementation
  }
}
</native>

<!-- Android only -->
<native platform="android">
class AndroidModule: NativeModule {
  override val moduleName: String = "AndroidModule"
  override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
    // Android implementation
  }
}
</native>

<!-- macOS only -->
<native platform="macos">
class MacosModule: NativeModule {
  var moduleName: String { "MacosModule" }
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    // macOS implementation
  }
}
</native>
```

### Shorthand Syntax

You can use platform names as shorthand attributes:

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

## Generated Code

The code generator creates three types of files:

### 1. Swift Modules (iOS/macOS)

**Location:** `native/ios/VueNativeCore/Sources/VueNativeCore/GeneratedModules/`

```swift
// Auto-generated from Haptics.vue
import Foundation
import VueNativeCore

final class HapticsModule: NativeModule {
    var moduleName: String { "Haptics" }
    
    // Your implementation from <native> block
    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
      // ...
    }
}
```

### 2. Kotlin Modules (Android)

**Location:** `native/android/VueNativeCore/src/main/kotlin/.../GeneratedModules/`

```kotlin
// Auto-generated from Haptics.vue
package com.vuenative.core.GeneratedModules

import com.vuenative.core.Bridge.NativeModule

class HapticsModule: NativeModule {
    override val moduleName: String = "Haptics"
    
    // Your implementation from <native> block
    override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
      // ...
    }
}
```

### 3. TypeScript Composables

**Location:** `packages/runtime/src/generated/` or `app/generated/`

```typescript
// Auto-generated from Haptics.vue
import { NativeBridge } from '../bridge'

export interface HapticsModule {
  vibrate(style: string): Promise<void>
}

export function useHaptics(): HapticsModule {
  return {
    vibrate(style: string) {
      return NativeBridge.invokeNativeModule('Haptics', 'vibrate', [style])
    },
  }
}
```

## Configuration

Configure code generation in your `vite.config.ts`:

```ts
import vue from '@vitejs/plugin-vue'
import vueNative from '@thelacanians/vue-native-vite-plugin'

export default {
  plugins: [
    vue(),
    vueNative({
      platform: 'ios',
      nativeCodegen: true, // Enable/disable codegen
      nativeOutputDirs: {
        ios: 'native/ios/GeneratedModules',
        android: 'native/android/GeneratedModules',
        macos: 'native/macos/GeneratedModules',
        typescript: 'app/generated',
      },
      exclude: ['node_modules', 'dist', '.git', 'tests'],
    }),
  ],
}
```

## Manual Code Generation

You can also run code generation manually:

```bash
# Using the parser and codegen packages directly
bun run -e "
  import { parseDirectory } from '@thelacanians/vue-native-sfc-parser'
  import { generateCode, writeGeneratedFiles } from '@thelacanians/vue-native-codegen'
  
  const result = parseDirectory('app/')
  const codegen = generateCode(result.allNativeBlocks)
  writeGeneratedFiles(codegen)
"
```

## Real-World Examples

### AI Chat with Native Streaming

```vue
<template>
  <VView class="container">
    <VList :data="messages" class="messages">
      <template #item="{ item }">
        <AIMessageView :message="item" :streaming="item.streaming" />
      </template>
    </VList>
    
    <VTextInput
      v-model="input"
      placeholder="Ask anything..."
      @submit="sendMessage"
    />
  </VView>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useAIChat } from '@/generated/useAIChat'

const { messages, send, streamResponse } = useAIChat()
const input = ref('')

async function sendMessage() {
  await send(input.value)
  input.value = ''
}
</script>

<native platform="ios">
class AIChatModule: NativeModule {
  var moduleName: String { "AIChat" }
  
  private var streamingConnection: URLSessionDataTask?
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    switch method {
    case "send":
      send(message: args[0] as! String) { response in
        callback(response, nil)
      }
      
    case "stream":
      stream(prompt: args[0] as! String) { chunk in
        // Emit chunks via NativeEventDispatcher
      }
      callback(nil, nil)
      
    default:
      callback(nil, "Unknown method")
    }
  }
  
  private func send(message: String, completion: @escaping (String?) -> Void) {
    // Implementation
  }
  
  private func stream(prompt: String, onChunk: @escaping (String) -> Void) {
    // Streaming implementation with SSE or WebSocket
  }
}
</native>

<native platform="android">
class AIChatModule: NativeModule {
  override val moduleName: String = "AIChat"
  
  private var streamingConnection: okhttp3.Call?
  
  override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
    when (method) {
      "send" -> {
        val message = args[0] as String
        send(message) { response ->
          callback(response, null)
        }
      }
      "stream" -> {
        val prompt = args[0] as String
        stream(prompt) { chunk ->
          // Emit chunks
        }
        callback(null, null)
      }
      else -> callback(null, "Unknown method")
    }
  }
}
</native>
```

### Code Editor with Native Syntax Highlighting

```vue
<template>
  <VView class="editor-container">
    <CodeEditorView
      v-model="code"
      :language="language"
      :theme="theme"
      @change="handleCodeChange"
    />
  </VView>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useCodeEditor } from '@/generated/useCodeEditor'

const { highlight, getCompletions } = useCodeEditor()
const code = ref('')
const language = ref('typescript')
const theme = ref('dark')

async function handleCodeChange() {
  const highlighted = await highlight(code.value, language.value)
  // Update UI with highlighted code
}
</script>

<native platform="ios">
class CodeEditorModule: NativeModule {
  var moduleName: String { "CodeEditor" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    switch method {
    case "highlight":
      let code = args[0] as! String
      let language = args[1] as? String ?? "swift"
      let result = highlightCode(code, language: language)
      callback(result, nil)
      
    case "completions":
      let code = args[0] as! String
      let position = args[1] as! Int
      let completions = getCompletions(code: code, at: position)
      callback(completions, nil)
      
    default:
      callback(nil, "Unknown method")
    }
  }
  
  private func highlightCode(_ code: String, language: String) -> String {
    // Use TextFormattingRule or custom tokenizer
    // Return attributed string as JSON
  }
  
  private func getCompletions(code: String, at position: Int) -> [String] {
    // Use SourceKit or custom completion engine
    return ["completion1", "completion2"]
  }
}
</native>
```

## Best Practices

### 1. Keep Native Code Focused

Write only performance-critical or platform-specific code in `<native>` blocks. For most use cases, use the built-in composables.

```vue
<!-- ✅ Good: Focused native code -->
<native platform="ios">
class ImageProcessorModule: NativeModule {
  // Only image processing logic
}
</native>

<!-- ❌ Avoid: Too much logic -->
<native platform="ios">
// 500+ lines of complex business logic
</native>
```

### 2. Use TypeScript Types

The generated TypeScript interfaces provide type safety. Use them:

```ts
// ✅ Good: Type-safe usage
const { highlight } = useCodeEditor()
await highlight(code, 'typescript')

// ❌ Avoid: Bypassing types
const module = NativeBridge.invokeNativeModule('CodeEditor', 'highlight', [code, 'ts'])
```

### 3. Handle Errors Gracefully

```vue
<native platform="ios">
class SafeModule: NativeModule {
  var moduleName: String { "SafeModule" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    do {
      let result = try performOperation(args)
      callback(result, nil)
    } catch {
      callback(nil, error.localizedDescription)
    }
  }
}
</native>
```

### 4. Document Your Native Code

Add comments explaining what the native code does:

```vue
<native platform="ios">
// ImageProcessorModule - Handles CPU-intensive image transformations
// Uses Core Image filters for hardware-accelerated processing
class ImageProcessorModule: NativeModule {
  // ...
}
</native>
```

## Troubleshooting

### Code Not Generating

1. Check that `nativeCodegen: true` in your Vite plugin config
2. Ensure your `<native>` blocks have valid platform attributes
3. Check the console for parse errors

### TypeScript Errors in Generated Files

1. Run codegen again: the types might be out of sync
2. Check that your Swift/Kotlin method signatures are valid
3. Restart your TypeScript server

### Native Module Not Found at Runtime

1. Ensure you've rebuilt the native project after codegen
2. Check that the module name matches in Swift/Kotlin and TypeScript
3. Verify the generated registration code includes your module

## Advanced Features

### Method Signature Extraction

The code generator automatically extracts method signatures from your Swift/Kotlin code to create type-safe TypeScript interfaces:

```swift
<native platform="ios">
class MyModule: NativeModule {
  func fetch(url: String, timeout: Int) async throws -> Data {
    // This method signature is extracted
  }
  
  func save(data: Data, path: String) -> Bool {
    // This too
  }
}
</native>
```

Generates:

```typescript
export interface MyModule {
  fetch(url: string, timeout: number): Promise<Data>
  save(data: Data, path: string): boolean
}
```

### Custom Registration

For advanced use cases, you can manually register modules:

```swift
// In your native app initialization code
NativeModuleRegistry.shared.register(CustomModule())
```

## Next Steps

- [Native Modules Guide](/guide/native-modules.md) - Learn about built-in native modules
- [TypeScript Guide](/guide/typescript.md) - Type safety in Vue Native
- [Performance Guide](/guide/performance.md) - Optimize native code performance
