import { NativeBridge } from '../bridge'

/**
 * Haptic feedback composable.
 *
 * Wraps the native Haptics module to provide tactile feedback.
 *
 * @example
 * ```ts
 * const { vibrate, selectionChanged } = useHaptics()
 * vibrate('medium')
 * ```
 */
export function useHaptics() {
  /**
   * Trigger impact feedback.
   * @param style - 'light' | 'medium' | 'heavy' | 'rigid' | 'soft'
   */
  function vibrate(style: 'light' | 'medium' | 'heavy' | 'rigid' | 'soft' = 'medium'): Promise<void> {
    return NativeBridge.invokeNativeModule<void>('Haptics', 'vibrate', [style])
  }

  /**
   * Trigger notification feedback.
   * @param type - 'success' | 'warning' | 'error'
   */
  function notificationFeedback(type: 'success' | 'warning' | 'error' = 'success'): Promise<void> {
    return NativeBridge.invokeNativeModule<void>('Haptics', 'notificationFeedback', [type])
  }

  /**
   * Trigger selection changed feedback.
   */
  function selectionChanged(): Promise<void> {
    return NativeBridge.invokeNativeModule<void>('Haptics', 'selectionChanged', [])
  }

  return { vibrate, notificationFeedback, selectionChanged }
}
