# useMenu

Create and manage native macOS menus — both the application menu bar and context menus. Provides methods to set the app menu, show context menus on right-click, and listen for menu item selections.

## Usage

```vue
<script setup>
import { useMenu } from '@thelacanians/vue-native-runtime'

const { setAppMenu, showContextMenu, onMenuItemClick } = useMenu()

setAppMenu([
  {
    title: 'File',
    items: [
      { id: 'new', title: 'New', key: 'n' },
      { id: 'open', title: 'Open...', key: 'o' },
      { title: '', separator: true },
      { id: 'quit', title: 'Quit', key: 'q' },
    ],
  },
  {
    title: 'Edit',
    items: [
      { id: 'undo', title: 'Undo', key: 'z' },
      { id: 'redo', title: 'Redo', key: 'Z' },
    ],
  },
])

onMenuItemClick((id, title) => {
  console.log('Menu item clicked:', id, title)
})
</script>
```

## API

```ts
useMenu(): {
  setAppMenu: (sections: MenuSection[]) => Promise<void>
  showContextMenu: (items: MenuItem[]) => Promise<void>
  onMenuItemClick: (callback: (id: string, title: string) => void) => () => void
}
```

### Return Value

| Method | Signature | Description |
|--------|-----------|-------------|
| `setAppMenu` | `(sections: MenuSection[]) => Promise<void>` | Set the application menu bar. Replaces the entire menu. Takes an array of `MenuSection` objects, each with a `title` and `items` list. |
| `showContextMenu` | `(items: MenuItem[]) => Promise<void>` | Show a context menu at the current mouse position. |
| `onMenuItemClick` | `(callback: (id: string, title: string) => void) => () => void` | Register a callback invoked when any menu item is clicked. Returns an unsubscribe function. Both the `id` and `title` of the clicked item are passed to the callback. |

### Types

```ts
interface MenuItem {
  /** Unique identifier for the menu item. */
  id?: string
  /** Display text for the menu item. */
  title: string
  /** Keyboard shortcut key (single character, e.g. 'n', 's', 'z'). */
  key?: string
  /** Whether the item is disabled (grayed out). */
  disabled?: boolean
  /** Whether the item is a separator line. */
  separator?: boolean
}

interface MenuSection {
  /** Display title for the menu section (shown as the top-level menu name). */
  title: string
  /** Items in this section. */
  items: MenuItem[]
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | No — iOS apps use `VActionSheet` for contextual actions. |
| Android | No — Android apps use `VActionSheet` for contextual actions. |
| macOS | Yes — Uses `NSMenu` and `NSMenuItem`. |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useMenu } from '@thelacanians/vue-native-runtime'

const { setAppMenu, showContextMenu, onMenuItemClick } = useMenu()
const lastAction = ref('None')

setAppMenu([
  {
    title: 'File',
    items: [
      { id: 'new-file', title: 'New File', key: 'n' },
      { id: 'open', title: 'Open...', key: 'o' },
      { id: 'save', title: 'Save', key: 's' },
      { title: '', separator: true },
      { id: 'quit', title: 'Quit', key: 'q' },
    ],
  },
  {
    title: 'View',
    items: [
      { id: 'sidebar', title: 'Show Sidebar', key: 'b' },
      { id: 'fullscreen', title: 'Full Screen' },
    ],
  },
])

onMenuItemClick((id, title) => {
  lastAction.value = `${title} (${id})`
})

function handleRightClick() {
  showContextMenu([
    { id: 'cut', title: 'Cut', key: 'x' },
    { id: 'copy', title: 'Copy', key: 'c' },
    { id: 'paste', title: 'Paste', key: 'v' },
    { title: '', separator: true },
    { id: 'select-all', title: 'Select All', key: 'a' },
  ])
}
</script>

<template>
  <VView :style="{ padding: 20, gap: 12 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold' }">Menu Demo</VText>
    <VText>Last action: {{ lastAction }}</VText>

    <VButton :onPress="handleRightClick">
      <VText>Show Context Menu</VText>
    </VButton>
  </VView>
</template>
```

## Notes

- `setAppMenu` accepts an array of `MenuSection` objects (not flat `MenuItemConfig` items). Each section has a `title` and an `items` array of `MenuItem` objects.
- Use `separator: true` on a `MenuItem` to render a divider line between items.
- `showContextMenu` takes a flat `MenuItem[]` list and displays it at the current mouse position.
- The `onMenuItemClick` callback receives both the item `id` and `title` — the `id` is useful for action dispatch and the `title` is useful for display.
- `onMenuItemClick` returns an unsubscribe function. Call it to stop listening before the component unmounts, or rely on automatic cleanup.
- Calling these methods on iOS or Android is a no-op and does not throw.
