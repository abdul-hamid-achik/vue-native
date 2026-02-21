import { ref } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

/**
 * Keyboard state composable.
 *
 * Provides reactive keyboard visibility state and a dismiss function.
 * The `isVisible` and `height` refs are updated by native keyboard events
 * dispatched through a special keyboard node.
 *
 * @example
 * ```ts
 * const { isVisible, height, dismiss } = useKeyboard()
 * ```
 */
export function useKeyboard() {
  const isVisible = ref(false)
  const height = ref(0)

  /**
   * Dismiss the keyboard programmatically.
   */
  function dismiss(): Promise<void> {
    return NativeBridge.invokeNativeModule('Keyboard', 'dismiss', []).then(() => undefined)
  }

  /**
   * Get current keyboard height and visibility.
   */
  async function getHeight(): Promise<{ height: number; isVisible: boolean }> {
    const result = await NativeBridge.invokeNativeModule('Keyboard', 'getHeight', []) as { height: number; isVisible: boolean }
    isVisible.value = result.isVisible ?? false
    height.value = result.height ?? 0
    return result
  }

  return { isVisible, height, dismiss, getHeight }
}
