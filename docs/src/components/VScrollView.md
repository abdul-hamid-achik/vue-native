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

Use the `refreshing` prop and `@refresh` event for pull-to-refresh.

::: warning Mobile only
Pull-to-refresh is implemented on iOS and Android. On macOS `VScrollView`
accepts `refreshing` and `@refresh` but neither does anything — the event never
fires — and a debug build logs a warning telling you so. There is no
pull-to-refresh gesture on desktop; render an explicit refresh control (a
`VButton` in a header, for example) and gate it with `usePlatform()` if you need
one on macOS.
:::

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
| `scrollEventThrottle` | `Number` | `16` | Minimum interval in milliseconds between scroll events. Lower values give more frequent updates but may impact performance. |
| `style` | `Object` | — | Style for the scroll view |
| `accessibilityLabel` | `string` | — | A text label for assistive technologies |
| `accessibilityRole` | `string` | — | The accessibility role (e.g. `'scrollbar'`) |
| `accessibilityHint` | `string` | — | Describes what happens when the user interacts with the element |
| `accessibilityState` | `Object` | — | Accessibility state object |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `scroll` | `{ x, y, contentWidth, contentHeight, layoutWidth, layoutHeight }` | Fired on scroll with current offset and content/layout dimensions |
| `refresh` | — | Fired when the user pulls to refresh. iOS and Android only; never fires on macOS |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS      | Full (`UIScrollView`) |
| Android  | Full (`ScrollView`) |
| macOS    | Scrolling is full (`NSScrollView`; children are added to its document view, an `NSClipView`-hosted `FlippedView`). Pull-to-refresh is **not** supported: `refreshing` and `@refresh` are accepted and ignored, with a debug-build warning. |
