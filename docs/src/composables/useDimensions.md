# useDimensions

Reactive screen dimensions. Tracks the device screen width, height, and pixel scale in real time, automatically updating when the screen size changes (e.g., on device rotation or multitasking split).

## Usage

```vue
<script setup>
import { useDimensions } from '@thelacanians/vue-native-runtime'

const { width, height, scale } = useDimensions()
</script>

<template>
  <VView>
    <VText>Screen: {{ width }} x {{ height }}</VText>
    <VText>Scale: {{ scale }}x</VText>
  </VView>
</template>
```

## API

```ts
useDimensions(): {
  width: Ref<number>,
  height: Ref<number>,
  scale: Ref<number>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `width` | `Ref<number>` | The current screen width in logical points. |
| `height` | `Ref<number>` | The current screen height in logical points. |
| `scale` | `Ref<number>` | The device pixel ratio (e.g., 2.0 for Retina, 3.0 for Super Retina). |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `UIScreen.main.bounds` for initial values and listens for `UIScreen` dimension change notifications. |
| Android | Uses `DisplayMetrics` from the `WindowManager` for initial values and listens for configuration changes. |

## Example

```vue
<script setup>
import { computed } from 'vue'
import { useDimensions } from '@thelacanians/vue-native-runtime'

const { width, height } = useDimensions()
const isLandscape = computed(() => width.value > height.value)
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText :style="{ fontSize: 18 }">
      Orientation: {{ isLandscape ? 'Landscape' : 'Portrait' }}
    </VText>
    <VText>{{ width }} x {{ height }} points</VText>

    <VView
      :style="{
        width: isLandscape ? '50%' : '100%',
        height: 200,
        backgroundColor: '#3498db'
      }"
    >
      <VText :style="{ color: '#fff' }">Responsive Box</VText>
    </VView>
  </VView>
</template>
```

## Notes

- Initial values are fetched synchronously from `DeviceInfo.getInfo()` so they are available on the first render.
- Listens for `dimensionsChange` events from the native bridge to update values reactively.
- Values are in logical points, not physical pixels. Multiply by `scale` to get physical pixel dimensions.
- Automatically unsubscribes from dimension change events when the component unmounts.
- On iPad, dimensions change during Split View and Slide Over multitasking.
