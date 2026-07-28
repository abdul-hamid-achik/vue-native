import { onMounted, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

declare const __PLATFORM__: string

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
      const handled = handler()
      if (!handled) {
        // BackHandler.exitApp only exists on Android. Skip it on iOS/macOS to
        // avoid a guaranteed failure (and a spurious dev warning) when the back
        // event is dispatched programmatically there.
        const platform = typeof __PLATFORM__ !== 'undefined' ? __PLATFORM__ : undefined
        if (platform !== 'ios' && platform !== 'macos') {
          NativeBridge.invokeNativeModule('BackHandler', 'exitApp', []).catch((err: unknown) => {
            if (__DEV__) console.warn('[vue-native] BackHandler.exitApp failed:', err)
          })
        }
      }
    })
  })

  onUnmounted(() => {
    unsubscribe?.()
    unsubscribe = null
  })
}
