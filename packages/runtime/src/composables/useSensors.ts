import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

export interface SensorOptions {
  /** Update interval in milliseconds. Default: 100 */
  interval?: number
}

export interface SensorData {
  x: number
  y: number
  z: number
}

// ─── useAccelerometer ─────────────────────────────────────────────────────

/**
 * Reactive accelerometer data. Reads device acceleration (including gravity)
 * via CMMotionManager on iOS and SensorManager on Android.
 *
 * @example
 * const { x, y, z, isAvailable, start, stop } = useAccelerometer({ interval: 50 })
 */
export function useAccelerometer(options: SensorOptions = {}) {
  const x = ref(0)
  const y = ref(0)
  const z = ref(0)
  const isAvailable = ref(false)
  let running = false
  let unsubscribe: (() => void) | null = null

  // Check availability
  NativeBridge.invokeNativeModule('Sensors', 'isAvailable', ['accelerometer'])
    .then((result: { available: boolean }) => {
      isAvailable.value = result.available
    })
    .catch(() => {})

  function start() {
    if (running) return
    running = true

    unsubscribe = NativeBridge.onGlobalEvent('sensor:accelerometer', (payload: SensorData) => {
      x.value = payload.x
      y.value = payload.y
      z.value = payload.z
    })

    NativeBridge.invokeNativeModule('Sensors', 'startAccelerometer', [
      options.interval ?? 100,
    ]).catch(() => {})
  }

  function stop() {
    if (!running) return
    running = false
    unsubscribe?.()
    unsubscribe = null
    NativeBridge.invokeNativeModule('Sensors', 'stopAccelerometer').catch(() => {})
  }

  onUnmounted(() => {
    stop()
  })

  return { x, y, z, isAvailable, start, stop }
}

// ─── useGyroscope ─────────────────────────────────────────────────────────

/**
 * Reactive gyroscope data. Reads device rotation rate
 * via CMMotionManager on iOS and SensorManager on Android.
 *
 * @example
 * const { x, y, z, isAvailable, start, stop } = useGyroscope({ interval: 50 })
 */
export function useGyroscope(options: SensorOptions = {}) {
  const x = ref(0)
  const y = ref(0)
  const z = ref(0)
  const isAvailable = ref(false)
  let running = false
  let unsubscribe: (() => void) | null = null

  // Check availability
  NativeBridge.invokeNativeModule('Sensors', 'isAvailable', ['gyroscope'])
    .then((result: { available: boolean }) => {
      isAvailable.value = result.available
    })
    .catch(() => {})

  function start() {
    if (running) return
    running = true

    unsubscribe = NativeBridge.onGlobalEvent('sensor:gyroscope', (payload: SensorData) => {
      x.value = payload.x
      y.value = payload.y
      z.value = payload.z
    })

    NativeBridge.invokeNativeModule('Sensors', 'startGyroscope', [
      options.interval ?? 100,
    ]).catch(() => {})
  }

  function stop() {
    if (!running) return
    running = false
    unsubscribe?.()
    unsubscribe = null
    NativeBridge.invokeNativeModule('Sensors', 'stopGyroscope').catch(() => {})
  }

  onUnmounted(() => {
    stop()
  })

  return { x, y, z, isAvailable, start, stop }
}
