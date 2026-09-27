# Components

Vue Native provides 40 built-in components that map directly to native views on iOS, Android, and macOS.

## Import

All components are globally registered — no import needed in templates.

## Reading the tables

The three platform columns name the native view (or views) that backs the component on each OS.

- **"JS-composed"** means the component has no native factory of its own — it is assembled in TypeScript out of other components (and, for animation, `useAnimation`), so it behaves identically on all three platforms.
- **"No-op"** means the component is registered for API compatibility but renders nothing (or a hidden, zero-size placeholder). Your app will not crash or warn in production; it just gets no UI from that component on that platform.
- `VToolbar`, `VSplitView`, and `VOutlineView` are **macOS-only** — in development builds they log a console warning on iOS/Android and render nothing there.

## Layout

| Component | iOS | Android | macOS | Description |
|-----------|-----|---------|-------|-------------|
| [`<VView>`](../components/VView.md) | UIView | FlexboxLayout | FlippedView (NSView) | Container view. Supports all Flexbox props |
| [`<VScrollView>`](../components/VScrollView.md) | UIScrollView | ScrollView | NSScrollView | Scrollable container |
| [`<VSafeArea>`](../components/VSafeArea.md) | UIView + safeAreaInsets | View + WindowInsetsCompat | Pass-through NSView (no insets) | Respects device safe areas |
| [`<VKeyboardAvoiding>`](../components/VKeyboardAvoiding.md) | Custom VC logic | AdjustResize / manual offset | Pass-through NSView (no avoidance) | Shifts content when keyboard appears |
| [`<VSplitView>`](../components/VSplitView.md) | No-op | No-op | NSSplitView | Resizable split pane. **macOS only** |

## Text & Input

| Component | iOS | Android | macOS | Description |
|-----------|-----|---------|-------|-------------|
| [`<VText>`](../components/VText.md) | UILabel | TextView | NSTextField | Text display |
| [`<VInput>`](../components/VInput.md) | UITextField / UITextView | EditText | NSTextField | Text input with `v-model` |
| [`<VCheckbox>`](../components/VCheckbox.md) | Custom checkbox view | CheckBox | NSButton (checkbox) | Boolean checkbox with optional label, `v-model` |
| [`<VRadio>`](../components/VRadio.md) | UIStackView + radio circles | RadioGroup + RadioButton | NSStackView + NSButton (radio) | Radio button group, `v-model` |
| [`<VDropdown>`](../components/VDropdown.md) | UIMenu (iOS 14+) / UIPickerView | Spinner | NSPopUpButton | Dropdown selection, `v-model` |
| [`<VPicker>`](../components/VPicker.md) | UIDatePicker | DatePickerDialog / NumberPicker | NSDatePicker | Date/time and value picker |

## Interactive

| Component | iOS | Android | macOS | Description |
|-----------|-----|---------|-------|-------------|
| [`<VButton>`](../components/VButton.md) | UIButton / UIControl | Custom TouchDelegate | ClickableView (NSView) | Pressable container with `:onPress` |
| [`<VPressable>`](../components/VPressable.md) | Custom TouchableView | Custom TouchableView | PressableView (ClickableView subclass) | Generic pressable wrapper with press-in/out events |
| [`<VSwitch>`](../components/VSwitch.md) | UISwitch | Switch | NSSwitch | Toggle with `v-model` |
| [`<VSlider>`](../components/VSlider.md) | UISlider | SeekBar | NSSlider | Range slider with `v-model` |
| [`<VSegmentedControl>`](../components/VSegmentedControl.md) | UISegmentedControl | TabLayout | NSSegmentedControl | Tab strip selector |
| [`<VToolbar>`](../components/VToolbar.md) | No-op | No-op | NSToolbar | Window toolbar with items. **macOS only** |

## Media

| Component | iOS | Android | macOS | Description |
|-----------|-----|---------|-------|-------------|
| [`<VImage>`](../components/VImage.md) | UIImageView + URLSession | ImageView + Coil | NSImageView | Async image loading with caching |
| [`<VSVG>`](../components/VSVG.md) | SVGKit | AndroidSVG (custom `SVGView`) | SVGKit + NSImageView | Native SVG rendering (inline, asset, or URI) |
| [`<VVideo>`](../components/VVideo.md) | AVPlayer | MediaPlayer | AVPlayer + AVPlayerLayer | Inline video playback with progress events |
| [`<VWebView>`](../components/VWebView.md) | WKWebView | WebView | WKWebView | Embedded web view |

## Lists

| Component | iOS | Android | macOS | Description |
|-----------|-----|---------|-------|-------------|
| [`<VList>`](../components/VList.md) | UITableView | RecyclerView | NSScrollView + NSTableView | Virtualized list for large datasets. Rows come from the `#item` slot |
| [`<VSectionList>`](../components/VSectionList.md) | UITableView (sections) | RecyclerView | NSScrollView + NSTableView (group rows) | Sectioned list with headers |
| [`<VFlatList>`](../components/VFlatList.md) | JS-composed (VScrollView + VView) | JS-composed | JS-composed | React Native-compatible list. Takes a `renderItem` prop, unlike `VList` |
| [`<VOutlineView>`](../components/VOutlineView.md) | No-op | No-op | NSOutlineView | Hierarchical outline / source list. **macOS only** |

