# macOS Showcase

Demonstrates macOS-specific features and desktop patterns.

> **macOS host included; iOS and Android are not.** This directory ships a
> runnable `macos/` XcodeGen host (`macos/project.yml` is the source of truth;
> `macos/*.xcodeproj` is generated and gitignored). There is no `ios/` or
> `android/` shell here, so `dev:ios` and `dev:android` build a bundle with
> nothing to run it in — this example targets desktop patterns. To see the same
> UI on mobile, copy `app/`, `vite.config.ts` and `env.d.ts` into a scaffolded
> project (`bunx vue-native create my-app`) and drop the macOS-only pieces.

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
bun run build          # produces dist/vue-native-bundle.js, which the host copies
cd macos && xcodegen generate && cd ..
open macos/MacosShowcase.xcodeproj   # then Cmd+R on a macOS destination
```

Or from the repo root, once the bundle exists:

```bash
cd macos && xcodebuild -project MacosShowcase.xcodeproj -scheme MacosShowcase \
  -destination 'platform=macOS' build
```

`macos/project.yml` declares the host: it points at the repo's
`native/macos/VueNativeMacOS` package (which resolves `VueNativeShared` by local
path, so a remote git URL would not work), copies `../dist/vue-native-bundle.js`
into `Contents/Resources`, and ad-hoc signs so no Apple Developer team is needed.
Vue Native's macOS runtime requires macOS 15+.

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
