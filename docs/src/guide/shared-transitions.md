# Shared Element Transitions

Shared element transitions animate views between screens during navigation. When an image on a list screen and the same image on a detail screen share an identifier, the framework animates position and size between them for a seamless visual transition.

## Setup

Register shared elements using `useSharedElementTransition` in both the source and destination screens:

```vue
<!-- ListScreen.vue -->
<script setup>
import { useSharedElementTransition } from '@thelacanians/vue-native-navigation'
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()
const { register } = useSharedElementTransition('hero-image')

function onImageMounted(viewId) {
  register(viewId)
}

function goToDetail(id) {
  router.push('Detail', { id }, { sharedElements: ['hero-image'] })
}
</script>

<template>
  <VView :style="{ flex: 1 }">
    <VImage
      ref="imageRef"
      :source="{ uri: imageUrl }"
      :style="{ width: 100, height: 100, borderRadius: 8 }"
    />
    <VButton :onPress="() => goToDetail(item.id)">
      <VText>View Detail</VText>
    </VButton>
  </VView>
</template>
```

```vue
<!-- DetailScreen.vue -->
<script setup>
import { useSharedElementTransition } from '@thelacanians/vue-native-navigation'

const { register } = useSharedElementTransition('hero-image')
</script>

<template>
  <VView :style="{ flex: 1 }">
    <VImage
      :source="{ uri: imageUrl }"
      :style="{ width: '100%', height: 300 }"
    />
  </VView>
</template>
```

## How It Works

1. **Registration**: Each screen registers views with a shared element ID using `useSharedElementTransition(id)`.

2. **Navigation**: When calling `router.push()`, pass `sharedElements` in the options:
   ```ts
   router.push('Detail', { id: 42 }, {
     sharedElements: ['hero-image', 'title-text']
   })
   ```

3. **Transition**: The framework:
   - Captures the source element's frame (position + size)
   - Navigates to the destination screen
   - Captures the destination element's frame
   - Animates a snapshot from source frame to destination frame

4. **Cleanup**: Registrations are automatically cleaned up when the component unmounts.

## API

### `useSharedElementTransition(id)`

```ts
import { useSharedElementTransition } from '@thelacanians/vue-native-navigation'

const {
  id,         // string — the shared element identifier
  viewId,     // Ref<number | null> — the registered native view ID
  register,   // (nativeViewId: number) => void
  unregister, // () => void
} = useSharedElementTransition('hero-image')
```

| Property | Type | Description |
|----------|------|-------------|
| `id` | `string` | The shared element identifier. |
| `viewId` | `Ref<number \| null>` | The native view ID, or null if not registered. |
| `register` | `(nativeViewId: number) => void` | Register a native view as this shared element. |
| `unregister` | `() => void` | Remove the registration. Called automatically on unmount. |

### `router.push()` with Shared Elements

```ts
router.push(routeName, params?, {
  sharedElements?: string[]  // IDs of elements to animate
})
```

The `sharedElements` array contains the IDs of elements that should transition between screens. Both the source and destination screens must register elements with matching IDs.

### Utility Functions

```ts
import {
  getSharedElementViewId,
  getRegisteredSharedElements,
  clearSharedElementRegistry,
} from '@thelacanians/vue-native-navigation'

// Get the native view ID for a shared element
const viewId = getSharedElementViewId('hero-image')

// Get all registered shared element IDs
const ids = getRegisteredSharedElements()

// Clear all registrations (used internally during transitions)
clearSharedElementRegistry()
```

## Multiple Shared Elements

You can animate multiple elements simultaneously:

```ts
router.push('Detail', { id: 42 }, {
  sharedElements: ['hero-image', 'title-text', 'subtitle']
})
```

Each element animates independently between its source and destination frames.

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | JS-driven animation using `UIView.animate` for position and scale interpolation. |
| Android | JS-driven animation using `ObjectAnimator` for position and scale interpolation. |

## Notes

- Shared element IDs must be unique across the currently visible screens.
- The `register()` function should be called after the view is mounted and its native view ID is available.
- Registrations are automatically cleaned up when the component is unmounted via `onUnmounted`.
- The transition animation is JS-driven: the framework measures source/destination frames via the bridge and drives native animations.
