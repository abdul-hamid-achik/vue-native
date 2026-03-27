import type { Directive, VNode } from '@vue/runtime-core'
import type { NativeNode } from '../node'
import { NativeBridge } from '../bridge'

interface ModelDirectiveEvent {
  value?: unknown
  target?: {
    value?: unknown
  }
}

type ModelBinding = {
  value: unknown
  modifiers?: {
    lazy?: boolean
    number?: boolean
    trim?: boolean
  }
}

function getModelValue(event: unknown): unknown {
  const modelEvent = event as ModelDirectiveEvent | undefined
  return modelEvent?.value ?? modelEvent?.target?.value ?? event
}

/**
 * v-model directive for native inputs.
 *
 * Provides two-way data binding for form elements like VInput, VSwitch, VSlider, etc.
 *
 * @example
 * ```vue
 * <VInput v-model="text" />
 * <VSwitch v-model="enabled" />
 * <VInput v-model.lazy="text" />
 * <VInput v-model.number="count" />
 * <VInput v-model.trim="text" />
 * ```
 */
export const vModel: Directive<NativeNode> = {
  beforeMount(el, binding, vnode) {
    const { value, modifiers } = binding as unknown as ModelBinding
    const { lazy, number, trim } = modifiers || {}

    // Set initial value on native element
    NativeBridge.updateProp(el.id, 'value', value)

    // Get the assign function from vnode - this is the function Vue's compiler
    // wired up to push values back to the binding. It calls emit('update:modelValue', value)
    const assign = (vnode as VNode).dirs?.[0]?.value as ((value: unknown) => void) | undefined

    if (typeof assign !== 'function') {
      console.warn(
        '[VueNative] v-model directive requires the vnode to have an assign function. '
        + 'This usually happens when using v-model on native elements rendered by Vue, '
        + 'not custom components with modelValue props.',
      )
      return
    }

    // Listen to input or change event based on lazy modifier
    const eventName = lazy ? 'change' : 'input'
    NativeBridge.addEventListener(el.id, eventName, (event: unknown) => {
      let newValue = getModelValue(event)

      // Apply modifiers to the raw user input before pushing back
      if (trim && typeof newValue === 'string') {
        newValue = newValue.trim()
      }
      if (number) {
        newValue = Number(newValue)
      }

      // Push the new value back to the reactive binding
      assign(newValue)
    })
  },

  updated(el, { value, oldValue, modifiers }, vnode) {
    if (value === oldValue) return

    // Get assign function in case component re-renders changed vnode tree
    const _assign = (vnode as VNode).dirs?.[0]?.value as ((value: unknown) => void) | undefined

    // Apply modifiers consistently when parent value changes
    // Note: Applying trim/number to parent value is unusual but maintains parity
    // with how modifiers work in the event direction
    let newValue = value
    if (modifiers?.trim && typeof value === 'string') {
      newValue = value.trim()
    }
    if (modifiers?.number) {
      newValue = Number(value)
    }

    // Update native value to reflect parent's (potentially modified) value
    // This ensures consistency between what's shown and what would be sent on input
    NativeBridge.updateProp(el.id, 'value', newValue)
  },

  beforeUnmount(el, _binding, _vnode) {
    // Cleanup event listeners - remove whichever was registered
    // Since we don't track which one was registered, try both
    NativeBridge.removeEventListener(el.id, 'input')
    NativeBridge.removeEventListener(el.id, 'change')
  },
}
