# useGesture

A composable for handling touch and mouse gestures across iOS, Android, and macOS.

## Overview

`useGesture` provides a unified API for handling common gestures like pan, pinch, rotate, swipe, and more. It works with template refs or node IDs and automatically manages event listener lifecycle.

## Basic Usage

```vue
<script setup>
import { ref } from 'vue'
import { useGesture, VView, VText } from '@thelacanians/vue-native-runtime'

const viewRef = ref()

const { pan, isGesturing } = useGesture(viewRef, {
  pan: true,
  pinch: true,
})

// pan.value = { translationX, translationY, velocityX, velocityY, state }
// isGesturing.value = true while gesture is active
</script>

<template>
  <VView 
    ref="viewRef"
    :style="{ 
      flex: 1, 
      justifyContent: 'center', 
      alignItems: 'center',
      backgroundColor: '#f0f0f0'
    }"
  >
    <VText v-if="pan">
      Pan: {{ pan.translationX.toFixed(0) }}, {{ pan.translationY.toFixed(0) }}
    </VText>
    <VText v-else>Start panning...</VText>
  </VView>
</template>
```

## Supported Gestures

| Gesture | Platform | Description |
|---------|----------|-------------|
| `pan` | iOS, Android, macOS | Drag/finger movement tracking |
| `pinch` | iOS, Android, macOS | Two-finger pinch to zoom |
| `rotate` | iOS, Android, macOS | Two-finger rotation gesture |
| `swipeLeft` | iOS, Android | Fast swipe left |
| `swipeRight` | iOS, Android | Fast swipe right |
| `swipeUp` | iOS, Android | Fast swipe up |
| `swipeDown` | iOS, Android | Fast swipe down |
| `press` | iOS, Android, macOS | Single tap |
| `longPress` | iOS, Android, macOS | Long press (hold) |
| `doubleTap` | iOS, Android, macOS | Double tap |
| `forceTouch` | iOS, macOS | 3D Touch / Force Touch pressure |
| `hover` | iOS (13+), macOS | Mouse/touch hover tracking |

## Gesture State Types

### PanGestureState

```ts
interface PanGestureState {
  translationX: number
  translationY: number
  velocityX: number
  velocityY: number
  state: 'began' | 'changed' | 'ended' | 'cancelled'
}
```

### PinchGestureState

```ts
interface PinchGestureState {
  scale: number      // 1.0 = no scale
  velocity: number
  state: 'began' | 'changed' | 'ended' | 'cancelled'
}
```

### RotateGestureState

```ts
interface RotateGestureState {
  rotation: number   // radians
  velocity: number
  state: 'began' | 'changed' | 'ended' | 'cancelled'
}
```

### SwipeGestureState

```ts
interface SwipeGestureState {
  direction: 'left' | 'right' | 'up' | 'down'
  locationX: number
  locationY: number
}
```

### TapGestureState

```ts
interface TapGestureState {
  locationX: number
  locationY: number
  tapCount: number
}
```

### ForceTouchState

```ts
interface ForceTouchState {
  force: number      // 0.0 - 1.0+ (normalized)
  locationX: number
  locationY: number
  stage: number      // 0 = no touch, 1+ = pressure levels
}
```

### HoverState

```ts
interface HoverState {
  locationX: number
  locationY: number
  state: 'entered' | 'moved' | 'exited'
}
```

## Return Values

```ts
interface UseGestureReturn {
  // Gesture state refs
  pan: Ref<PanGestureState | null>
  pinch: Ref<PinchGestureState | null>
  rotate: Ref<RotateGestureState | null>
  swipeLeft: Ref<SwipeGestureState | null>
  swipeRight: Ref<SwipeGestureState | null>
  swipeUp: Ref<SwipeGestureState | null>
  swipeDown: Ref<SwipeGestureState | null>
  press: Ref<TapGestureState | null>
  longPress: Ref<TapGestureState | null>
  doubleTap: Ref<TapGestureState | null>
  forceTouch: Ref<ForceTouchState | null>
  hover: Ref<HoverState | null>
  
  // Computed refs
  gestureState: Ref<GestureState | null>  // Currently active gesture
  activeGesture: Ref<string | null>       // Name of active gesture
  isGesturing: Ref<boolean>                // True while gesture is active
  
  // Methods
  attach: (target: GestureTarget) => void   // Manually attach to a view
  detach: () => void                         // Remove all listeners
  on: (event, callback) => () => void        // Manual event binding
}
```

## Options

```ts
interface UseGestureOptions {
  pan?: boolean | GestureConfig
  pinch?: boolean | GestureConfig
  rotate?: boolean | GestureConfig
  swipeLeft?: boolean | GestureConfig
  swipeRight?: boolean | GestureConfig
  swipeUp?: boolean | GestureConfig
  swipeDown?: boolean | GestureConfig
  press?: boolean | GestureConfig
  longPress?: boolean | GestureConfig
  doubleTap?: boolean | GestureConfig
  forceTouch?: boolean | GestureConfig
  hover?: boolean | GestureConfig
}
```

## Example: Draggable View

