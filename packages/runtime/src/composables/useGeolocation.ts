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
    const result: GeoCoordinates = await NativeBridge.invokeNativeModule('Geolocation', 'getCurrentPosition')
    coords.value = result
    return result
  }

  async function watchPosition(): Promise<number> {
    const id: number = await NativeBridge.invokeNativeModule('Geolocation', 'watchPosition')
    watchId = id

    const unsubscribe = NativeBridge.onGlobalEvent('location:update', (payload: GeoCoordinates) => {
      coords.value = payload
    })

    onUnmounted(() => {
      unsubscribe()
      if (watchId !== null) clearWatch(watchId)
    })

    return id
  }

  async function clearWatch(id: number): Promise<void> {
    await NativeBridge.invokeNativeModule('Geolocation', 'clearWatch', [id])
    watchId = null
  }

  return { coords, error, getCurrentPosition, watchPosition, clearWatch }
}
