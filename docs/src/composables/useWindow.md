# useWindow

Control the native macOS window from your Vue components. Provides methods for setting the title, resizing, centering, and managing window state.

## Usage

```vue
<script setup>
import { useWindow } from '@thelacanians/vue-native-runtime'

const { setTitle, setSize, center, toggleFullScreen, getInfo } = useWindow()

setTitle('My App — Settings')
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VButton :onPress="() => setTitle('Updated Title')">
      <VText>Change Title</VText>
    </VButton>
    <VButton :onPress="() => setSize(1024, 768)">
      <VText>Resize Window</VText>
    </VButton>
    <VButton :onPress="center">
      <VText>Center Window</VText>
    </VButton>
    <VButton :onPress="toggleFullScreen">
      <VText>Toggle Full Screen</VText>
    </VButton>
  </VView>
</template>
```

## API

```ts
useWindow(): {
  setTitle: (title: string) => Promise<void>
  setSize: (width: number, height: number) => Promise<void>
  center: () => Promise<void>
  minimize: () => Promise<void>
  toggleFullScreen: () => Promise<void>
  close: () => Promise<void>
  getInfo: () => Promise<WindowInfo | null>
}
```

### Return Value

| Method | Signature | Description |
|--------|-----------|-------------|
| `setTitle` | `(title: string) => Promise<void>` | Set the window title bar text. |
| `setSize` | `(width: number, height: number) => Promise<void>` | Resize the window to the given dimensions in points. |
| `center` | `() => Promise<void>` | Center the window on the screen. |
| `minimize` | `() => Promise<void>` | Minimize the window to the dock. |
| `toggleFullScreen` | `() => Promise<void>` | Toggle between full screen and windowed mode. |
| `close` | `() => Promise<void>` | Close the window. If this is the last window and `applicationShouldTerminateAfterLastWindowClosed` returns `true`, the app will quit. |
| `getInfo` | `() => Promise<WindowInfo \| null>` | Get current window information (size, position, full screen state). Returns `null` on non-macOS platforms. |

### Types

```ts
interface WindowInfo {
  width: number
  height: number
  x: number
  y: number
  isFullScreen: boolean
  isVisible: boolean
  title: string
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | No — iOS apps do not have user-managed windows. |
| Android | No — Android apps do not have desktop-style windows. |
| macOS | Yes — Uses `NSWindow` APIs. |

## Example

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'
import { useWindow } from '@thelacanians/vue-native-runtime'

const { setTitle, setSize, center, minimize, toggleFullScreen, close, getInfo } = useWindow()
const windowInfo = ref<WindowInfo | null>(null)

onMounted(async () => {
  windowInfo.value = await getInfo()
  setTitle(`My App (${windowInfo.value.width}x${windowInfo.value.height})`)
})

async function handleResize(width: number, height: number) {
  setSize(width, height)
  center()
  windowInfo.value = await getInfo()
}
</script>

<template>
  <VView :style="{ padding: 20, gap: 12 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold' }">Window Controls</VText>

    <VView v-if="windowInfo" :style="{ padding: 12, backgroundColor: '#f5f5f5', borderRadius: 8 }">
      <VText>Size: {{ windowInfo.width }} x {{ windowInfo.height }}</VText>
      <VText>Position: ({{ windowInfo.x }}, {{ windowInfo.y }})</VText>
      <VText>Full Screen: {{ windowInfo.isFullScreen }}</VText>
    </VView>

    <VButton :onPress="() => handleResize(800, 600)"><VText>800 x 600</VText></VButton>
    <VButton :onPress="() => handleResize(1024, 768)"><VText>1024 x 768</VText></VButton>
    <VButton :onPress="() => handleResize(1280, 960)"><VText>1280 x 960</VText></VButton>
    <VButton :onPress="center"><VText>Center</VText></VButton>
    <VButton :onPress="minimize"><VText>Minimize</VText></VButton>
    <VButton :onPress="toggleFullScreen"><VText>Toggle Full Screen</VText></VButton>
    <VButton :onPress="close"><VText>Close</VText></VButton>
  </VView>
</template>
```

## Notes

- All methods are async and return Promises. Await them if you need to ensure ordering.
- Calling these methods on iOS or Android is a no-op and does not throw.
- Window size is specified in points, not pixels. On Retina displays, multiply by `window.devicePixelRatio` for pixel dimensions.
