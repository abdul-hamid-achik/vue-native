# usePerformance

Performance profiler composable that tracks FPS, memory usage, and bridge operation count. Backed by native `CADisplayLink` on iOS and `Choreographer` on Android.

## Usage

```vue
<script setup>
import { usePerformance } from '@thelacanians/vue-native-runtime'

const {
  startProfiling,
  stopProfiling,
  fps,
  memoryMB,
  bridgeOps,
  isProfiling,
} = usePerformance()
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VButton :onPress="isProfiling ? stopProfiling : startProfiling">
      <VText>{{ isProfiling ? 'Stop' : 'Start' }} Profiling</VText>
    </VButton>

    <VView v-if="isProfiling" :style="{ marginTop: 20 }">
      <VText>FPS: {{ fps }}</VText>
      <VText>Memory: {{ memoryMB.toFixed(1) }} MB</VText>
      <VText>Bridge Ops: {{ bridgeOps }}</VText>
    </VView>
  </VView>
</template>
```

## API

```ts
usePerformance(): {
  startProfiling: () => Promise<void>
  stopProfiling: () => Promise<void>
  getMetrics: () => Promise<PerformanceMetrics>
  isProfiling: Ref<boolean>
  fps: Ref<number>
  memoryMB: Ref<number>
  bridgeOps: Ref<number>
}
```

### Methods

#### `startProfiling()`

Start the native performance profiler. Begins tracking FPS, memory, and bridge operations. Metrics are pushed to the reactive refs every 1 second via native events.

#### `stopProfiling()`

Stop the profiler and unsubscribe from metrics events. The reactive refs retain their last values.

#### `getMetrics()`

Request a one-time snapshot of current metrics from the native side. Returns a `PerformanceMetrics` object.

### Reactive Refs

| Ref | Type | Description |
|-----|------|-------------|
| `isProfiling` | `Ref<boolean>` | Whether the profiler is currently active. |
| `fps` | `Ref<number>` | Current frames per second (updated every 1s). |
| `memoryMB` | `Ref<number>` | Current memory usage in megabytes. |
| `bridgeOps` | `Ref<number>` | Total bridge operations since profiling started. |

### Types

```ts
interface PerformanceMetrics {
  fps: number
  memoryMB: number
  bridgeOps: number
  timestamp: number
}
```

## How It Works

### iOS
- **FPS**: Measured via `CADisplayLink` attached to the main run loop. Frame count is sampled every 0.5 seconds for smooth readings.
- **Memory**: Uses `task_info` with `MACH_TASK_BASIC_INFO` to get `resident_size` in bytes, converted to MB.
- **Metrics dispatch**: A `Timer` fires every 1 second, collecting metrics and dispatching a `perf:metrics` global event to JS.

### Android
- **FPS**: Measured via `Choreographer.FrameCallback`. Frame count is sampled every 0.5 seconds.
- **Memory**: Uses `Runtime.getRuntime()` to calculate `totalMemory() - freeMemory()`, converted to MB.
- **Metrics dispatch**: A `Handler.postDelayed` runnable fires every 1 second.

## Lifecycle

The profiler automatically stops when the component using `usePerformance()` is unmounted. This prevents leaked `CADisplayLink`/`Choreographer` callbacks.

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | `CADisplayLink` for FPS, `mach_task_basic_info` for memory. |
| Android | `Choreographer.FrameCallback` for FPS, `Runtime.getRuntime()` for memory. |

## Notes

- Calling `startProfiling()` multiple times has no effect if already profiling.
- Calling `stopProfiling()` when not profiling is a no-op.
- The FPS value is averaged over 0.5-second windows for stability.
- Memory values on iOS reflect the process's resident memory; on Android, they reflect JVM heap usage.
- Bridge operation count is cumulative since `startProfiling()` was called.
