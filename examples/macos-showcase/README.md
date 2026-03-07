# macOS Showcase

Demonstrates macOS-specific features and desktop patterns.

## What It Demonstrates

- **Components:** VToolbar, VSplitView, VOutlineView, VView, VText
- **Composables:** `useWindow`, `useMenu`, `useFileDialog`, `useDragDrop`
- **Patterns:**
  - macOS native components
  - Menu bar integration
  - File dialogs
  - Drag and drop
  - Multi-window support

## Key Features

- Native macOS toolbar
- Split view layout
- Outline view (sidebar)
- Menu bar items
- File open/save dialogs
- Drag and drop support

## How to Run

```bash
cd examples/macos-showcase
bun install
bun vue-native dev
```

**Note:** Requires macOS 12.0+

## Key Concepts

### Toolbar

```vue
<VToolbar>
  <VToolbar.Item 
    icon="plus"
    title="New"
    @click="createNew"
  />
  <VToolbar.Item 
    icon="folder"
    title="Open"
    @click="openFile"
  />
</VToolbar>
```

### Split View

```vue
<VSplitView>
  <template #sidebar>
    <VOutlineView :data="items" />
  </template>
  <template #content>
    <VView>
      <VText>Main content</VText>
    </VView>
  </template>
</VSplitView>
```

### File Dialog

```typescript
const { openFile } = useFileDialog()

const result = await openFile({
  title: 'Open Document',
  filters: [{ name: 'Documents', extensions: ['pdf', 'doc', 'txt'] }],
})

if (result.files.length > 0) {
  console.log('Selected:', result.files[0])
}
```

### Menu Bar

```typescript
const { addItem } = useMenu()

addItem({
  id: 'file.new',
  label: 'New',
  accelerator: 'Cmd+N',
  click: () => createNew(),
})
```

## Learn More

- [VToolbar Component](../../docs/src/components/VToolbar.md)
- [VSplitView Component](../../docs/src/components/VSplitView.md)
- [useWindow](../../docs/src/composables/useWindow.md)
- [useMenu](../../docs/src/composables/useMenu.md)
