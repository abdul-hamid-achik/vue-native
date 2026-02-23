# useDeviceInfo

Fetches device information such as model name, OS version, and screen dimensions. The data is loaded once on mount and exposed as reactive refs.

## Usage

```vue
<script setup>
import { useDeviceInfo } from '@thelacanians/vue-native-runtime'

const { model, systemName, systemVersion, screenWidth, screenHeight } = useDeviceInfo()
</script>

<template>
  <VView>
    <VText>{{ model }} running {{ systemName }} {{ systemVersion }}</VText>
    <VText>Screen: {{ screenWidth }}x{{ screenHeight }}</VText>
  </VView>
</template>
```

## API

```ts
useDeviceInfo(): {
  model: Ref<string>
  systemVersion: Ref<string>
  systemName: Ref<string>
  name: Ref<string>
  screenWidth: Ref<number>
  screenHeight: Ref<number>
  scale: Ref<number>
  isLoaded: Ref<boolean>
  fetchInfo: () => Promise<void>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `model` | `Ref<string>` | Device model identifier (e.g., `"iPhone15,2"` on iOS, `"Pixel 7"` on Android). |
| `systemVersion` | `Ref<string>` | OS version string (e.g., `"17.4"`, `"14"`). |
| `systemName` | `Ref<string>` | OS name (e.g., `"iOS"`, `"Android"`). |
| `name` | `Ref<string>` | User-assigned device name (e.g., `"John's iPhone"`). |
| `screenWidth` | `Ref<number>` | Screen width in points. |
| `screenHeight` | `Ref<number>` | Screen height in points. |
| `scale` | `Ref<number>` | Screen pixel density scale factor (e.g., `3` for @3x Retina). |
| `isLoaded` | `Ref<boolean>` | `true` after the native info has been fetched. |
| `fetchInfo` | `() => Promise<void>` | Manually re-fetch device info. Called automatically on mount. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Reads from `UIDevice.current` and `UIScreen.main`. |
| Android | Reads from `android.os.Build` and `DisplayMetrics`. |

## Example

```vue
<script setup>
import { useDeviceInfo } from '@thelacanians/vue-native-runtime'

const {
  model,
  systemName,
  systemVersion,
  screenWidth,
  screenHeight,
  scale,
  isLoaded,
} = useDeviceInfo()
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 20, fontWeight: 'bold', marginBottom: 16 }">
      Device Info
    </VText>
    <VActivityIndicator v-if="!isLoaded" />
    <VView v-else>
      <VText>Model: {{ model }}</VText>
      <VText>OS: {{ systemName }} {{ systemVersion }}</VText>
      <VText>Screen: {{ screenWidth }} x {{ screenHeight }} (@{{ scale }}x)</VText>
    </VView>
  </VView>
</template>
```

## Notes

- Device info is fetched asynchronously on `onMounted`. Use the `isLoaded` ref to show a loading state.
- All refs default to empty strings or `0` until the native data arrives.
- Call `fetchInfo()` manually if you need to re-query (e.g., after a screen rotation changes dimensions).
