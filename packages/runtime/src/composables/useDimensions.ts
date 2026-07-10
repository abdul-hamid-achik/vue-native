import { ref, onMounted, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface Dimensions {
  width: number
  height: number
  scale: number
}

interface DeviceInfoPayload {
  screenWidth?: number
  screenHeight?: number
  scale?: number
  screenScale?: number
}

interface DimensionsChangePayload {
  width?: number
  height?: number
  scale?: number
}

/**
 * Reactive screen dimensions composable.
 *
 * Fetches initial dimensions from DeviceInfo on mount, then listens for
 * orientation/resize changes via the 'dimensionsChange' global event.
 *
 * @example
 * ```ts
 * const { width, height, scale } = useDimensions()
 * ```
 */
export function useDimensions() {
  const width = ref(0)
  const height = ref(0)
  const scale = ref(1)
  let eventRevision = 0
  let isActive = true

  onMounted(async () => {
    const revisionAtRequest = eventRevision
    try {
      const info: DeviceInfoPayload = await NativeBridge.invokeNativeModule('DeviceInfo', 'getInfo', [])
      // Resize/orientation events emitted while the snapshot is loading are
      // newer than the snapshot and must remain authoritative.
      if (isActive && eventRevision === revisionAtRequest) {
        width.value = info?.screenWidth || 0
        height.value = info?.screenHeight || 0
        scale.value = info?.scale ?? info?.screenScale ?? 1
      }
    } catch {
      // DeviceInfo may not be available in all environments
    }
  })

  // Listen for orientation/resize changes
  const cleanup = NativeBridge.onGlobalEvent<DimensionsChangePayload>('dimensionsChange', (payload) => {
    eventRevision++
    if (payload.width != null) width.value = payload.width
    if (payload.height != null) height.value = payload.height
    if (payload.scale != null) scale.value = payload.scale
  })

  onUnmounted(() => {
    isActive = false
    cleanup()
  })

  return { width, height, scale }
}
