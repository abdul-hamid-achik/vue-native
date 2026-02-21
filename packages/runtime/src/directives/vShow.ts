import type { Directive } from '@vue/runtime-core'
import type { NativeNode } from '../node'
import { NativeBridge } from '../bridge'

/**
 * v-show directive for Vue Native.
 * Maps to the 'hidden' prop on native views (view.isHidden in Swift).
 */
export const vShow: Directive<NativeNode> = {
  beforeMount(el, { value }) {
    NativeBridge.updateProp(el.id, 'hidden', !value)
  },
  updated(el, { value, oldValue }) {
    if (value === oldValue) return
    NativeBridge.updateProp(el.id, 'hidden', !value)
  },
}
