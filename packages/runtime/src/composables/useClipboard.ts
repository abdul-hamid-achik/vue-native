import { ref } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

/**
 * Clipboard composable providing read/write access to UIPasteboard.
 *
 * `content` is a reactive ref that updates when `paste()` is called.
 *
 * @example
 * ```ts
 * const { copy, paste, content } = useClipboard()
 * await copy('Hello, World!')
 * const text = await paste()
 * ```
 */
export function useClipboard() {
  /** The last pasted clipboard content */
  const content = ref<string>('')

  /**
   * Copy text to the clipboard.
   */
  function copy(text: string): Promise<void> {
    return NativeBridge.invokeNativeModule('Clipboard', 'copy', [text]).then(() => undefined)
  }

  /**
   * Paste the current clipboard content. Updates the `content` ref.
   */
  async function paste(): Promise<string> {
    const text = await NativeBridge.invokeNativeModule('Clipboard', 'paste', [])
    const result = typeof text === 'string' ? text : ''
    content.value = result
    return result
  }

  return { copy, paste, content }
}
