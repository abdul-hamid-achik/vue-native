import { ref, onUnmounted } from '@vue/runtime-core'
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
      const id: number = await NativeBridge.invokeNativeModule('Geolocation', 'watchPosition')
      watchId = id

      const unsubscribe = NativeBridge.onGlobalEvent('location:update', (payload: GeoCoordinates) => {
        coords.value = payload
      })

      const unsubscribeError = NativeBridge.onGlobalEvent('location:error', (payload: { message: string }) => {
        error.value = payload.message
      })

      onUnmounted(() => {
        unsubscribe()
        unsubscribeError()
        if (watchId !== null) clearWatch(watchId)
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
    watchId = null
  }

  return { coords, error, getCurrentPosition, watchPosition, clearWatch }
}
