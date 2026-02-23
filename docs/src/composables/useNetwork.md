# useNetwork

Reactive network connectivity status. Automatically tracks whether the device is online and what type of connection is active. Updates in real time when network conditions change.

## Usage

```vue
<script setup>
import { useNetwork } from '@thelacanians/vue-native-runtime'

const { isConnected, connectionType } = useNetwork()
</script>

<template>
  <VView>
    <VText>{{ isConnected ? 'Online' : 'Offline' }}</VText>
    <VText>Connection: {{ connectionType }}</VText>
  </VView>
</template>
```

## API

```ts
useNetwork(): { isConnected: Ref<boolean>, connectionType: Ref<ConnectionType> }
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `isConnected` | `Ref<boolean>` | Whether the device currently has network connectivity. Defaults to `true` until the first native status check completes. |
| `connectionType` | `Ref<ConnectionType>` | The active connection type: `'wifi'`, `'cellular'`, `'ethernet'`, `'none'`, or `'unknown'`. |

### Types

```ts
type ConnectionType = 'wifi' | 'cellular' | 'ethernet' | 'none' | 'unknown'
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `NWPathMonitor` from the Network framework. Detects wifi, cellular, and ethernet. |
| Android | Uses `ConnectivityManager.NetworkCallback`. Detects wifi, cellular, and ethernet. |

## Example

```vue
<script setup>
import { watch } from 'vue'
import { useNetwork } from '@thelacanians/vue-native-runtime'

const { isConnected, connectionType } = useNetwork()

watch(isConnected, (connected) => {
  if (!connected) {
    console.log('Network lost — queuing offline requests')
  }
})
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold' }">
      Network Status
    </VText>
    <VText>
      Status: {{ isConnected ? 'Connected' : 'Disconnected' }}
    </VText>
    <VText>
      Type: {{ connectionType }}
    </VText>
  </VView>
</template>
```

## Notes

- The composable fetches the initial network status on creation and then subscribes to real-time push events from the native `NWPathMonitor` (iOS) or `ConnectivityManager` (Android).
- The event listener is automatically cleaned up on `onUnmounted`.
- `isConnected` defaults to `true` before the first native check resolves. Design your UI to handle this brief initial state.
