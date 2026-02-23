# VList

A virtualized scrollable list backed by `UITableView` on iOS and `RecyclerView` on Android. Efficient for large datasets — only visible rows are rendered.

## Usage

VList uses a `:data` prop and an `#item` slot to render each row. Do **not** use `v-for` inside VList — the native virtualization engine manages which rows are rendered.

```vue
<script setup>
import { ref } from '@thelacanians/runtime'

const items = ref([
  { id: 1, title: 'Item 1' },
  { id: 2, title: 'Item 2' },
  { id: 3, title: 'Item 3' },
])
</script>

<template>
  <VList
    :data="items"
    :keyExtractor="item => item.id"
    :style="{ flex: 1 }"
  >
    <template #item="{ item }">
      <VView :style="{ padding: 16, borderBottomWidth: 1, borderBottomColor: '#eee' }">
        <VText>{{ item.title }}</VText>
      </VView>
    </template>
  </VList>
</template>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `data` | `Array` | **required** | The array of items to render |
| `keyExtractor` | `(item: T) => string \| number` | — | Function that returns a unique key for each item |
| `style` | `StyleProp` | — | Container styles |
| `estimatedItemHeight` | `number` | `44` | Estimated row height (improves scroll perf) |
| `showsScrollIndicator` | `boolean` | `true` | Show/hide the scroll bar |
| `bounces` | `boolean` | `true` | Bounce at top/bottom (iOS only) |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@scroll` | `{ x: number, y: number }` | Fires as the user scrolls |
| `@endReached` | — | Fires when scrolled near the bottom (20% threshold). Use this for infinite scroll / pagination |

## Infinite scroll example

```vue
<script setup>
import { ref } from '@thelacanians/runtime'

const items = ref(Array.from({ length: 20 }, (_, i) => ({ id: i + 1 })))
const loading = ref(false)

async function loadMore() {
  if (loading.value) return
  loading.value = true
  // fetch more items…
  items.value.push(...newItems)
  loading.value = false
}
</script>

<template>
  <VList
    :data="items"
    :keyExtractor="item => item.id"
    :style="{ flex: 1 }"
    @endReached="loadMore"
  >
    <template #item="{ item }">
      <VView :style="{ padding: 16 }">
        <VText>Item {{ item.id }}</VText>
      </VView>
    </template>
  </VList>
  <VActivityIndicator v-if="loading" />
</template>
```

::: tip Performance
Set `estimatedItemHeight` close to your actual row height. This prevents layout jumps when the list first renders.
:::
