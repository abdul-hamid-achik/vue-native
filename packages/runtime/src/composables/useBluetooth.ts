import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

export interface BLEDevice {
  id: string
  name: string
  rssi: number
}

export interface BLECharacteristic {
  value: string // base64 encoded
  characteristicUUID: string
  serviceUUID: string
}

export interface BLECharacteristicChange {
  deviceId: string
  serviceUUID: string
  characteristicUUID: string
  value: string // base64 encoded
}

export type BLEState = 'poweredOn' | 'poweredOff' | 'unauthorized' | 'unsupported' | 'resetting' | 'unknown'

// ─── useBluetooth composable ──────────────────────────────────────────────

/**
 * Bluetooth Low Energy (BLE) composable for scanning, connecting,
 * and communicating with BLE peripherals.
 *
 * @example
 * const { scan, connect, devices, connectedDevice, isScanning } = useBluetooth()
 *
 * // Scan for devices
 * await scan()
 *
 * // Connect to a device
 * await connect(devices.value[0].id)
 *
 * // Read a characteristic
 * const data = await read(deviceId, serviceUUID, charUUID)
 */
export function useBluetooth() {
  const devices = ref<BLEDevice[]>([])
  const connectedDevice = ref<BLEDevice | null>(null)
  const isScanning = ref(false)
  const isAvailable = ref(false)
  const error = ref<string | null>(null)

  const cleanups: Array<() => void> = []

  // Check BLE state on creation
  NativeBridge.invokeNativeModule('Bluetooth', 'getState')
    .then((state: BLEState) => {
      isAvailable.value = state === 'poweredOn'
    })
    .catch(() => {
      isAvailable.value = false
    })

  // Listen for state changes
  const unsubState = NativeBridge.onGlobalEvent('ble:stateChanged', (payload: { state: BLEState }) => {
    isAvailable.value = payload.state === 'poweredOn'
  })
  cleanups.push(unsubState)

  // Listen for discovered devices
  const unsubFound = NativeBridge.onGlobalEvent('ble:deviceFound', (payload: BLEDevice) => {
    const existing = devices.value.findIndex(d => d.id === payload.id)
    if (existing >= 0) {
      devices.value[existing] = payload
    } else {
      devices.value = [...devices.value, payload]
    }
  })
  cleanups.push(unsubFound)

  // Listen for connection events
  const unsubConnected = NativeBridge.onGlobalEvent('ble:connected', (payload: BLEDevice) => {
    connectedDevice.value = payload
  })
  cleanups.push(unsubConnected)

  const unsubDisconnected = NativeBridge.onGlobalEvent('ble:disconnected', () => {
    connectedDevice.value = null
  })
  cleanups.push(unsubDisconnected)

  // Listen for errors
  const unsubError = NativeBridge.onGlobalEvent('ble:error', (payload: { message: string }) => {
    error.value = payload.message
  })
  cleanups.push(unsubError)

  async function scan(serviceUUIDs?: string[]): Promise<void> {
    devices.value = []
    isScanning.value = true
    error.value = null
    try {
      await NativeBridge.invokeNativeModule('Bluetooth', 'startScan', [serviceUUIDs])
    } catch (e: any) {
      error.value = e?.message || String(e)
      isScanning.value = false
    }
  }

  async function stopScan(): Promise<void> {
    await NativeBridge.invokeNativeModule('Bluetooth', 'stopScan')
    isScanning.value = false
  }

  async function connect(deviceId: string): Promise<BLEDevice> {
    error.value = null
    const result: BLEDevice = await NativeBridge.invokeNativeModule('Bluetooth', 'connect', [deviceId])
    return result
  }

  async function disconnect(deviceId: string): Promise<void> {
    await NativeBridge.invokeNativeModule('Bluetooth', 'disconnect', [deviceId])
    connectedDevice.value = null
  }

  async function read(deviceId: string, serviceUUID: string, charUUID: string): Promise<BLECharacteristic> {
    return NativeBridge.invokeNativeModule('Bluetooth', 'readCharacteristic', [deviceId, serviceUUID, charUUID])
  }

  async function write(deviceId: string, serviceUUID: string, charUUID: string, data: string): Promise<void> {
    return NativeBridge.invokeNativeModule('Bluetooth', 'writeCharacteristic', [deviceId, serviceUUID, charUUID, data])
  }

  async function subscribe(
    deviceId: string,
    serviceUUID: string,
    charUUID: string,
    callback: (change: BLECharacteristicChange) => void,
  ): Promise<() => void> {
    await NativeBridge.invokeNativeModule('Bluetooth', 'subscribeToCharacteristic', [deviceId, serviceUUID, charUUID])
    const unsubscribe = NativeBridge.onGlobalEvent('ble:characteristicChanged', (payload: BLECharacteristicChange) => {
      if (
        payload.deviceId === deviceId
        && payload.serviceUUID === serviceUUID
        && payload.characteristicUUID === charUUID
      ) {
        callback(payload)
      }
    })
    cleanups.push(unsubscribe)
    return async () => {
      unsubscribe()
      await NativeBridge.invokeNativeModule('Bluetooth', 'unsubscribeFromCharacteristic', [
        deviceId,
        serviceUUID,
        charUUID,
      ])
    }
  }

  onUnmounted(() => {
    if (isScanning.value) {
      NativeBridge.invokeNativeModule('Bluetooth', 'stopScan').catch(() => {})
    }
    cleanups.forEach(fn => fn())
    cleanups.length = 0
  })

  return {
    scan,
    stopScan,
    connect,
    disconnect,
    read,
    write,
    subscribe,
    devices,
    connectedDevice,
    isScanning,
    isAvailable,
    error,
  }
}
