# VOutlineView

A tree-structured list component for macOS. Maps to `NSOutlineView` wrapped in an `NSScrollView`, supporting unlimited nesting, expand/collapse, and single or multiple selection.

> **Platform:** macOS only

## Usage

```vue
<script setup lang="ts">
import { ref } from '@thelacanians/vue-native-runtime'

const treeData = ref([
  {
    id: 'src',
    label: 'src',
    children: [
      { id: 'main', label: 'main.ts' },
      { id: 'app',  label: 'App.vue' },
      {
        id: 'components',
        label: 'components',
        children: [
          { id: 'header', label: 'Header.vue' },
          { id: 'footer', label: 'Footer.vue' },
        ],
      },
    ],
  },
  { id: 'package', label: 'package.json' },
])

function onSelect(e: { id: string; label: string }) {
  console.log('Selected:', e.label)
}
</script>

<template>
  <VOutlineView
    :data="treeData"
    selectionMode="single"
    :expandAll="false"
    :style="{ flex: 1 }"
    @select="onSelect"
  />
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `data` | `OutlineNode[]` | **required** | The tree data to display. Each node may have a `children` array for nested items. |
| `expandAll` | `boolean` | `false` | When `true`, all nodes with children are expanded. When set back to `false`, all nodes are collapsed. |
| `selectionMode` | `'single' \| 'multiple' \| 'none'` | `'single'` | Controls how many rows can be selected at once. |
| `style` | `StyleProp` | — | Layout and appearance styles applied to the scroll view container. |

### OutlineNode

```ts
interface OutlineNode {
  id: string           // Unique identifier for the node
  label: string        // Text displayed in the row
  children?: OutlineNode[]  // Nested child nodes; omit or leave empty for leaf nodes
}
```

- Nodes without `children` (or with an empty `children` array) are leaf nodes and cannot be expanded.
- The `id` field is returned in all events and must be unique across the entire tree.

### `selectionMode` values

| Value | Behaviour |
|-------|-----------|
| `"single"` | One row can be selected at a time. Selection is highlighted with `NSTableView`'s regular style. |
| `"multiple"` | Multiple rows can be selected by holding Shift or Command. |
| `"none"` | Rows cannot be selected. No highlight is shown. |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@select` | `{ id: string; label: string }` | Fired when a row becomes selected. `id` and `label` match the selected node's data. |
| `@expand` | `{ id: string }` | Fired after a node with children is expanded (disclosure triangle opened). |
| `@collapse` | `{ id: string }` | Fired after a node with children is collapsed (disclosure triangle closed). |

::: tip
`@select` fires only when a row is selected (including via keyboard navigation). It does not fire on deselection in `selectionMode="multiple"`.
:::

## Examples

### File tree with expand/collapse tracking

```vue
<script setup lang="ts">
import { ref } from '@thelacanians/vue-native-runtime'

const files = ref([
  {
    id: 'packages',
    label: 'packages',
    children: [
      {
        id: 'runtime',
        label: 'runtime',
        children: [
          { id: 'runtime-src', label: 'src' },
          { id: 'runtime-pkg', label: 'package.json' },
        ],
      },
      {
        id: 'cli',
        label: 'cli',
        children: [
          { id: 'cli-src', label: 'src' },
          { id: 'cli-pkg', label: 'package.json' },
        ],
      },
    ],
  },
  { id: 'turbo', label: 'turbo.json' },
  { id: 'root-pkg', label: 'package.json' },
])

const expandedIds = ref<Set<string>>(new Set())
const selectedNode = ref<{ id: string; label: string } | null>(null)

function onSelect(e: { id: string; label: string }) {
  selectedNode.value = e
}

function onExpand(e: { id: string }) {
  expandedIds.value.add(e.id)
}

function onCollapse(e: { id: string }) {
  expandedIds.value.delete(e.id)
}
</script>

<template>
  <VView :style="{ flex: 1 }">
    <VText :style="{ padding: 8, fontSize: 12, color: '#666' }">
      Selected: {{ selectedNode?.label ?? 'none' }}
    </VText>
    <VOutlineView
      :data="files"
      selectionMode="single"
      :style="{ flex: 1 }"
      @select="onSelect"
      @expand="onExpand"
      @collapse="onCollapse"
    />
  </VView>
</template>
```

### Expand all by default

```vue
<script setup lang="ts">
const categories = [
  {
    id: 'fruit',
    label: 'Fruit',
    children: [
      { id: 'apple',  label: 'Apple' },
      { id: 'banana', label: 'Banana' },
      { id: 'cherry', label: 'Cherry' },
    ],
  },
  {
    id: 'vegetables',
    label: 'Vegetables',
    children: [
      { id: 'carrot',  label: 'Carrot' },
      { id: 'spinach', label: 'Spinach' },
    ],
  },
]
</script>

<template>
  <VOutlineView
    :data="categories"
    :expandAll="true"
    selectionMode="single"
    :style="{ flex: 1 }"
    @select="e => console.log('Picked:', e.label)"
  />
</template>
```

### Multiple selection

```vue
<script setup lang="ts">
import { ref } from '@thelacanians/vue-native-runtime'

const lastSelected = ref('')

const permissions = [
  {
    id: 'read',
    label: 'Read',
    children: [
      { id: 'read-files',   label: 'Files' },
      { id: 'read-network', label: 'Network' },
    ],
  },
  {
    id: 'write',
    label: 'Write',
    children: [
      { id: 'write-files',   label: 'Files' },
      { id: 'write-network', label: 'Network' },
    ],
  },
]
</script>

<template>
  <VOutlineView
    :data="permissions"
    selectionMode="multiple"
    :expandAll="true"
    :style="{ flex: 1 }"
    @select="e => lastSelected = e.label"
  />
</template>
```

### Read-only tree (no selection)

```vue
<template>
  <VOutlineView
    :data="dependencyTree"
    selectionMode="none"
    :expandAll="true"
    :style="{ flex: 1 }"
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

- The component renders as an `NSScrollView` with a vertical scroller. The scroller autohides when not in use. Horizontal scrolling is disabled; long labels are clipped.
- Each row displays only the node's `label` text. Custom cell rendering (icons, badges, etc.) is not yet supported — all styling must come from the native `NSTableCellView` defaults.
- The `@select` event fires when `NSOutlineView`'s selection changes, which includes both mouse clicks and keyboard navigation (arrow keys, Return). It reports only the most-recently-selected row, even in `selectionMode="multiple"`.
- Setting `expandAll` from `true` to `false` collapses all nodes immediately. Setting it back to `true` after a `data` update re-expands the entire tree.
- `id` values must be unique across the entire tree. Duplicate `id`s will cause unpredictable event payloads.
- Updating `data` triggers a full `reloadData()` on the underlying `NSOutlineView`. If `expandAll` is `true`, all items are expanded again after reload. Individual expand states are not preserved across data updates.
