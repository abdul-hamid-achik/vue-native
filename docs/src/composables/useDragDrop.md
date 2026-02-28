# useDragDrop

Enable drag and drop support for macOS. Register drop zones on views and respond to files or data being dragged into your app.

## Usage

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useDragDrop } from '@thelacanians/vue-native-runtime'

const { isDragging, enableDropZone, onDrop, onDragEnter, onDragLeave } = useDragDrop()

enableDropZone()

onDrop((files) => {
  console.log('Dropped files:', files)
})

onDragEnter(() => {
  console.log('Drag entered')
})

onDragLeave(() => {
  console.log('Drag left')
})
</script>

<template>
  <VView
    :style="{
      padding: 40,
      borderWidth: 2,
      borderStyle: 'dashed',
      borderColor: isDragging ? '#007AFF' : '#ccc',
      borderRadius: 12,
      backgroundColor: isDragging ? '#E8F0FE' : '#fff',
      alignItems: 'center',
      justifyContent: 'center',
    }"
  >
    <VText>{{ isDragging ? 'Drop here!' : 'Drag files here' }}</VText>
  </VView>
</template>
```

## API

```ts
useDragDrop(): {
  isDragging: Readonly<Ref<boolean>>
  enableDropZone: () => Promise<void>
  onDrop: (callback: (files: string[]) => void) => () => void
  onDragEnter: (callback: () => void) => () => void
  onDragLeave: (callback: () => void) => () => void
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `isDragging` | `Readonly<Ref<boolean>>` | Reactive ref that is `true` when a drag operation is hovering over the drop zone. |
| `enableDropZone` | `() => Promise<void>` | Register the window as a drop target. Call this once during component setup. |
| `onDrop` | `(callback: (files: string[]) => void) => () => void` | Register a callback invoked when files are dropped. Receives an array of absolute file paths. Returns an unsubscribe function. |
| `onDragEnter` | `(callback: () => void) => () => void` | Register a callback invoked when a drag enters the zone. Returns an unsubscribe function. |
| `onDragLeave` | `(callback: () => void) => () => void` | Register a callback invoked when a drag leaves the zone. Returns an unsubscribe function. |

### Types

The `onDrop` callback receives `string[]` — an array of absolute POSIX file paths for every file dropped onto the window. No additional type filtering is exposed at the JS layer.

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | No — iOS uses different drag APIs. |
| Android | No — Android uses different drag APIs. |
| macOS | Yes — Uses `NSView` `registerForDraggedTypes` and `NSDraggingDestination` protocol. |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useDragDrop } from '@thelacanians/vue-native-runtime'

const droppedFiles = ref<string[]>([])
const { isDragging, enableDropZone, onDrop } = useDragDrop()

enableDropZone()

onDrop((files) => {
  droppedFiles.value = [...droppedFiles.value, ...files]
})
</script>

<template>
  <VView :style="{ padding: 20, gap: 16 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold' }">Drag & Drop Demo</VText>

    <VView
      :style="{
        padding: 40,
        borderWidth: 2,
        borderStyle: 'dashed',
        borderColor: isDragging ? '#007AFF' : '#ccc',
        borderRadius: 12,
        backgroundColor: isDragging ? '#E8F0FE' : '#FAFAFA',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: 120,
      }"
    >
      <VText :style="{ fontSize: 16, color: isDragging ? '#007AFF' : '#999' }">
        {{ isDragging ? 'Release to drop' : 'Drag files here' }}
      </VText>
    </VView>

    <VView v-if="droppedFiles.length > 0">
      <VText :style="{ fontWeight: 'bold', marginBottom: 8 }">
        Dropped Files ({{ droppedFiles.length }}):
      </VText>
      <VText v-for="(file, i) in droppedFiles" :key="i" :style="{ fontSize: 13, color: '#666' }">
        {{ file }}
      </VText>
    </VView>
  </VView>
</template>
```

## Notes

- `enableDropZone` takes no arguments. It registers the entire window as a drop target on the native side. Call it once during component setup.
- `isDragging` is a readonly reactive ref that updates automatically — use it to style your drop indicator.
- `onDrop` receives `string[]` — a flat array of absolute POSIX file paths (e.g. `/Users/name/Desktop/file.png`). You can pass these paths directly to `useFileSystem` for reading.
- All event listener functions (`onDrop`, `onDragEnter`, `onDragLeave`) return unsubscribe functions. Call the returned function to stop listening.
- Calling these methods on iOS or Android is a no-op and does not throw. `isDragging` will always be `false`.
