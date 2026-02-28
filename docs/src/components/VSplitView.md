# VSplitView

A resizable split-pane container for macOS. Maps to `NSSplitView` and supports horizontal (side-by-side) or vertical (top-and-bottom) arrangements with a draggable divider.

> **Platform:** macOS only

## Usage

```vue
<script setup lang="ts">
function onResize(e: { positions: number[] }) {
  console.log('Divider positions:', e.positions)
}
</script>

<template>
  <VSplitView
    direction="horizontal"
    dividerStyle="thin"
    :dividerPosition="260"
    :style="{ flex: 1 }"
    @resize="onResize"
  >
    <VView :style="{ flex: 1, padding: 16 }">
      <VText>Sidebar</VText>
    </VView>
    <VView :style="{ flex: 1, padding: 16 }">
      <VText>Main Content</VText>
    </VView>
  </VSplitView>
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `direction` | `'horizontal' \| 'vertical'` | `'horizontal'` | `'horizontal'` places panes side-by-side; `'vertical'` stacks them top-and-bottom |
| `dividerStyle` | `'thin' \| 'thick' \| 'paneSplitter'` | `'thin'` | Visual style of the divider handle |
| `dividerColor` | `string` | system default | Hex color string for the divider (e.g. `'#AAAAAA'`) |
| `dividerPosition` | `number` | — | Initial position of the first divider in points, measured from the leading/top edge |
| `style` | `StyleProp` | — | Layout and appearance styles for the split view container |

### `direction` vs. `NSSplitView.isVertical`

The `direction` prop uses intuitive naming. Internally it maps to `NSSplitView.isVertical` with the opposite polarity:

| `direction` prop | `NSSplitView.isVertical` | Result |
|------------------|--------------------------|--------|
| `"horizontal"` | `true` | Panes sit side-by-side (left / right) |
| `"vertical"` | `false` | Panes stack top-and-bottom |

### `dividerStyle` values

| Value | Appearance |
|-------|------------|
| `"thin"` | Hairline divider, no visible drag handle |
| `"thick"` | Wide divider with an embossed handle |
| `"paneSplitter"` | Full-height/width panel-splitter appearance (e.g. Finder sidebar) |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@resize` | `{ positions: number[] }` | Fired whenever the user drags a divider. `positions` is an array of divider offsets in points from the leading/top edge of the split view. For a two-pane split there is one position; for three panes there are two. |

## Examples

### Sidebar layout

A classic macOS sidebar — fixed initial width with a draggable divider.

```vue
<script setup lang="ts">
import { ref } from '@thelacanians/vue-native-runtime'

const sidebarWidth = ref(240)

function onResize(e: { positions: number[] }) {
  sidebarWidth.value = e.positions[0]
}
</script>

<template>
  <VSplitView
    direction="horizontal"
    dividerStyle="paneSplitter"
    :dividerPosition="sidebarWidth"
    :style="{ flex: 1 }"
    @resize="onResize"
  >
    <!-- Sidebar -->
    <VView :style="{ flex: 1, backgroundColor: '#F5F5F5', padding: 12 }">
      <VText :style="{ fontWeight: '600', marginBottom: 8 }">Navigation</VText>
      <VText>Inbox</VText>
      <VText>Sent</VText>
      <VText>Drafts</VText>
    </VView>

    <!-- Detail -->
    <VView :style="{ flex: 1, padding: 24 }">
      <VText :style="{ fontSize: 20, fontWeight: '700' }">Select a message</VText>
    </VView>
  </VSplitView>
</template>
```

### Three-pane layout

Add a third child to create a three-pane split. The `@resize` payload will contain two positions.

```vue
<script setup lang="ts">
function onResize(e: { positions: number[] }) {
  const [firstDivider, secondDivider] = e.positions
  console.log('Left pane width:', firstDivider)
  console.log('Middle pane width:', secondDivider - firstDivider)
}
</script>

<template>
  <VSplitView
    direction="horizontal"
    dividerStyle="thin"
    :style="{ flex: 1 }"
    @resize="onResize"
  >
    <VView :style="{ flex: 1, padding: 16 }">
      <VText>Left</VText>
    </VView>
    <VView :style="{ flex: 2, padding: 16 }">
      <VText>Middle</VText>
    </VView>
    <VView :style="{ flex: 1, padding: 16 }">
      <VText>Right</VText>
    </VView>
  </VSplitView>
</template>
```

### Vertical (top-and-bottom) split

```vue
<template>
  <VSplitView
    direction="vertical"
    dividerStyle="thick"
    :dividerPosition="300"
    :style="{ flex: 1 }"
  >
    <VView :style="{ flex: 1, padding: 16 }">
      <VText>Editor</VText>
    </VView>
    <VView :style="{ flex: 1, padding: 16, backgroundColor: '#1E1E1E' }">
      <VText :style="{ color: '#D4D4D4', fontFamily: 'Menlo' }">Console output…</VText>
    </VView>
  </VSplitView>
</template>
```

### Custom divider color

```vue
<template>
  <VSplitView
    direction="horizontal"
    dividerColor="#0078D4"
    dividerStyle="thin"
    :style="{ flex: 1 }"
  >
    <VView :style="{ flex: 1, padding: 16 }">
      <VText>Left Pane</VText>
    </VView>
    <VView :style="{ flex: 1, padding: 16 }">
      <VText>Right Pane</VText>
    </VView>
  </VSplitView>
</template>
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS      | No-op   |
| Android  | No-op   |
| macOS    | Full    |

## Notes

- Direct children of `VSplitView` become the arranged subviews of the underlying `NSSplitView`. Each child fills one pane.
- `dividerPosition` sets the position of the **first** divider only. For three-pane layouts the second divider is positioned by `NSSplitView` according to each pane's natural size.
- Do not mix AutoLayout constraints with Yoga layout inside the same `VSplitView` hierarchy. `VSplitView` manages its children through `NSSplitView`'s `addArrangedSubview` / `insertArrangedSubview` APIs and runs Yoga on each pane independently.
- The `@resize` event fires on every drag update, not just on release. Debounce or throttle the handler if you are persisting pane sizes to storage.
- `dividerColor` accepts any hex string that the runtime's `NSColor.fromHex()` extension understands (e.g. `'#RGB'`, `'#RRGGBB'`, `'#RRGGBBAA'`).
