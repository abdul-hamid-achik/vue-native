# VRefreshControl

A pull-to-refresh indicator component. Designed to be used as a child of `VScrollView` or `VList`. When the user pulls down past the scroll boundary, the `onRefresh` callback fires.

On iOS this attaches a `UIRefreshControl` to the parent `UIScrollView`. On Android this configures the parent `SwipeRefreshLayout`.

## Usage

```vue
<VScrollView :style="{ flex: 1 }">
  <VRefreshControl
    :refreshing="isLoading"
    :onRefresh="handleRefresh"
    tintColor="#007AFF"
  />
  <VText>Content here</VText>
</VScrollView>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `refreshing` | `boolean` | `false` | Whether the refresh indicator is currently active. Set to `true` while loading, then `false` when done. |
| `onRefresh` | `Function` | -- | Callback fired when the user triggers a pull-to-refresh |
| `tintColor` | `string` | system default | Color of the spinner indicator |
| `title` | `string` | -- | Title text shown below the spinner (iOS only) |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'

const items = ref(['Item 1', 'Item 2', 'Item 3'])
const isLoading = ref(false)

async function handleRefresh() {
  isLoading.value = true
  // Simulate a network request
  await new Promise(resolve => setTimeout(resolve, 2000))
  items.value = ['Refreshed 1', 'Refreshed 2', 'Refreshed 3']
  isLoading.value = false
}
</script>

<template>
  <VScrollView :style="{ flex: 1 }">
    <VRefreshControl
      :refreshing="isLoading"
      :onRefresh="handleRefresh"
      tintColor="#34C759"
      title="Pull to refresh"
    />
    <VView v-for="(item, i) in items" :key="i" :style="{ padding: 16 }">
      <VText>{{ item }}</VText>
    </VView>
  </VScrollView>
</template>
```

## Notes

- `VRefreshControl` must be a direct child of `VScrollView` or `VList` for the native refresh control to attach properly.
- Set `refreshing` back to `false` in your refresh callback when loading is complete. The spinner will not dismiss automatically.
- The `title` prop is iOS-only and displays a short message beneath the spinner.
- On Android, the tint color affects the animated arrow and spinner.
