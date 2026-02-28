# useDragDrop

Enable drag and drop support for macOS. Register drop zones on views and respond to files or data being dragged into your app.

## Usage

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useDragDrop } from '@thelacanians/vue-native-runtime'

const dropZoneRef = ref()
const { isDragging, enableDropZone, onDrop, onDragEnter, onDragLeave } = useDragDrop()

enableDropZone(dropZoneRef, {
  acceptedTypes: ['public.image', 'public.file-url'],
})

onDrop((items) => {
  console.log('Dropped items:', items)
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
    ref="dropZoneRef"
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
  isDragging: Ref<boolean>
  enableDropZone: (ref: Ref<NativeNode>, options?: DropZoneOptions) => void
  onDrop: (callback: (items: DropItem[]) => void) => void
  onDragEnter: (callback: () => void) => void
  onDragLeave: (callback: () => void) => void
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `isDragging` | `Ref<boolean>` | Reactive ref that is `true` when a drag operation is hovering over the registered drop zone. |
| `enableDropZone` | `(ref, options?) => void` | Register a view as a drop target. Pass a template ref to the view. |
| `onDrop` | `(callback) => void` | Register a callback invoked when items are dropped on the zone. |
| `onDragEnter` | `(callback) => void` | Register a callback invoked when a drag enters the zone. |
| `onDragLeave` | `(callback) => void` | Register a callback invoked when a drag leaves the zone. |

### Types

```ts
interface DropZoneOptions {
  /** UTI types to accept (e.g. 'public.image', 'public.file-url'). Omit to accept all. */
  acceptedTypes?: string[]
}

interface DropItem {
  /** The type of the dropped item (UTI string). */
  type: string
  /** File path, if the item is a file. */
  path?: string
  /** Text content, if the item is a string. */
  text?: string
  /** Raw data as base64, if the item is binary data. */
  data?: string
}
```

#### Common UTI Types

| UTI | Description |
|-----|-------------|
| `public.file-url` | Any file |
| `public.image` | Images (PNG, JPEG, etc.) |
| `public.plain-text` | Plain text strings |
| `public.html` | HTML content |
| `public.url` | URLs |

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

const dropZoneRef = ref()
const droppedFiles = ref<string[]>([])
const { isDragging, enableDropZone, onDrop } = useDragDrop()

enableDropZone(dropZoneRef, {
  acceptedTypes: ['public.file-url'],
})

onDrop((items) => {
  const paths = items
    .filter((item) => item.path)
    .map((item) => item.path!)
  droppedFiles.value = [...droppedFiles.value, ...paths]
})
</script>

<template>
  <VView :style="{ padding: 20, gap: 16 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold' }">Drag & Drop Demo</VText>

    <VView
      ref="dropZoneRef"
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

- `enableDropZone` must be called with a template ref after the component mounts. The view is registered as a drop target on the native side.
- `isDragging` updates reactively — use it to style the drop zone (highlight, border color, etc.).
- Callbacks registered with `onDrop`, `onDragEnter`, and `onDragLeave` are automatically cleaned up when the component unmounts.
- Calling these methods on iOS or Android is a no-op and does not throw. `isDragging` will always be `false`.
- For file drops, the `path` property contains the absolute POSIX file path. You can pass this to `useFileSystem` for reading.