```vue
<script setup>
import { ref, computed } from 'vue'
import { useGesture, VView, VText } from '@thelacanians/vue-native-runtime'

const viewRef = ref()
const offsetX = ref(0)
const offsetY = ref(0)

const { pan, isGesturing } = useGesture(viewRef, { pan: true })

// Update position on pan
const style = computed(() => ({
  flex: 1,
  justifyContent: 'center',
  alignItems: 'center',
  backgroundColor: isGesturing.value ? '#007AFF' : '#666',
  transform: [
    { translateX: offsetX.value + (pan.value?.translationX ?? 0) },
    { translateY: offsetY.value + (pan.value?.translationY ?? 0) },
  ],
}))

function onPanEnd() {
  if (pan.value?.state === 'ended') {
    offsetX.value += pan.value.translationX
    offsetY.value += pan.value.translationY
  }
}
</script>

<template>
  <VView :style="{ flex: 1, backgroundColor: '#f5f5f5' }">
    <VView ref="viewRef" :style="style">
      <VText :style="{ color: '#fff' }">
        {{ isGesturing ? 'Dragging...' : 'Drag me!' }}
      </VText>
    </VView>
  </VView>
</template>
```

## Example: Pinch to Zoom

```vue
<script setup>
import { ref, computed } from 'vue'
import { useGesture, VView, VText, VImage } from '@thelacanians/vue-native-runtime'

const imageRef = ref()
const scale = ref(1)

const { pinch } = useGesture(imageRef, { pinch: true })

const imageStyle = computed(() => ({
  width: 300,
  height: 300,
  transform: [{ scale: scale.value * (pinch.value?.scale ?? 1) }],
}))

function onPinchEnd() {
  if (pinch.value?.state === 'ended') {
    scale.value *= pinch.value.scale
  }
}
</script>

<template>
  <VView :style="{ flex: 1, justifyContent: 'center', alignItems: 'center' }">
    <VImage 
      ref="imageRef"
      :source="{ uri: 'https://example.com/image.jpg' }"
      :style="imageStyle"
    />
    <VText :style="{ marginTop: 16 }">
      Scale: {{ (scale.value * (pinch.value?.scale ?? 1)).toFixed(2) }}
    </VText>
  </VView>
</template>
```

## Example: Swipe Gallery

```vue
<script setup>
import { ref } from 'vue'
import { useGesture, VView, VText, VImage } from '@thelacanians/vue-native-runtime'

const images = [
  'https://example.com/image1.jpg',
  'https://example.com/image2.jpg',
  'https://example.com/image3.jpg',
]

const currentIndex = ref(0)
const containerRef = ref()

const { swipeLeft, swipeRight } = useGesture(containerRef, {
  swipeLeft: true,
  swipeRight: true,
})

// React to swipes
import { watch } from 'vue'
watch(swipeLeft, (state) => {
  if (state) {
    currentIndex.value = Math.min(currentIndex.value + 1, images.length - 1)
  }
})

watch(swipeRight, (state) => {
  if (state) {
    currentIndex.value = Math.max(currentIndex.value - 1, 0)
  }
})
</script>

<template>
  <VView ref="containerRef" :style="{ flex: 1, justifyContent: 'center', alignItems: 'center' }">
    <VImage 
      :source="{ uri: images[currentIndex] }"
      :style="{ width: 300, height: 300 }"
    />
    <VText :style="{ marginTop: 16 }">
      {{ currentIndex + 1 }} / {{ images.length }} - Swipe to navigate
    </VText>
  </VView>
</template>
```

## useComposedGestures

For handling multiple simultaneous gestures with combined state:

```vue
<script setup>
import { ref } from 'vue'
import { useComposedGestures, VView, VText } from '@thelacanians/vue-native-runtime'

const viewRef = ref()

const { 
  pan, 
  pinch, 
  rotate,
  isGesturing,
  isPinchingAndRotating,
  isPanningAndPinching 
} = useComposedGestures(viewRef)
</script>

<template>
  <VView ref="viewRef" :style="{ flex: 1, justifyContent: 'center', alignItems: 'center' }">
    <VText v-if="isPinchingAndRotating">Pinching + Rotating!</VText>
    <VText v-else-if="isPanningAndPinching">Panning + Pinching!</VText>
    <VText v-else-if="isGesturing">Gesture active</VText>
    <VText v-else>Use two fingers to transform</VText>
  </VView>
</template>
```

## Manual Event Binding

For advanced use cases, use the `on()` method:

```vue
<script setup>
import { ref, onMounted } from 'vue'
import { useGesture, VView } from '@thelacanians/vue-native-runtime'

const viewRef = ref()
const { attach, on, detach } = useGesture()

onMounted(() => {
  attach(viewRef)
  
  // Manual event binding
  const disposePress = on('press', (state) => {
    console.log('Pressed at', state.locationX, state.locationY)
  })
  
  const disposePan = on('pan', (state) => {
    if (state.state === 'ended') {
      console.log('Pan ended with velocity:', state.velocityX, state.velocityY)
    }
  })
  
  // Cleanup on unmount (optional - onUnmounted handles this)
  // disposePress()
  // disposePan()
})
</script>

<template>
  <VView ref="viewRef" :style="{ flex: 1 }">
    <!-- content -->
  </VView>
</template>
```

## Platform Notes

### iOS

- Uses native `UIGestureRecognizer` subclasses
- `forceTouch` uses 3D Touch on supported devices
- `hover` requires iOS 13+ (uses `UIHoverGestureRecognizer`)

### Android

- Uses `GestureDetector` and `ScaleGestureDetector`
- `forceTouch` is emulated based on touch area size

### macOS

- Uses `NSGestureRecognizer` subclasses
- `forceTouch` uses Force Touch trackpad pressure
- `hover` uses `NSTrackingArea` for mouse tracking

## See Also

- [VView](./VView.md) - Basic container component
- [VPressable](./VPressable.md) - Pressable container with feedback
- [useAnimation](../composables/useAnimation.md) - Animation API