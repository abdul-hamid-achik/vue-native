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
  let unsubscribeLocation: (() => void) | null = null

  async function getCurrentPosition(): Promise<GeoCoordinates> {
    try {
      const result = await NativeBridge.invokeNativeModule<GeoCoordinates>('Geolocation', 'getCurrentPosition')
      coords.value = result
      return result
    } catch (e) {
      error.value = e instanceof Error ? e.message : String(e)
      throw e
    }
  }

  async function watchPosition(): Promise<number> {
    // Prevent multiple concurrent watches — clean up existing one first
    if (watchId !== null) {
      await clearWatch(watchId)
    }
    if (unsubscribeLocation) {
      unsubscribeLocation()
    }

    const id = await NativeBridge.invokeNativeModule<number>('Geolocation', 'watchPosition')
    watchId = id

    unsubscribeLocation = NativeBridge.onGlobalEvent<GeoCoordinates>('location:update', payload => {
      coords.value = payload
    })

    onUnmounted(() => {
      unsubscribeLocation?.()
      unsubscribeLocation = null
      if (watchId !== null) clearWatch(watchId)
    })

    return id
  }

  async function clearWatch(id: number): Promise<void> {
    await NativeBridge.invokeNativeModule<void>('Geolocation', 'clearWatch', [id])
    watchId = null
  }

  return { coords, error, getCurrentPosition, watchPosition, clearWatch }
}
