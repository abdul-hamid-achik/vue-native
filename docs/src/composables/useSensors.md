# useSensors

Device motion sensor composables. Exports `useAccelerometer` and `useGyroscope` for accessing real-time accelerometer and gyroscope data. Sensors are not started by default — call `start()` to begin receiving updates, and `stop()` to pause them.

## Usage

```vue
<script setup>
import { useAccelerometer, useGyroscope } from '@thelacanians/vue-native-runtime'

const accel = useAccelerometer({ interval: 50 })
const gyro = useGyroscope({ interval: 50 })

accel.start()
gyro.start()
</script>

<template>
  <VView>
    <VText>Accelerometer: x={{ accel.x.toFixed(2) }} y={{ accel.y.toFixed(2) }} z={{ accel.z.toFixed(2) }}</VText>
    <VText>Gyroscope: x={{ gyro.x.toFixed(2) }} y={{ gyro.y.toFixed(2) }} z={{ gyro.z.toFixed(2) }}</VText>
  </VView>
</template>
```

## API

### useAccelerometer

```ts
useAccelerometer(options?: SensorOptions): {
  x: Ref<number>,
  y: Ref<number>,
  z: Ref<number>,
  isAvailable: Ref<boolean>,
  start: () => void,
  stop: () => void
}
```

### useGyroscope

```ts
useGyroscope(options?: SensorOptions): {
  x: Ref<number>,
  y: Ref<number>,
  z: Ref<number>,
  isAvailable: Ref<boolean>,
  start: () => void,
  stop: () => void
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `options` | `SensorOptions` | Optional configuration for the sensor update interval. |

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `x` | `Ref<number>` | The sensor reading along the x-axis. |
| `y` | `Ref<number>` | The sensor reading along the y-axis. |
| `z` | `Ref<number>` | The sensor reading along the z-axis. |
| `isAvailable` | `Ref<boolean>` | Whether the sensor hardware is available on the device. |
| `start` | `() => void` | Begin receiving sensor updates. |
| `stop` | `() => void` | Stop receiving sensor updates. |

### Types

```ts
interface SensorOptions {
  /** Update interval in milliseconds. Default: 100 */
  interval?: number
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `CMMotionManager` from the CoreMotion framework. Accelerometer values are in G-forces; gyroscope values are in radians per second. |
| Android | Uses `SensorManager` with `Sensor.TYPE_ACCELEROMETER` and `Sensor.TYPE_GYROSCOPE`. Accelerometer values are in m/s²; gyroscope values are in radians per second. |

## Example

```vue
<script setup>
import { computed } from 'vue'
import { useAccelerometer } from '@thelacanians/vue-native-runtime'

const { x, y, z, isAvailable, start, stop } = useAccelerometer({ interval: 100 })

const tilt = computed(() => {
  const angle = Math.atan2(y.value, x.value) * (180 / Math.PI)
  return Math.round(angle)
})
</script>

<template>
  <VView :style="{ flex: 1, padding: 20, alignItems: 'center' }">
    <VText :style="{ fontSize: 24, marginBottom: 16 }">Motion Sensor</VText>

    <VText v-if="!isAvailable" :style="{ color: 'red' }">
      Accelerometer not available on this device.
    </VText>

    <VView v-else>
      <VText>X: {{ x.toFixed(3) }}</VText>
      <VText>Y: {{ y.toFixed(3) }}</VText>
      <VText>Z: {{ z.toFixed(3) }}</VText>
      <VText :style="{ marginTop: 12 }">Tilt: {{ tilt }}°</VText>

      <VView :style="{ flexDirection: 'row', marginTop: 20, gap: 12 }">
        <VButton title="Start" @press="start" />
        <VButton title="Stop" @press="stop" />
      </VView>
    </VView>
  </VView>
</template>
```

## Notes

- Sensors are **not started by default**. You must call `start()` to begin receiving data updates.
- The default update interval is 100 milliseconds. Lower intervals provide smoother data but consume more battery.
- Sensor updates are automatically stopped when the component unmounts to conserve battery and prevent resource leaks.
- The `isAvailable` ref is checked on initialization. On devices without the required hardware (e.g., simulators), it will be `false`.
- Accelerometer units differ between platforms: iOS reports G-forces while Android reports m/s². Plan accordingly if cross-platform consistency is needed.
- Both composables are exported individually from the runtime package, not as a combined `useSensors` function.
