import type { Ref } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

type FocusTarget = number | { id: number } | Ref<{ id: number } | null | undefined>

function resolveNodeId(target: FocusTarget): number {
  if (typeof target === 'number') return target
  if (target !== null && typeof target === 'object' && 'value' in target) {
    const val = (target as Ref<{ id: number } | null | undefined>).value
    if (val !== null && val !== undefined && typeof val.id === 'number') return val.id
    throw new Error('[useAccessibility] Focus target ref has no .value.id — is the ref attached to a component?')
  }
  if (target !== null && typeof target === 'object' && 'id' in target
    && typeof (target as { id: unknown }).id === 'number') {
    return (target as { id: number }).id
  }
  throw new Error('[useAccessibility] Invalid focus target. Pass a node id, template ref, or NativeNode.')
}

/**
 * Accessibility composable for screen-reader announcements and focus management.
 *
 * - `announce(message)` makes the platform screen reader (VoiceOver / TalkBack)
 *   speak a message without moving focus — use for status updates and live
 *   regions (WCAG 4.1.3 Status Messages).
 * - `setFocus(target)` moves accessibility focus to a view — use after opening
 *   a modal/dialog or revealing new content (WCAG 2.4.3 Focus Order).
 *
 * @example
 * ```ts
 * const { announce, setFocus } = useAccessibility()
 *
 * announce('3 items added to your cart')
 * setFocus(dialogRef)
 * ```
 */
export function useAccessibility() {
  /** Announce a message to the screen reader (does not move focus). */
  function announce(message: string): void {
    NativeBridge.invokeNativeModule('Accessibility', 'announce', [message]).catch((err: unknown) => {
      console.warn('[vue-native] Accessibility.announce failed:', err)
    })
  }

  /** Move accessibility focus to the given view (node id, template ref, or NativeNode). */
  function setFocus(target: FocusTarget): void {
    const nodeId = resolveNodeId(target)
    NativeBridge.invokeNativeModule('Accessibility', 'setFocus', [nodeId]).catch((err: unknown) => {
      console.warn('[vue-native] Accessibility.setFocus failed:', err)
    })
  }

  return { announce, setFocus }
}
