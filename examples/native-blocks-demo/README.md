# Native Blocks Demo

This example demonstrates Vue Native's **`<native>` blocks** feature - write Swift and Kotlin code directly in your Vue SFC files!

## What This Demo Shows

1. **Custom Haptics Module** - Advanced haptic feedback with custom patterns
2. **Image Processor Module** - Native image filters using Core Image (iOS) and Bitmap (Android)
3. **Device Info Module** - Extended device information access

## Features Demonstrated

- ✅ Multiple `<native>` blocks in a single SFC
- ✅ Platform-specific implementations (iOS + Android)
- ✅ Auto-generated TypeScript composables
- ✅ Method signature extraction
- ✅ Type-safe native module calls
- ✅ Complex native code (async patterns, image processing)

## Running the Demo

### Prerequisites

- Vue Native CLI installed
- Xcode (for iOS) or Android Studio (for Android)
- Node.js and Bun

### Install Dependencies

```bash
cd examples/native-blocks-demo
bun install
```

### Generate Native Code

```bash
# Generate Swift, Kotlin, and TypeScript from <native> blocks
bun run generate

# Or use the CLI directly
vue-native generate
```

### Run on iOS

```bash
# Start dev server
bun run dev

# In another terminal, run on iOS
vue-native run ios
```

### Run on Android

```bash
# Start dev server
bun run dev

# In another terminal, run on Android
vue-native run android
```

## Generated Files

After running `vue-native generate`, you'll find:

### TypeScript Composables

```
app/generated/
├── useCustomHaptics.ts
├── useImageProcessor.ts
└── useDeviceInfo.ts
```

### Swift Modules (iOS)

```
native/ios/.../GeneratedModules/
├── CustomHapticsModule.swift
├── ImageProcessorModule.swift
└── DeviceInfoModule.swift
```

### Kotlin Modules (Android)

```
native/android/.../GeneratedModules/
├── CustomHapticsModule.kt
├── ImageProcessorModule.kt
└── DeviceInfoModule.kt
```

## Code Structure

### Vue SFC with Native Blocks

```vue
<template>
  <VView>
    <VButton title="Vibrate" @press="handleVibrate" />
  </VView>
</template>

<script setup lang="ts">
import { useCustomHaptics } from './generated/useCustomHaptics'

const { vibrate } = useCustomHaptics()

async function handleVibrate() {
  await vibrate('heavy')
}
</script>

<native platform="ios">
class CustomHapticsModule: NativeModule {
  var moduleName: String { "CustomHaptics" }
  
  func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
    // Implementation
  }
}
</native>

<native platform="android">
class CustomHapticsModule: NativeModule {
  override val moduleName: String = "CustomHaptics"
  
  override fun invoke(method: String, args: List<Any>, callback: (Any?, String?) -> Unit) {
    // Implementation
  }
}
</native>
```

## Examples in Action

### Custom Haptics

```typescript
// Light, medium, heavy vibrations
await vibrate('light')
await vibrate('medium')
await vibrate('heavy')

// Custom pattern (duration in ms)
await pattern([100, 50, 100, 50, 200])
```

### Image Filters

```typescript
// Apply grayscale filter
await applyFilter('CIPhotoEffectMono')

// Apply blur with radius
await applyFilter('CIGaussianBlur', { inputRadius: 5 })
```

### Device Info

```typescript
// Get battery level (0.0 - 1.0)
const battery = await getBatteryLevel()

// Get device model
const model = await getDeviceModel()
```

## Learning Points

1. **Multiple Native Blocks**: You can have multiple `<native>` blocks in a single SFC
2. **Platform Specific**: Each block targets a specific platform (ios, android, macos)
3. **Auto-Generated Types**: TypeScript interfaces are generated from your Swift/Kotlin code
4. **Method Extraction**: Public methods are automatically extracted and typed
5. **Registration**: Modules are automatically registered in the native runtime

## Troubleshooting

### Generated Files Not Found

Run `vue-native generate` to create the files.

### TypeScript Errors

Make sure the generated files are up to date:

```bash
vue-native generate --clean
```

### Native Module Not Found at Runtime

1. Rebuild the native project
2. Check that the module name matches in all platforms
3. Verify the generated registration code includes your module

## Next Steps

- Try modifying the native code and regenerating
- Add your own custom native module
- Check out the [Native Blocks Documentation](../../docs/src/guide/native-blocks.md)
- Explore other examples in the `examples/` directory

## License

MIT
