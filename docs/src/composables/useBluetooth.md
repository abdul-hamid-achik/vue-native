# useBluetooth

Bluetooth Low Energy (BLE) composable for scanning, connecting to, and communicating with BLE peripherals. Provides reactive state for discovered devices, connection status, and BLE availability.

## Usage

```vue
<script setup>
import { useBluetooth } from '@thelacanians/vue-native-runtime'

const { scan, stopScan, connect, devices, isScanning, isAvailable } = useBluetooth()
</script>

<template>
  <VView>
    <VText v-if="!isAvailable">Bluetooth is not available</VText>
    <VButton :onPress="() => scan()">
      <VText>{{ isScanning ? 'Scanning...' : 'Scan for Devices' }}</VText>
    </VButton>
    <VView v-for="device in devices" :key="device.id">
      <VText>{{ device.name || 'Unknown' }} ({{ device.rssi }}dBm)</VText>
      <VButton :onPress="() => connect(device.id)">
        <VText>Connect</VText>
      </VButton>
    </VView>
  </VView>
</template>
```

## API

```ts
useBluetooth(): {
  scan: (serviceUUIDs?: string[]) => Promise<void>
  stopScan: () => Promise<void>
  connect: (deviceId: string) => Promise<BLEDevice>
  disconnect: (deviceId: string) => Promise<void>
  read: (deviceId: string, serviceUUID: string, charUUID: string) => Promise<BLECharacteristic>
  write: (deviceId: string, serviceUUID: string, charUUID: string, data: string) => Promise<void>
  subscribe: (deviceId: string, serviceUUID: string, charUUID: string, callback: (change: BLECharacteristicChange) => void) => Promise<() => void>
  devices: Ref<BLEDevice[]>
  connectedDevice: Ref<BLEDevice | null>
  isScanning: Ref<boolean>
  isAvailable: Ref<boolean>
  error: Ref<string | null>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `scan` | `(serviceUUIDs?: string[]) => Promise<void>` | Start scanning for BLE peripherals. Optionally filter by service UUIDs. |
| `stopScan` | `() => Promise<void>` | Stop scanning for peripherals. |
| `connect` | `(deviceId: string) => Promise<BLEDevice>` | Connect to a discovered peripheral by its ID. |
| `disconnect` | `(deviceId: string) => Promise<void>` | Disconnect from a connected peripheral. |
| `read` | `(deviceId, serviceUUID, charUUID) => Promise<BLECharacteristic>` | Read a characteristic value (returned as base64). |
| `write` | `(deviceId, serviceUUID, charUUID, data) => Promise<void>` | Write data (base64 encoded) to a characteristic. |
| `subscribe` | `(deviceId, serviceUUID, charUUID, callback) => Promise<() => void>` | Subscribe to characteristic notifications. Returns an unsubscribe function. |
| `devices` | `Ref<BLEDevice[]>` | List of discovered devices, updated during scanning. |
| `connectedDevice` | `Ref<BLEDevice \| null>` | Currently connected device, or `null`. |
| `isScanning` | `Ref<boolean>` | Whether a scan is currently in progress. |
| `isAvailable` | `Ref<boolean>` | Whether Bluetooth is powered on and available. |
| `error` | `Ref<string \| null>` | Last error message, or `null`. |

### Types

```ts
interface BLEDevice {
  id: string      // UUID (iOS) or MAC address (Android)
  name: string    // Advertised name
  rssi: number    // Signal strength in dBm
}

interface BLECharacteristic {
  value: string            // base64 encoded data
  characteristicUUID: string
  serviceUUID: string
}

interface BLECharacteristicChange {
  deviceId: string
  serviceUUID: string
  characteristicUUID: string
  value: string            // base64 encoded
}

type BLEState = 'poweredOn' | 'poweredOff' | 'unauthorized' | 'unsupported' | 'resetting' | 'unknown'
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses `CoreBluetooth` (`CBCentralManager`). Add `NSBluetoothAlwaysUsageDescription` to `Info.plist`. |
| Android | Uses Android BLE API (`BluetoothLeScanner`, `BluetoothGatt`). Requires `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` permissions (Android 12+) or `ACCESS_FINE_LOCATION` (older). |

## Example

```vue
<script setup>
import { ref } from 'vue'
import { useBluetooth } from '@thelacanians/vue-native-runtime'

const HEART_RATE_SERVICE = '180D'
const HEART_RATE_MEASUREMENT = '2A37'

const { scan, stopScan, connect, read, subscribe, devices, connectedDevice, isScanning, isAvailable } = useBluetooth()
const heartRate = ref<number | null>(null)

async function connectToDevice(deviceId: string) {
  await stopScan()
  await connect(deviceId)

  // Subscribe to heart rate measurements
  await subscribe(deviceId, HEART_RATE_SERVICE, HEART_RATE_MEASUREMENT, (change) => {
    // Decode heart rate from base64 value
    const bytes = atob(change.value)
    heartRate.value = bytes.charCodeAt(1)
  })
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold', marginBottom: 12 }">
      BLE Heart Rate Monitor
    </VText>

    <VText v-if="!isAvailable" :style="{ color: 'red' }">
      Bluetooth is not available
    </VText>

    <VButton v-if="!connectedDevice" :onPress="() => scan([HEART_RATE_SERVICE])">
      <VText>{{ isScanning ? 'Scanning...' : 'Find Heart Rate Monitors' }}</VText>
    </VButton>

    <VView v-if="isScanning">
      <VView v-for="device in devices" :key="device.id" :style="{ marginVertical: 4 }">
        <VButton :onPress="() => connectToDevice(device.id)">
          <VText>{{ device.name || 'Unknown' }} ({{ device.rssi }}dBm)</VText>
        </VButton>
      </VView>
    </VView>

    <VView v-if="connectedDevice">
      <VText>Connected to: {{ connectedDevice.name }}</VText>
      <VText v-if="heartRate" :style="{ fontSize: 48, fontWeight: 'bold' }">
        {{ heartRate }} BPM
      </VText>
    </VView>
  </VView>
</template>
```

## Notes

- **Permissions:** Use the `usePermissions` composable to request Bluetooth permissions before scanning, or handle the error from `scan()`.
- **Data encoding:** Characteristic values are transferred as base64-encoded strings. Use `atob()` / `btoa()` to decode/encode.
- **Service discovery:** After connecting, the native side automatically discovers all services and characteristics. There may be a brief delay before `read`/`write`/`subscribe` work.
- **Cleanup:** Scanning is automatically stopped on component unmount. Event listeners are cleaned up.
- **Background BLE:** For background BLE, add the `bluetooth-central` background mode to your iOS `Info.plist`.
