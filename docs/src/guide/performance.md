# Performance

This guide covers performance best practices for Vue Native apps and how to use the built-in profiler to identify bottlenecks.

## Performance Profiler

Vue Native includes a native performance profiler that tracks FPS, memory usage, and bridge operation counts in real time.

### Quick Start

```vue
<script setup>
import { usePerformance } from '@thelacanians/vue-native-runtime'

const { startProfiling, stopProfiling, fps, memoryMB, bridgeOps, isProfiling } = usePerformance()
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VButton :onPress="isProfiling ? stopProfiling : startProfiling">
      <VText>{{ isProfiling ? 'Stop Profiler' : 'Start Profiler' }}</VText>
    </VButton>

    <VView v-if="isProfiling" :style="{ padding: 10, backgroundColor: '#1a1a2e', borderRadius: 8, marginTop: 10 }">
      <VText :style="{ color: fps < 30 ? '#e74c3c' : fps < 55 ? '#f39c12' : '#2ecc71', fontSize: 16 }">
        FPS: {{ fps }}
      </VText>
      <VText :style="{ color: '#ecf0f1', fontSize: 14 }">Memory: {{ memoryMB.toFixed(1) }} MB</VText>
      <VText :style="{ color: '#ecf0f1', fontSize: 14 }">Bridge Ops: {{ bridgeOps }}</VText>
    </VView>
  </VView>
</template>
```

### One-Time Snapshot

For non-reactive metrics, use `getMetrics()`:

```ts
const { getMetrics } = usePerformance()

const snapshot = await getMetrics()
console.log(`FPS: ${snapshot.fps}, Memory: ${snapshot.memoryMB} MB`)
```

## Best Practices

### 1. Minimize Bridge Operations

Every JS-to-native call has overhead. Batch operations where possible.

```ts
// Avoid: many individual style updates
style.backgroundColor = 'red'
style.borderRadius = 8
style.padding = 10

// Prefer: single style object
const style = { backgroundColor: 'red', borderRadius: 8, padding: 10 }
```

Vue Native already batches bridge operations per microtask cycle, but reducing the number of reactive updates helps.

### 2. Use `VList` for Long Lists

`VList` uses native `UITableView`/`RecyclerView` for virtualized rendering. Only visible items are rendered.

```vue
<VList
  :data="items"
  :renderItem="renderItem"
  :keyExtractor="(item) => item.id"
/>
```

Never render long lists with `v-for` inside `VScrollView` -- this creates all views upfront and causes memory issues.

### 3. Avoid Unnecessary Re-renders

Use `computed` for derived state and `shallowRef` for objects that don't need deep reactivity:

```ts
import { shallowRef, computed } from '@thelacanians/vue-native-runtime'

// Good: only triggers when the reference changes
const user = shallowRef({ name: 'Alice', avatar: 'url' })

// Good: computed caches the result
const fullName = computed(() => `${user.value.firstName} ${user.value.lastName}`)
```

### 4. Optimize Images

- Use appropriately sized images for the display size
- Prefer `resizeMode: 'cover'` or `'contain'` over `'stretch'`
- Consider lazy-loading images in lists

### 5. Minimize Layout Passes

Yoga (the layout engine) recalculates layout when style properties change. Avoid frequent style changes that affect layout (width, height, padding, margin, flex).

```ts
// Avoid: changing layout properties in rapid succession
// This triggers multiple layout passes

// Prefer: use transform for animations (doesn't trigger layout)
await timing(viewId, { translateX: 100 }, { duration: 300 })
```

### 6. Use `unmountInactiveScreens`

For apps with many screens, enable `unmountInactiveScreens` to free memory from screens that aren't visible:

```ts
const router = createRouter({
  routes: [...],
  unmountInactiveScreens: true,
})
```

### 7. Profile Before Optimizing

Always measure before optimizing. Use the profiler to identify actual bottlenecks:

1. Start the profiler on the screen you want to test
2. Perform the interactions you want to measure
3. Watch for FPS drops below 60
4. Check memory growth over time
5. Monitor bridge operation spikes

### Reading the Metrics

| Metric | Good | Warning | Problem |
|--------|------|---------|---------|
| FPS | 55-60 | 30-55 | < 30 |
| Memory | Stable | Gradual growth | Rapid growth |
| Bridge Ops | Low, steady | Spikes during interaction | Constant high volume |

## Common Performance Issues

### FPS drops during scrolling
- Use `VList` instead of `v-for` + `VScrollView`
- Reduce the complexity of list item components
- Avoid inline function allocation in list item render functions

### High memory usage
- Enable `unmountInactiveScreens` in the router
- Use appropriately sized images
- Check for retained references in closures

### Slow initial load
- Reduce the number of components rendered on the initial screen
- Defer non-critical data fetching
- Use lazy tab loading with `lazy: true` in tab screens

## Profiler API Reference

See the [usePerformance composable documentation](/composables/usePerformance.md) for the full API reference.
