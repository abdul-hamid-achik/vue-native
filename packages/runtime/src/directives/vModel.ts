import type { Directive } from '@vue/runtime-core'
import type { NativeNode } from '../node'
import { NativeBridge } from '../bridge'

/**
 * v-model directive for native inputs.
 *
 * Provides two-way data binding for form elements like VInput, VSwitch, VSlider, etc.
 *
 * @example
 * ```vue
 * <VInput v-model="text" />
 * <VSwitch v-model="enabled" />
 * ```
 */
export const vModel: Directive<NativeNode> = {
  beforeMount(el, { value, modifiers }) {
    const { lazy, number, trim } = modifiers || {}

    // Set initial value
    NativeBridge.updateProp(el.id, 'value', value)

    // Add event listener for input changes
    const eventName = lazy ? 'change' : 'input'
    NativeBridge.addEventListener(el.id, eventName, (event: any) => {
      let newValue = event?.value ?? event?.target?.value ?? event

      // Apply modifiers
      if (trim && typeof newValue === 'string') {
        newValue = newValue.trim()
      }
      if (number) {
        newValue = Number(newValue)
      }

      // Update the binding - this will trigger a re-render if needed
      // The actual value update happens through Vue's reactivity system
    })
  },

  updated(el, { value, oldValue, modifiers }) {
    if (value === oldValue) return

    // Apply modifiers
    let newValue = value
    if (modifiers?.trim && typeof value === 'string') {
      newValue = value.trim()
    }
    if (modifiers?.number) {
      newValue = Number(value)
    }

    // Update native value
    NativeBridge.updateProp(el.id, 'value', newValue)
  },

  beforeUnmount(el) {
    // Cleanup event listeners
    NativeBridge.removeEventListener(el.id, 'input')
    NativeBridge.removeEventListener(el.id, 'change')
  },
}
