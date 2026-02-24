import { ref, onMounted, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface Dimensions {
  width: number
  height: number
  scale: number
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

  onMounted(async () => {
    try {
      const info = await NativeBridge.invokeNativeModule('DeviceInfo', 'getInfo', [])
      width.value = info?.screenWidth || 0
      height.value = info?.screenHeight || 0
      scale.value = info?.scale || 1
    } catch {
      // DeviceInfo may not be available in all environments
    }
  })

  // Listen for orientation/resize changes
  const cleanup = NativeBridge.onGlobalEvent('dimensionsChange', (payload: any) => {
    if (payload.width != null) width.value = payload.width
    if (payload.height != null) height.value = payload.height
    if (payload.scale != null) scale.value = payload.scale
  })

  onUnmounted(cleanup)

  return { width, height, scale }
}
