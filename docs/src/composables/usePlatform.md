# usePlatform

Returns the current platform the app is running on. Provides simple boolean flags for platform-specific logic. Values are determined at build time and are not reactive.

## Usage

```vue
<script setup>
import { usePlatform } from '@thelacanians/vue-native-runtime'

const { platform, isIOS, isAndroid } = usePlatform()
</script>

<template>
  <VView>
    <VText>Running on: {{ platform }}</VText>
    <VText v-if="isIOS">Welcome, iOS user!</VText>
    <VText v-if="isAndroid">Welcome, Android user!</VText>
  </VView>
</template>
```

## API

```ts
usePlatform(): {
  platform: 'ios' | 'android',
  isIOS: boolean,
  isAndroid: boolean
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `platform` | `'ios' \| 'android'` | The current platform identifier. |
| `isIOS` | `boolean` | `true` if the app is running on iOS. |
| `isAndroid` | `boolean` | `true` if the app is running on Android. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Returns `'ios'` as the platform value. |
| Android | Returns `'android'` as the platform value. |

## Example

```vue
<script setup>
import { usePlatform } from '@thelacanians/vue-native-runtime'

const { isIOS, isAndroid } = usePlatform()

const buttonStyle = {
  backgroundColor: isIOS ? '#007AFF' : '#6200EE',
  borderRadius: isIOS ? 10 : 4,
  padding: 12,
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
  </VView>
</template>
```

## Notes

- Return values are **not reactive** — they are plain values determined at build time, not `Ref` wrappers.
- Uses the `__PLATFORM__` compile-time constant injected by the Vite plugin during the build process.
- Falls back to `'ios'` if the `__PLATFORM__` constant is not defined.
- Since values are resolved at build time, dead code elimination can remove unused platform branches in production builds.
- For conditional logic that does not need to be in a template, prefer using `usePlatform` over manual `typeof` checks or global variables.
