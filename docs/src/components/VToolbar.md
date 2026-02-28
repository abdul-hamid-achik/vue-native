# VToolbar

A native macOS toolbar component that attaches an `NSToolbar` to the window, supporting icon and label items with click handling.

> **Platform:** macOS only

## Usage

```vue
<script setup lang="ts">
import { ref } from '@thelacanians/vue-native-runtime'

const items = ref([
  { id: 'new',  label: 'New',  icon: 'doc.badge.plus' },
  { id: 'open', label: 'Open', icon: 'folder' },
  { id: 'save', label: 'Save', icon: 'square.and.arrow.down' },
])

function onItemClick(e: { id: string }) {
  console.log('Toolbar item clicked:', e.id)
}
</script>

<template>
  <VToolbar
    :items="items"
    displayMode="iconAndLabel"
    :showsBaselineSeparator="true"
    @itemClick="onItemClick"
  />
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `items` | `ToolbarItem[]` | **required** | Array of toolbar item descriptors |
| `displayMode` | `'iconOnly' \| 'labelOnly' \| 'iconAndLabel'` | `'iconAndLabel'` | Controls how each toolbar item renders its icon and label |
| `showsBaselineSeparator` | `boolean` | `true` | Whether to draw the thin separator line below the toolbar |

### ToolbarItem

Each entry in the `items` array has this shape:

```ts
interface ToolbarItem {
  id: string      // Unique identifier for the item — returned in itemClick events
  label: string   // Text label shown beneath or beside the icon
  icon?: string   // SF Symbol name (e.g. 'folder') or named asset from the asset catalog
}
```

- If `icon` resolves to a known SF Symbol it is loaded via `NSImage(systemSymbolName:)`. Otherwise the factory falls back to `NSImage(named:)` for asset catalog images.
- Items without an `icon` are rendered as label-only toolbar items regardless of `displayMode`.

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@itemClick` | `{ id: string }` | Fired when the user clicks a toolbar item. The `id` matches the item's `id` field from the `items` prop. |

## Examples

### Icon-only toolbar

```vue
<script setup lang="ts">
const tools = [
  { id: 'bold',      label: 'Bold',      icon: 'bold' },
  { id: 'italic',    label: 'Italic',    icon: 'italic' },
  { id: 'underline', label: 'Underline', icon: 'underline' },
]
</script>

<template>
  <VToolbar
    :items="tools"
    displayMode="iconOnly"
    :showsBaselineSeparator="false"
    @itemClick="e => applyFormat(e.id)"
  />
</template>
```

### Toolbar with dynamic items

Add or remove items reactively — the toolbar rebuilds automatically when `items` changes.

```vue
<script setup lang="ts">
import { ref, computed } from '@thelacanians/vue-native-runtime'

const canSave = ref(false)

const items = computed(() => {
  const base = [
    { id: 'new',  label: 'New',  icon: 'doc.badge.plus' },
    { id: 'open', label: 'Open', icon: 'folder' },
  ]
  if (canSave.value) {
    base.push({ id: 'save', label: 'Save', icon: 'square.and.arrow.down' })
  }
  return base
})

function handleItem(e: { id: string }) {
  if (e.id === 'new')  createDocument()
  if (e.id === 'open') openDocument()
  if (e.id === 'save') saveDocument()
}
</script>

<template>
  <VToolbar :items="items" @itemClick="handleItem" />
</template>
```

### Label-only toolbar

```vue
<template>
  <VToolbar
    :items="[
      { id: 'file', label: 'File' },
      { id: 'edit', label: 'Edit' },
      { id: 'view', label: 'View' },
    ]"
    displayMode="labelOnly"
    @itemClick="onMenuClick"
  />
</template>
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS      | No-op   |
| Android  | No-op   |
| macOS    | Full    |

## Notes

- `VToolbar` renders a zero-size placeholder `FlippedView` in the layout tree. The actual `NSToolbar` is attached directly to the window, outside the normal view hierarchy. The placeholder does **not** affect the layout of sibling components.
- The toolbar is created (or rebuilt) the first time the placeholder view is added to a window. If `items` is updated before the view appears in a window, the toolbar creation is deferred until the window is available.
- Only one `VToolbar` should be used per window. Mounting multiple instances will overwrite the window's toolbar each time.
- SF Symbol names can be verified in the macOS **SF Symbols** app. Only symbols available on macOS 11+ are supported without a version guard.
- `displayMode` changes applied before the view is in a window are ignored. Set `displayMode` after the component has mounted, or ensure the view is in a window first.
