# useGeolocation

GPS location access with support for one-shot position queries and continuous location watching. Coordinates are exposed as a reactive ref that updates automatically.

## Usage

```vue
<script setup>
import { useGeolocation } from '@thelacanians/vue-native-runtime'

const { coords, getCurrentPosition } = useGeolocation()

// Fetch position on demand
getCurrentPosition()
</script>

<template>
  <VView>
    <VText v-if="coords">
      {{ coords.latitude }}, {{ coords.longitude }}
    </VText>
  </VView>
</template>
```

## API

```ts
useGeolocation(): {
  coords: Ref<GeoCoordinates | null>
  error: Ref<string | null>
  getCurrentPosition: () => Promise<GeoCoordinates>
  watchPosition: () => Promise<number>
  clearWatch: (id: number) => Promise<void>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `coords` | `Ref<GeoCoordinates \| null>` | The most recent location coordinates. `null` until the first position is obtained. |
| `error` | `Ref<string \| null>` | Error message if the last location request failed. |
| `getCurrentPosition` | `() => Promise<GeoCoordinates>` | Request a single location fix. Updates `coords` and returns the result. |
| `watchPosition` | `() => Promise<number>` | Start continuous location updates. Returns a watch ID. Updates `coords` on every new position. |
| `clearWatch` | `(id: number) => Promise<void>` | Stop continuous updates for the given watch ID. |

### Types

```ts
interface GeoCoordinates {
  latitude: number
  longitude: number
  altitude: number
  accuracy: number       // horizontal accuracy in meters
  altitudeAccuracy: number
  heading: number        // course/bearing in degrees
  speed: number          // meters per second
  timestamp: number      // Unix timestamp in milliseconds
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `CLLocationManager`. Requires `NSLocationWhenInUseUsageDescription` in `Info.plist`. |
| Android | Uses `FusedLocationProviderClient` (Google Play Services). Requires `ACCESS_FINE_LOCATION` permission. |

## Example

```vue
<script setup>
import { onMounted, onUnmounted, ref } from 'vue'
import { useGeolocation } from '@thelacanians/vue-native-runtime'

const { coords, getCurrentPosition, watchPosition, clearWatch } = useGeolocation()
const watchId = ref<number | null>(null)

onMounted(async () => {
  // Get initial position
  await getCurrentPosition()
})

async function startTracking() {
  watchId.value = await watchPosition()
}

async function stopTracking() {
  if (watchId.value !== null) {
    await clearWatch(watchId.value)
    watchId.value = null
  }
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold', marginBottom: 12 }">
      Location
    </VText>
    <VText v-if="coords">
      Lat: {{ coords.latitude.toFixed(6) }}
    </VText>
    <VText v-if="coords">
      Lng: {{ coords.longitude.toFixed(6) }}
    </VText>
    <VText v-if="coords">
      Accuracy: {{ coords.accuracy.toFixed(0) }}m
    </VText>
    <VText v-if="!coords">
      Waiting for location...
    </VText>
    <VView :style="{ flexDirection: 'row', gap: 12, marginTop: 16 }">
      <VButton title="Start Tracking" :onPress="startTracking" />
      <VButton title="Stop Tracking" :onPress="stopTracking" />
    </VView>
  </VView>
</template>
```

## Notes

- **Permissions:** Location permission must be granted before calling `getCurrentPosition` or `watchPosition`. Use the `usePermissions` composable or request authorization natively. If permission is not granted, the native module returns an error.
- When using `watchPosition`, the listener and watch are automatically cleaned up on `onUnmounted`. You can also stop manually with `clearWatch`.
- On iOS, `clearWatch` stops `CLLocationManager.stopUpdatingLocation()` when no active watches remain.
- On Android, `getCurrentPosition` uses the last known location from `FusedLocationProviderClient`. If no cached location is available, it returns an error.
