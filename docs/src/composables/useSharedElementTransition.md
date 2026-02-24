# useSharedElementTransition

Register native views as shared elements for cross-screen transitions. When navigating between screens, elements with the same shared ID on the source and destination screens animate smoothly in position and size, creating a seamless visual connection between views.

## Usage

```vue
<script setup>
import { useSharedElementTransition } from '@thelacanians/vue-native-runtime'
import { useRouter } from '@thelacanians/vue-native-navigation'

const { id, register } = useSharedElementTransition('hero-image')
const router = useRouter()

function goToDetail() {
  router.push('Detail', { sharedElements: ['hero-image'] })
}
</script>

<template>
  <VView>
    <VImage
      source="https://example.com/photo.jpg"
      :style="{ width: 120, height: 120, borderRadius: 8 }"
      @layout="(e) => register(e.nativeViewId)"
    />
    <VButton title="View Detail" @press="goToDetail" />
  </VView>
</template>
```

## API

```ts
useSharedElementTransition(elementId: string): {
  id: string,
  viewId: Ref<number | null>,
  register: (nativeViewId: number) => void,
  unregister: () => void
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `elementId` | `string` | A unique identifier for the shared element. Must match on both source and destination screens. |

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `id` | `string` | The shared element identifier passed to the composable. |
| `viewId` | `Ref<number \| null>` | The native view ID of the registered element, or `null` if not registered. |
| `register` | `(nativeViewId: number) => void` | Register a native view as the shared element for this ID. |
| `unregister` | `() => void` | Unregister the shared element, removing it from the transition registry. |

### Utility Functions

The following utility functions are also exported for advanced use cases:

```ts
/** Measure the frame (position and size) of a native view by its ID. */
measureViewFrame(nativeViewId: number): Promise<{ x: number, y: number, width: number, height: number }>

/** Get the registered native view ID for a shared element identifier. */
getSharedElementViewId(elementId: string): number | null

/** Get all currently registered shared elements as a Map. */
getRegisteredSharedElements(): Map<string, number>

/** Clear all entries from the shared element registry. */
clearSharedElementRegistry(): void
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `UIView` snapshotting and `UIViewPropertyAnimator` for smooth frame animations between source and destination views. |
| Android | Uses `View` snapshotting and `ObjectAnimator` for smooth frame animations between source and destination views. |

## Example

```vue
<!-- ListScreen.vue -->
<script setup>
import { useSharedElementTransition } from '@thelacanians/vue-native-runtime'
import { useRouter } from '@thelacanians/vue-native-navigation'

const router = useRouter()

const items = [
  { id: 1, title: 'Mountain', image: 'https://example.com/mountain.jpg' },
  { id: 2, title: 'Ocean', image: 'https://example.com/ocean.jpg' },
]

function openItem(item) {
  router.push('Detail', {
    params: { id: item.id },
    sharedElements: [`photo-${item.id}`]
  })
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VView v-for="item in items" :key="item.id" :style="{ marginBottom: 16 }">
      <SharedImage :elementId="`photo-${item.id}`" :source="item.image" />
      <VText :style="{ fontSize: 18 }">{{ item.title }}</VText>
      <VButton title="Open" @press="openItem(item)" />
    </VView>
  </VView>
</template>
```

```vue
<!-- SharedImage.vue (reusable wrapper) -->
<script setup>
import { useSharedElementTransition } from '@thelacanians/vue-native-runtime'

const props = defineProps({
  elementId: String,
  source: String
})

const { register } = useSharedElementTransition(props.elementId)
</script>

<template>
  <VImage
    :source="source"
    :style="{ width: 200, height: 200, borderRadius: 12 }"
    @layout="(e) => register(e.nativeViewId)"
  />
</template>
```

```vue
<!-- DetailScreen.vue -->
<script setup>
import { useSharedElementTransition } from '@thelacanians/vue-native-runtime'
import { useRoute } from '@thelacanians/vue-native-navigation'

const route = useRoute()
const { register } = useSharedElementTransition(`photo-${route.params.id}`)
</script>

<template>
  <VView :style="{ flex: 1 }">
    <VImage
      :source="`https://example.com/${route.params.id}.jpg`"
      :style="{ width: '100%', height: 300 }"
      @layout="(e) => register(e.nativeViewId)"
    />
    <VText :style="{ fontSize: 24, padding: 20 }">Detail View</VText>
  </VView>
</template>
```

## Notes

- The `elementId` must be identical on both the source and destination screens for the transition to work.
- Call `register()` with the native view ID after the view has been laid out. The `@layout` event is the recommended way to obtain the native view ID.
- The composable automatically unregisters the shared element when the component unmounts, preventing stale entries in the registry.
- Transitions animate both position and size from the source element's frame to the destination element's frame.
- Works with `router.push()` by passing `sharedElements` as an array of element IDs in the navigation options.
- For best visual results, ensure the source and destination elements render similar content (e.g., the same image).
- Use the utility functions (`getRegisteredSharedElements`, `clearSharedElementRegistry`) for debugging or advanced transition orchestration.
