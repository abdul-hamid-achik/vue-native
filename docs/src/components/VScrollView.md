# VScrollView

A scrollable container component. Maps to `UIScrollView` on iOS and `ScrollView` on Android.

## Usage

```vue
<template>
  <VScrollView :style="{ flex: 1 }" @scroll="onScroll">
    <VView v-for="item in items" :key="item.id" :style="styles.row">
      <VText>{{ item.title }}</VText>
    </VView>
  </VScrollView>
</template>
```

### Horizontal Scrolling

```vue
<VScrollView :horizontal="true" :style="{ height: 200 }">
  <VView v-for="card in cards" :key="card.id" :style="styles.card">
    <VText>{{ card.title }}</VText>
  </VView>
</VScrollView>
```

### Pull to Refresh

Use the `refreshing` prop and `@refresh` event for pull-to-refresh:

```vue
<template>
  <VScrollView
    :style="{ flex: 1 }"
    :refreshing="isRefreshing"
    @refresh="onRefresh"
  >
    <VText v-for="item in items" :key="item.id">{{ item.title }}</VText>
  </VScrollView>
</template>

<script setup>
import { ref } from 'vue-native'

const isRefreshing = ref(false)
const items = ref([/* ... */])

async function onRefresh() {
  isRefreshing.value = true
  items.value = await fetchItems()
  isRefreshing.value = false
}
</script>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `horizontal` | `Boolean` | `false` | Scroll horizontally instead of vertically |
| `showsVerticalScrollIndicator` | `Boolean` | `true` | Show vertical scroll indicator |
| `showsHorizontalScrollIndicator` | `Boolean` | `false` | Show horizontal scroll indicator |
| `scrollEnabled` | `Boolean` | `true` | Enable/disable scrolling |
| `bounces` | `Boolean` | `true` | Enable bounce at scroll boundaries |
| `pagingEnabled` | `Boolean` | `false` | Snap to pages when scrolling |
| `refreshing` | `Boolean` | `false` | Whether the pull-to-refresh indicator is active |
| `contentContainerStyle` | `Object` | — | Style for the inner content container |
| `style` | `Object` | — | Style for the scroll view |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `scroll` | `{ x: number, y: number }` | Fired on scroll with current offset |
| `refresh` | — | Fired when the user pulls to refresh |
