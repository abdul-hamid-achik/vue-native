# macOS Showcase

Demonstrates macOS-specific features and desktop patterns.

> **Requires a native host.** This directory ships Vue source and build config
> only — there is no `ios/`, `android/`, or `macos/` app shell here. `bun run
> dev:ios`, `dev:android` and `dev:macos` build the JS bundle but have nothing
> to run it in. To see this app on a device or simulator:
>
> ```bash
> bunx vue-native create my-app   # scaffolds iOS + Android hosts
> ```
>
> Then copy `app/`, `vite.config.ts` and `env.d.ts` from this example over the
> scaffold's equivalents, run `bun run build` here, and open the generated
> project in Xcode or Android Studio. `vue-native create` does not scaffold a
> macOS shell yet.

## What It Demonstrates

- **Components:** VView, VText, VButton, VCheckbox, VRadio, VDropdown, VSegmentedControl, VSlider, VScrollView
- **Composables:** `useWindow`, `useMenu`, `useFileDialog`, `useDragDrop`, `usePlatform`
- **Patterns:**
  - App menu bar integration via `useMenu`
  - Open / save file dialogs via `useFileDialog`
  - Drag and drop via `useDragDrop`
  - Window information via `useWindow`
  - Platform branching with `usePlatform`
  - Desktop form controls (segmented control, dropdown, radio, checkbox, slider)

> ⚠️ **`VToolbar`, `VSplitView` and `VOutlineView` are not used here.** Those
> components exist in the runtime (`packages/runtime/src/components/`) and this
> example was meant to show them, but `app/App.vue` does not render any of them.
> Adding them is the intended follow-up; until then the list above reflects what
> the code actually does.

## Key Features

- App menu bar items via `useMenu`
- File open / save dialogs via `useFileDialog`
- Drag and drop via `useDragDrop`
- Window information via `useWindow`
- Desktop form controls

Native toolbar, split view, outline view and multi-window support are **not**
demonstrated yet — see the note above.

## How to Run

```bash
cd examples/macos-showcase
bun install
bun run dev:macos
```

This directory contains the macOS Vue source and build configuration, not an
Xcode app shell. Copy it into a project with a `VueNativeWindowController`
macOS host before launching it. Vue Native's macOS runtime requires macOS 15+.

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