## Feedback

| Component | iOS | Android | macOS | Description |
|-----------|-----|---------|-------|-------------|
| [`<VActivityIndicator>`](../components/VActivityIndicator.md) | UIActivityIndicatorView | ProgressBar (circular) | NSProgressIndicator (spinner) | Loading spinner |
| [`<VProgressBar>`](../components/VProgressBar.md) | UIProgressView | ProgressBar (horizontal) | NSProgressIndicator (bar) | Progress bar |
| [`<VAlertDialog>`](../components/VAlertDialog.md) | UIAlertController | AlertDialog | NSAlert | Native alert |
| [`<VActionSheet>`](../components/VActionSheet.md) | UIAlertController (.actionSheet) | BottomSheetDialog | NSMenu | Action sheet |
| [`<VModal>`](../components/VModal.md) | UIViewController presentation | Dialog | NSPanel | Full-screen overlay modal |
| [`<VRefreshControl>`](../components/VRefreshControl.md) | UIRefreshControl | SwipeRefreshLayout | No-op placeholder | Pull-to-refresh. Mobile pattern — inert on macOS |

## Navigation

| Component | iOS | Android | macOS | Description |
|-----------|-----|---------|-------|-------------|
| [`<VTabBar>`](../components/VTabBar.md) | JS-composed (VView + VPressable) | JS-composed | JS-composed | Tab bar with labels, icons, and badges |
| [`<VDrawer>`](../components/VDrawer.md) | JS-composed (VPressable + VView) | JS-composed | JS-composed | Side-menu drawer container |
| [`<VDrawerItem>`](../components/VDrawer.md) | JS-composed | JS-composed | JS-composed | Row inside a `VDrawer` |
| [`<VDrawerSection>`](../components/VDrawer.md) | JS-composed | JS-composed | JS-composed | Labelled group of `VDrawerItem`s |

## System

| Component | iOS | Android | macOS | Description |
|-----------|-----|---------|-------|-------------|
| [`<VStatusBar>`](../components/VStatusBar.md) | UIStatusBarStyle (via the root view controller) | WindowInsetsController | No-op | Control status bar style. Props: `barStyle`, `hidden`, `animated` |

## Vue Built-ins

These are Vue's own components, re-exported so they cooperate with the custom renderer. They have no native view of their own and work identically on all three platforms.

| Component | iOS | Android | macOS | Description |
|-----------|-----|---------|-------|-------------|
| [`<VTransition>`](../components/VTransition.md) | JS-composed (`useAnimation`) | JS-composed | JS-composed | Enter/leave transitions driven by native animations |
| `<VTransitionGroup>` | JS-composed (`useAnimation`) | JS-composed | JS-composed | Same, for lists |
| [`<KeepAlive>`](../components/KeepAlive.md) | Renderer-level | Renderer-level | Renderer-level | Caches inactive component instances |
| [`<VSuspense>`](../components/VSuspense.md) | Renderer-level | Renderer-level | Renderer-level | Async component boundary (Vue's `Suspense`) |

## Also registered globally

`createApp()` registers the 40 components above plus a few extras, so these need no import either:

| Global name | Notes |
|---|---|
| `ErrorBoundary` / [`VErrorBoundary`](../components/VErrorBoundary.md) | Two names for the same component. Both are registered and both are in the `GlobalComponents` type augmentation, so editors resolve either tag. |
| `VDrawer.Item` / `VDrawer.Section` | Dotted aliases for `VDrawerItem` / `VDrawerSection`. Registered at runtime, but a dotted name cannot be a key in `GlobalComponents`, so it gets no editor typing. Prefer `<VDrawerItem>` / `<VDrawerSection>` in `lang="ts"` SFCs. |

`KeepAlive` is deliberately absent from Vue Native's own augmentation because `@vue/runtime-core` already declares it — the runtime re-exports Vue's `KeepAlive` unchanged.

[`<VNavigationBar>`](../components/VNavigationBar.md) is the one documented component that is *not* globally registered: it lives in `@thelacanians/vue-native-navigation`, so import it from that package.

## Platform-only components

Three components exist for macOS window chrome and render nothing elsewhere. Guard them with [`usePlatform()`](../composables/usePlatform.md) if you share screens across targets:

```vue
<script setup>
import { usePlatform } from '@thelacanians/vue-native-runtime'

const { isMacOS } = usePlatform()
</script>

<template>
  <VToolbar v-if="isMacOS" :items="toolbarItems" @itemClick="onToolbarItem" />
  <VView v-else :style="{ flex: 1 }">
    <!-- mobile header -->
  </VView>
</template>
```

In development builds, mounting `VToolbar`, `VSplitView`, or `VOutlineView` on iOS or Android logs a console warning telling you the component renders nothing on that platform.
