# Native Blocks Demo

Advanced example demonstrating `<native>` blocks for custom native code.

## What It Demonstrates

- **Feature:** `<native>` blocks for Swift/Kotlin code
- **Patterns:**
  - Custom native modules
  - Code generation
  - TypeScript type generation
  - Platform-specific implementations

## Key Features

- Write Swift code inline
- Write Kotlin code inline
- Automatic TypeScript types
- Automatic module registration
- Cross-platform native functionality

## How to Run

```bash
cd examples/native-blocks-demo
bun install
bun vue-native dev
```

## Key Concepts

### Native Block Syntax

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const result = ref('')

// Call the native module
async function callNative() {
  result.value = await NativeBridge.invokeNativeModule(
    'CustomModule',
    'greet',
    ['World']
  )
}
</script>

<template>
  <VView>
    <VButton title="Call Native" @press="callNative" />
    <VText>{{ result }}</VText>
  </VView>
</template>

<native>
// This code is compiled to Swift (iOS) and Kotlin (Android)

module CustomModule {
  func greet(name: String) -> String {
    return "Hello, \(name)!"
  }
}
</native>
```

### Platform-Specific Code

```vue
<native platform="ios">
// Swift code only for iOS
import UIKit

module iOSModule {
  func showNativeAlert(title: String, message: String) {
    let alert = UIAlertController(
      title: title,
      message: message,
      preferredStyle: .alert
    )
    // ...
  }
}
</native>

<native platform="android">
// Kotlin code only for Android
package com.example

module AndroidModule {
  fun showNativeAlert(title: String, message: String) {
    // Android alert implementation
  }
}
</native>
```

### Custom Native Module

```vue
<native>
module BatteryModule {
  func getBatteryLevel() -> Int {
    // iOS implementation
    return UIDevice.current.batteryLevel * 100
  }
}
</native>
```

## File Structure

```
examples/native-blocks-demo/
├── app/
│   ├── main.ts
│   ├── App.vue
│   └── NativeDemo.vue    # Contains <native> blocks
├── native/
│   ├── ios/
│   └── android/
├── generated/            # Auto-generated code
│   ├── ios/
│   └── android/
└── package.json
```

## Build Process

1. Vite plugin extracts `<native>` blocks
2. Code generator creates Swift/Kotlin files
3. TypeScript types are generated
4. Native modules are registered
5. App is built with native code

## Learn More

- [Native Blocks Guide](../../docs/src/guide/native-blocks.md)
- [Custom Native Modules](../../docs/src/guide/native-modules.md)
- [Code Generation](../../docs/src/guide/codegen.md)

## Try This

Experiment with:
1. Create a custom toast notification module
2. Implement platform-specific haptics
3. Add a native image filter
4. Create a barcode scanner module
5. Build a native payment integration
