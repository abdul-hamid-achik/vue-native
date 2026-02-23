import { onMounted, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

/**
 * useBackHandler — intercept the hardware back button press (Android).
 *
 * The callback should return `true` if the back press was handled
 * (preventing default behavior), or `false` to allow default navigation.
 *
 * On iOS this is a no-op since there is no hardware back button,
 * but the event can still be dispatched programmatically.
 *
 * @example
 * ```ts
 * useBackHandler(() => {
 *   if (hasUnsavedChanges.value) {
 *     showDiscardDialog()
 *     return true // prevent default back
 *   }
 *   return false // allow default back
 * })
 * ```
 */
export function useBackHandler(handler: () => boolean): void {
  let unsubscribe: (() => void) | null = null

  onMounted(() => {
    unsubscribe = NativeBridge.onGlobalEvent('hardware:backPress', () => {
      handler()
    })
  })

  onUnmounted(() => {
    unsubscribe?.()
    unsubscribe = null
  })
}
