# Native Modules

Native modules expose device capabilities to your Vue code via composables.

## Built-in Native Modules

Vue Native comes with 30+ built-in native modules for common functionality.

### Device & System

```ts
import { useNetwork, useAppState, useColorScheme, useDeviceInfo } from '@thelacanians/vue-native-runtime'

const { isConnected, connectionType } = useNetwork()
const { state } = useAppState()          // 'active' | 'inactive' | 'background'
const { colorScheme, isDark } = useColorScheme()
const { model, screenWidth, screenHeight } = useDeviceInfo()
```

### Storage

```ts
import { useAsyncStorage } from '@thelacanians/vue-native-runtime'

const { getItem, setItem, removeItem } = useAsyncStorage()

await setItem('key', 'value')
const value = await getItem('key')
```

### Sensors & Hardware

```ts
import { useGeolocation, useBiometry, useHaptics } from '@thelacanians/vue-native-runtime'

const { coords, getCurrentPosition } = useGeolocation()
const { authenticate, getSupportedBiometry } = useBiometry()
const { vibrate } = useHaptics()
```

### Media

```ts
import { useCamera } from '@thelacanians/vue-native-runtime'

const { launchCamera, launchImageLibrary } = useCamera()
```

### Permissions

```ts
import { usePermissions } from '@thelacanians/vue-native-runtime'

const { request, check } = usePermissions()
const status = await request('camera')  // 'granted' | 'denied' | 'restricted'
```

### UI

```ts
import { useKeyboard, useClipboard, useShare, useLinking, useAnimation, useHttp } from '@thelacanians/vue-native-runtime'

const { isVisible, height } = useKeyboard()
const { copy, paste } = useClipboard()
const { share } = useShare()
const { openURL, canOpenURL } = useLinking()
const { timing, spring } = useAnimation()
const http = useHttp({ baseURL: 'https://api.example.com' })
```

### Notifications

```ts
import { useNotifications } from '@thelacanians/vue-native-runtime'

const { requestPermission, scheduleLocal, onNotification } = useNotifications()
await scheduleLocal({ title: 'Reminder', body: 'Hello!', delay: 5 })
```

## Custom Native Modules with `<native>` Blocks

For functionality not covered by built-in modules, you can write **custom native code** directly in your Vue SFC files using [`<native>` blocks](./native-blocks.md).

### Example: Custom Haptics

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
    switch method {
    case "vibrate":
      let style = args[0] as? String ?? "heavy"
      vibrate(style: style)
      callback(nil, nil)
    default:
      callback(nil, "Unknown method")
    }
  }
  
  func vibrate(style: String) {
    let generator = UIImpactFeedbackGenerator(style: .heavy)
    generator.prepare()
    generator.impactOccurred()
  }
}
</native>

<native platform="android">
class CustomHapticsModule: NativeModule {
  override val moduleName: String = "CustomHaptics"
  
  override fun invoke(method: String, args: List<Any?>, callback: (Any?, String?) -> Unit) {
    when (method) {
      "vibrate" -> {
        val style = args[0] as? String ?: "heavy"
        vibrate(style)
        callback(null, null)
      }
      else -> callback(null, "Unknown method")
    }
  }
}
</native>
```

The code generator automatically:
1. Creates Swift/Kotlin native modules
2. Generates TypeScript composables with type safety
3. Registers modules in the native runtime

👉 **Learn more:** [Native Code Blocks Guide](./native-blocks.md)

## When to Use Custom Native Modules

Use built-in modules when available. Create custom modules when you need:

- **Platform-specific APIs** not covered by built-in modules
- **High-performance operations** (image processing, audio, video)
- **Custom native integrations** (third-party SDKs)
- **Advanced features** (Metal, Core ML, ARKit, etc.)
- **Agentic AI interfaces** with native streaming
- **Code editors** with native syntax highlighting

## See Also

- [Native Code Blocks Guide](./native-blocks.md) - Complete guide to writing custom native code
- [Composables Reference](../composables/) - All built-in composables
- [TypeScript Guide](./typescript.md) - Type safety in Vue Native
