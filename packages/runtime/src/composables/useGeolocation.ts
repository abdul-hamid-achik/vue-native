import { getCurrentInstance, ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface GeoCoordinates {
  latitude: number
  longitude: number
  altitude: number
  accuracy: number
  altitudeAccuracy: number
  heading: number
  speed: number
  timestamp: number
}

/**
 * GPS location access with optional continuous watching.
 *
 * @example
 * const { coords, getCurrentPosition } = useGeolocation()
 * await getCurrentPosition()
 * console.log(coords.value?.latitude)
 */
export function useGeolocation() {
  const coords = ref<GeoCoordinates | null>(null)
  const error = ref<string | null>(null)
  let watchId: number | null = null
  let unsubscribePosition: (() => void) | null = null
  let unsubscribeError: (() => void) | null = null
  let isDisposed = false

  function removeWatchListeners(): void {
    unsubscribePosition?.()
    unsubscribeError?.()
    unsubscribePosition = null
    unsubscribeError = null
  }

  // Lifecycle hooks must be registered synchronously during setup. Registering
  // after watchPosition() awaits loses the active Vue instance and leaks both
  // native listeners and the continuous location watch.
  if (getCurrentInstance()) {
    onUnmounted(() => {
      isDisposed = true
      removeWatchListeners()
      const activeWatchId = watchId
      watchId = null
      if (activeWatchId !== null) {
        void NativeBridge.invokeNativeModule('Geolocation', 'clearWatch', [activeWatchId])
          .catch(() => undefined)
      }
    })
  }

  async function getCurrentPosition(): Promise<GeoCoordinates> {
    try {
      error.value = null
      const result: GeoCoordinates = await NativeBridge.invokeNativeModule('Geolocation', 'getCurrentPosition')
      coords.value = result
      return result
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e)
      error.value = msg
      throw e
    }
  }

  async function watchPosition(): Promise<number> {
    try {
      error.value = null
      if (watchId !== null) {
        await clearWatch(watchId)
      }
      removeWatchListeners()

      const id: number = await NativeBridge.invokeNativeModule('Geolocation', 'watchPosition')
      if (isDisposed) {
        await NativeBridge.invokeNativeModule('Geolocation', 'clearWatch', [id])
        return id
      }
      watchId = id

      unsubscribePosition = NativeBridge.onGlobalEvent('location:update', (payload: GeoCoordinates) => {
        coords.value = payload
      })

      unsubscribeError = NativeBridge.onGlobalEvent('location:error', (payload: { message: string }) => {
        error.value = payload.message
      })

      return id
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e)
      error.value = msg
      throw e
    }
  }

  async function clearWatch(id: number): Promise<void> {
    await NativeBridge.invokeNativeModule('Geolocation', 'clearWatch', [id])
    if (watchId === id) {
      watchId = null
      removeWatchListeners()
    }
  }

  return { coords, error, getCurrentPosition, watchPosition, clearWatch }
}
