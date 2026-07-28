# useBattery

Reactive battery state — level and charging status. Backed by the native `Battery` module
(`UIDevice` battery monitoring on iOS, `BatteryManager` on Android). On platforms without a
battery (desktop Mac) the values stay `null` and `isSupported` is `false`.

## API

```ts
const { level, isCharging, isSupported, refresh } = useBattery(options?)
```

| Return | Type | Description |
|--------|------|-------------|
| `level` | `Ref<number \| null>` | Battery level `0..1`, or `null` when unavailable. |
| `isCharging` | `Ref<boolean \| null>` | Whether the battery is charging, or `null` when unavailable. |
| `isSupported` | `Ref<boolean \| null>` | `false` on devices without a battery. |
| `refresh` | `() => Promise<void>` | Manually re-read the battery state. |

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `pollInterval` | `number` | `60000` | Refresh interval in ms. `0` disables automatic polling. |

## Example

```vue
<script setup lang="ts">
import { useBattery, VText, VView } from '@thelacanians/vue-native-runtime'

const { level, isCharging, isSupported } = useBattery()
</script>

<template>
  <VView v-if="isSupported">
    <VText>Battery: {{ Math.round((level ?? 0) * 100) }}%</VText>
    <VText>{{ isCharging ? 'Charging' : 'Not charging' }}</VText>
  </VView>
  <VText v-else>Battery info not available on this device.</VText>
</template>
```

## Notes

- The state is read on mount and refreshed every `pollInterval` ms.
- Set `pollInterval: 0` and call `refresh()` yourself for on-demand reads.
