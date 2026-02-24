# VSectionList

A high-performance, virtualized list with grouped sections. Backed by `UITableView` with sections on iOS and a sectioned `RecyclerView` adapter on Android.

Use named slots to render section headers, items, and footers. Like `VList`, rows are recycled for optimal memory usage.

## Usage

```vue
<VSectionList
  :sections="[
    { title: 'Fruits', data: ['Apple', 'Banana', 'Cherry'] },
    { title: 'Vegetables', data: ['Carrot', 'Broccoli'] },
  ]"
  :estimatedItemHeight="44"
>
  <template #sectionHeader="{ section }">
    <VText :style="{ fontWeight: '700', padding: 8 }">{{ section.title }}</VText>
  </template>
  <template #item="{ item }">
    <VText :style="{ padding: 12 }">{{ item }}</VText>
  </template>
</VSectionList>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `sections` | `Section[]` | **(required)** | Array of section objects containing a title and data array |
| `keyExtractor` | `Function` | index-based | `(item, index) => string` — unique key for each item |
| `estimatedItemHeight` | `Number` | `44` | Estimated row height in points, used for scroll calculations |
| `stickySectionHeaders` | `Boolean` | `true` | Whether section headers stick to the top while scrolling |
| `showsScrollIndicator` | `Boolean` | `true` | Shows the vertical scroll indicator |
| `bounces` | `Boolean` | `true` | Enables bounce effect at scroll edges (iOS) |
| `style` | `Object` | `{}` | Layout + appearance styles for the outer container |

### Section

```ts
interface Section {
  title: string
  data: any[]
}
```

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `scroll` | `{ contentOffset: { x: number, y: number } }` | Emitted continuously while the user scrolls |
| `endReached` | -- | Emitted when the user scrolls near the end of the list |

## Slots

| Slot | Scoped Props | Description |
|------|-------------|-------------|
| `#sectionHeader` | `{ section, index }` | Rendered at the top of each section |
| `#item` | `{ item, index, section }` | Rendered for each item in a section |
| `#sectionFooter` | `{ section, index }` | Rendered at the bottom of each section |
| `#header` | -- | Rendered once at the very top of the list |
| `#footer` | -- | Rendered once at the very bottom of the list |
| `#empty` | -- | Rendered when `sections` is empty or all sections have empty `data` |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const contacts = ref([
  {
    title: 'A',
    data: [
      { id: '1', name: 'Alice', phone: '555-0101' },
      { id: '2', name: 'Andrew', phone: '555-0102' },
    ],
  },
  {
    title: 'B',
    data: [
      { id: '3', name: 'Bob', phone: '555-0201' },
      { id: '4', name: 'Beth', phone: '555-0202' },
      { id: '5', name: 'Brian', phone: '555-0203' },
    ],
  },
  {
    title: 'C',
    data: [
      { id: '6', name: 'Carol', phone: '555-0301' },
    ],
  },
])

function onEndReached() {
  console.log('Load more contacts...')
}
</script>

<template>
  <VView :style="{ flex: 1 }">
    <VText :style="{ fontSize: 24, fontWeight: '700', padding: 16 }">
      Contacts
    </VText>

    <VSectionList
      :sections="contacts"
      :keyExtractor="(item) => item.id"
      :estimatedItemHeight="60"
      :stickySectionHeaders="true"
      :style="{ flex: 1 }"
      @endReached="onEndReached"
    >
      <template #sectionHeader="{ section }">
        <VView :style="{ backgroundColor: '#f0f0f0', paddingHorizontal: 16, paddingVertical: 6 }">
          <VText :style="{ fontSize: 14, fontWeight: '600', color: '#888' }">
            {{ section.title }}
          </VText>
        </VView>
      </template>

      <template #item="{ item }">
        <VPressable
          :style="{ paddingHorizontal: 16, paddingVertical: 12, borderBottomWidth: 0.5, borderBottomColor: '#e0e0e0' }"
          :onPress="() => console.log('Tapped', item.name)"
        >
          <VText :style="{ fontSize: 16, fontWeight: '500' }">{{ item.name }}</VText>
          <VText :style="{ fontSize: 13, color: '#888', marginTop: 2 }">{{ item.phone }}</VText>
        </VPressable>
      </template>

      <template #empty>
        <VView :style="{ padding: 40, alignItems: 'center' }">
          <VText :style="{ color: '#999' }">No contacts found</VText>
        </VView>
      </template>
    </VSectionList>
  </VView>
</template>
```
