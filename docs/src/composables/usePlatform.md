# usePlatform

Returns the current platform the app is running on. Provides simple boolean flags for platform-specific logic. Values are determined at build time and are not reactive.

## Usage

```vue
<script setup>
import { usePlatform } from '@thelacanians/vue-native-runtime'

const { platform, isIOS, isAndroid, isMacOS } = usePlatform()
</script>

<template>
  <VView>
    <VText>Running on: {{ platform }}</VText>
    <VText v-if="isIOS">Welcome, iOS user!</VText>
    <VText v-if="isAndroid">Welcome, Android user!</VText>
    <VText v-if="isMacOS">Welcome, macOS user!</VText>
  </VView>
</template>
```

## API

```ts
usePlatform(): {
  platform: 'ios' | 'android' | 'macos'
  isIOS: boolean
  isAndroid: boolean
  isMacOS: boolean
  isApple: boolean
  isDesktop: boolean
  isMobile: boolean
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `platform` | `'ios' \| 'android' \| 'macos'` | The current platform identifier. |
| `isIOS` | `boolean` | `true` if the app is running on iOS. |
| `isAndroid` | `boolean` | `true` if the app is running on Android. |
| `isMacOS` | `boolean` | `true` if the app is running on macOS. |
| `isApple` | `boolean` | `true` if the app is running on an Apple platform (iOS or macOS). |
| `isDesktop` | `boolean` | `true` if the app is running on a desktop platform (macOS). |
| `isMobile` | `boolean` | `true` if the app is running on a mobile platform (iOS or Android). |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Returns `'ios'` as the platform value. |
| Android | Returns `'android'` as the platform value. |
| macOS | Returns `'macos'` as the platform value. |

## Example

```vue
<script setup>
import { usePlatform } from '@thelacanians/vue-native-runtime'

const { platform, isIOS, isAndroid, isMacOS, isApple, isDesktop, isMobile } = usePlatform()

const buttonStyle = {
  backgroundColor: isIOS ? '#007AFF' : isAndroid ? '#6200EE' : '#000000',
  borderRadius: isIOS || isMacOS ? 10 : 4,
  padding: isMacOS ? 8 : 12,
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText :style="{ fontSize: 18, marginBottom: 16 }">
      Platform-Specific Styling
    </VText>

    <VButton
      title="Native Button"
      :style="buttonStyle"
    />

    <VText v-if="isIOS" :style="{ marginTop: 12 }">
      Using San Francisco font defaults
    </VText>
    <VText v-if="isAndroid" :style="{ marginTop: 12 }">
      Using Roboto font defaults
    </VText>
    <VText v-if="isMacOS" :style="{ marginTop: 12 }">
      Running on macOS — menu bar and window controls are available
    </VText>
    <VText v-if="isApple" :style="{ marginTop: 8, color: '#888' }">
      Apple platform: {{ platform }}
    </VText>
    <VText v-if="isMobile" :style="{ marginTop: 8, color: '#888' }">
      Mobile platform — touch optimised layout
    </VText>
    <VText v-if="isDesktop" :style="{ marginTop: 8, color: '#888' }">
      Desktop platform — mouse and keyboard input expected
    </VText>
  </VView>
</template>
```

## Notes

- Return values are **not reactive** — they are plain values determined at build time, not `Ref` wrappers.
- Uses the `__PLATFORM__` compile-time constant injected by the Vite plugin during the build process.
- Falls back to `'ios'` if the `__PLATFORM__` constant is not defined.
- Since values are resolved at build time, dead code elimination can remove unused platform branches in production builds.
- For conditional logic that does not need to be in a template, prefer using `usePlatform` over manual `typeof` checks or global variables.
