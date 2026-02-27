# VFlatList

A high-performance virtualized list for large datasets. Unlike VList (which uses native `UITableView` / `RecyclerView`), VFlatList only creates native views for items currently visible on screen plus a configurable buffer -- reducing memory usage from O(n) to O(visible).

Uses VScrollView internally with absolutely-positioned items. The scroll position drives which items are mounted.

## Usage

VFlatList uses a `:data` prop and an `#item` slot to render each row. Every item must have a fixed height specified via the `itemHeight` prop.

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const items = ref(
  Array.from({ length: 10000 }, (_, i) => ({ id: i + 1, title: `Item ${i + 1}` }))
)
</script>

<template>
  <VFlatList
    :data="items"
    :itemHeight="52"
    :keyExtractor="item => item.id"
    :style="{ flex: 1 }"
  >
    <template #item="{ item }">
      <VView :style="{ padding: 16, borderBottomWidth: 1, borderBottomColor: '#eee' }">
        <VText>{{ item.title }}</VText>
      </VView>
    </template>
  </VFlatList>
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `data` | `Array` | **required** | The array of items to render |
| `itemHeight` | `number` | **required** | Fixed height (in points) for each item. Required for virtualization math. |
| `keyExtractor` | `(item: T, index: number) => string \| number` | `item.id ?? item.key ?? index` | Function that returns a unique key for each item |
| `renderItem` | `(info: { item: T, index: number }) => VNode` | -- | Render function alternative to the `#item` slot |
| `windowSize` | `number` | `3` | Number of viewport-heights to render above and below the visible area. Higher values reduce blank flashes during fast scrolling but use more memory. |
| `style` | `ViewStyle` | `{}` | Styles for the outer scroll container |
| `showsScrollIndicator` | `boolean` | `true` | Show/hide the vertical scroll indicator |
| `bounces` | `boolean` | `true` | Bounce at scroll boundaries (iOS only) |
| `headerHeight` | `number` | `0` | Height in points of the `#header` slot content. Required for correct virtualization math when using a header. |
| `endReachedThreshold` | `number` | `0.5` | How far from the end (in viewport fractions) to trigger `@endReached`. 0.5 = trigger when within 50% of a viewport from the bottom. |

## Slots

| Slot | Props | Description |
|------|-------|-------------|
| `#item` | `{ item, index }` | Render each list item. Required unless `renderItem` prop is used. |
| `#header` | -- | Content rendered above the list items |
| `#empty` | -- | Content shown when `data` is an empty array |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@scroll` | `{ x, y, contentWidth, contentHeight, layoutWidth, layoutHeight }` | Fires as the user scrolls |
| `@endReached` | -- | Fires when scrolled near the bottom (controlled by `endReachedThreshold`). Use for infinite scroll / pagination. |

## Infinite scroll example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const items = ref(Array.from({ length: 50 }, (_, i) => ({ id: i + 1, title: `Item ${i + 1}` })))
const loading = ref(false)

async function loadMore() {
  if (loading.value) return
  loading.value = true
  const start = items.value.length
  const more = Array.from({ length: 20 }, (_, i) => ({
    id: start + i + 1,
    title: `Item ${start + i + 1}`,
  }))
  items.value = [...items.value, ...more]
  loading.value = false
}
</script>

<template>
  <VFlatList
    :data="items"
    :itemHeight="52"
    :keyExtractor="item => item.id"
    :style="{ flex: 1 }"
    @endReached="loadMore"
  >
    <template #item="{ item }">
      <VView :style="{ padding: 16 }">
        <VText>{{ item.title }}</VText>
      </VView>
    </template>
  </VFlatList>
</template>
```

## Header and empty state

```vue
<template>
  <VFlatList
    :data="items"
    :itemHeight="52"
    :keyExtractor="item => item.id"
    :style="{ flex: 1 }"
  >
    <template #header>
      <VView :style="{ padding: 16 }">
        <VText :style="{ fontSize: 24, fontWeight: 'bold' }">My Items</VText>
      </VView>
    </template>

    <template #item="{ item }">
      <VView :style="{ padding: 16 }">
        <VText>{{ item.title }}</VText>
      </VView>
    </template>

    <template #empty>
      <VView :style="{ padding: 40, alignItems: 'center' }">
        <VText :style="{ color: '#999' }">No items yet</VText>
      </VView>
    </template>
  </VFlatList>
</template>
```

## Using renderItem prop

For programmatic rendering, use the `renderItem` prop instead of the `#item` slot:

```vue
<script setup>
import { h } from '@thelacanians/vue-native-runtime'

const data = Array.from({ length: 10000 }, (_, i) => ({ id: i, title: `Item ${i}` }))

function renderItem({ item, index }) {
  return h('VView', { style: { padding: 16 } }, [
    h('VText', {}, `${item.title}`),
  ])
}
</script>

<template>
  <VFlatList
    :data="data"
    :renderItem="renderItem"
    :itemHeight="52"
    :style="{ flex: 1 }"
  />
</template>
```

## VList vs VFlatList

| | VList | VFlatList |
|---|---|---|
| **Backing** | Native `UITableView` / `RecyclerView` | JS-side virtualization over `VScrollView` |
| **Item height** | Variable (estimated via `estimatedItemHeight`) | Fixed (required `itemHeight` prop) |
| **Best for** | Small-to-medium lists, variable row heights | Very large datasets (1000+ items), fixed row heights |
| **Memory** | Native cell reuse | Only visible + buffer items mounted |

::: tip Performance
Set `itemHeight` to the exact pixel height of your rows. VFlatList uses this value for all scroll position math -- an incorrect value will cause items to appear at wrong positions.
:::

::: tip windowSize
The default `windowSize` of 3 means 3 viewports above + 3 viewports below the visible area are rendered (7 total viewports of items). Increase this if you see blank flashes during fast scrolling, or decrease it to save memory.
:::
