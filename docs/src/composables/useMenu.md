# useMenu

Create and manage native macOS menus — both the application menu bar and context menus. Provides methods to set the app menu, show context menus on right-click, and listen for menu item selections.

## Usage

```vue
<script setup>
import { useMenu } from '@thelacanians/vue-native-runtime'

const { setAppMenu, showContextMenu, onMenuItemClick } = useMenu()

setAppMenu([
  {
    label: 'File',
    children: [
      { id: 'new', label: 'New', shortcut: 'cmd+n' },
      { id: 'open', label: 'Open...', shortcut: 'cmd+o' },
      { type: 'separator' },
      { id: 'quit', label: 'Quit', shortcut: 'cmd+q' },
    ],
  },
  {
    label: 'Edit',
    children: [
      { id: 'undo', label: 'Undo', shortcut: 'cmd+z' },
      { id: 'redo', label: 'Redo', shortcut: 'cmd+shift+z' },
    ],
  },
])

onMenuItemClick((id) => {
  console.log('Menu item clicked:', id)
})
</script>
```

## API

```ts
useMenu(): {
  setAppMenu: (items: MenuItemConfig[]) => void
  showContextMenu: (items: MenuItemConfig[]) => void
  onMenuItemClick: (callback: (id: string) => void) => void
}
```

### Return Value

| Method | Signature | Description |
|--------|-----------|-------------|
| `setAppMenu` | `(items: MenuItemConfig[]) => void` | Set the application menu bar. Replaces the entire menu. |
| `showContextMenu` | `(items: MenuItemConfig[]) => void` | Show a context menu at the current mouse position. |
| `onMenuItemClick` | `(callback: (id: string) => void) => void` | Register a callback invoked when any menu item is clicked. The `id` from the `MenuItemConfig` is passed. |

### Types

```ts
interface MenuItemConfig {
  /** Unique identifier for the menu item. Required for non-separator items. */
  id?: string
  /** Display text for the menu item. */
  label?: string
  /** Item type. Defaults to 'normal'. */
  type?: 'normal' | 'separator' | 'checkbox'
  /** Keyboard shortcut (e.g. 'cmd+s', 'cmd+shift+n'). */
  shortcut?: string
  /** Whether the item is disabled (grayed out). */
  disabled?: boolean
  /** Whether a checkbox item is checked. Only used when type is 'checkbox'. */
  checked?: boolean
  /** Submenu items. Creates a hierarchical menu. */
  children?: MenuItemConfig[]
}
```

#### Shortcut Format

Shortcuts use a `+`-separated modifier string:

| Modifier | Key |
|----------|-----|
| `cmd` | Command |
| `shift` | Shift |
| `alt` | Option |
| `ctrl` | Control |

Examples: `cmd+s`, `cmd+shift+n`, `alt+f4`, `ctrl+alt+delete`

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
    label: 'File',
    children: [
      { id: 'new-file', label: 'New File', shortcut: 'cmd+n' },
      { id: 'open', label: 'Open...', shortcut: 'cmd+o' },
      { id: 'save', label: 'Save', shortcut: 'cmd+s' },
      { type: 'separator' },
      { id: 'quit', label: 'Quit', shortcut: 'cmd+q' },
    ],
  },
  {
    label: 'View',
    children: [
      { id: 'sidebar', label: 'Show Sidebar', type: 'checkbox', checked: true, shortcut: 'cmd+b' },
      { id: 'fullscreen', label: 'Full Screen', shortcut: 'ctrl+cmd+f' },
    ],
  },
])

onMenuItemClick((id) => {
  lastAction.value = id
})

function handleRightClick() {
  showContextMenu([
    { id: 'cut', label: 'Cut', shortcut: 'cmd+x' },
    { id: 'copy', label: 'Copy', shortcut: 'cmd+c' },
    { id: 'paste', label: 'Paste', shortcut: 'cmd+v' },
    { type: 'separator' },
    { id: 'select-all', label: 'Select All', shortcut: 'cmd+a' },
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

- `setAppMenu` replaces the entire application menu. Call it once at app startup.
- `showContextMenu` is typically called in response to a right-click or long-press event.
- The `onMenuItemClick` callback receives the `id` string — use it to dispatch actions in your app.
- Calling these methods on iOS or Android is a no-op and does not throw.
- The cleanup function returned by `onMenuItemClick` is automatically called when the component unmounts.
