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

interface ModelState {
  eventName: string
  listener: (event: unknown) => void
  /** Kept current by `updated` so the listener never writes through a stale binding. */
  assign: (value: unknown) => void
}

/** Per-element directive state, shared between the mount/update/unmount hooks. */
const modelState = new WeakMap<NativeNode, ModelState>()

function getAssigner(vnode: VNode): ((value: unknown) => void) | undefined {
  const assign = vnode.dirs?.[0]?.value as ((value: unknown) => void) | undefined
  return typeof assign === 'function' ? assign : undefined
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
    const assign = getAssigner(vnode as VNode)

    if (!assign) {
      console.warn(
        '[VueNative] v-model directive requires the vnode to have an assign function. '
        + 'This usually happens when using v-model on native elements rendered by Vue, '
        + 'not custom components with modelValue props.',
      )
      return
    }

    // Listen to input or change event based on lazy modifier. The listener
    // reads the assign function through the shared state at event time, so
    // re-renders that produce a new assign function keep working (`updated`
    // refreshes it below).
    const eventName = lazy ? 'change' : 'input'
    const state: ModelState = {
      eventName,
      assign,
      listener: (event: unknown) => {
        let newValue = getModelValue(event)

        // Apply modifiers to the raw user input before pushing back
        if (trim && typeof newValue === 'string') {
          newValue = newValue.trim()
        }
        if (number) {
          newValue = Number(newValue)
        }

        // Push the new value back to the current reactive binding
        state.assign(newValue)
      },
    }
    modelState.set(el, state)
    NativeBridge.addEventListener(el.id, eventName, state.listener)
  },

  updated(el, { value, oldValue, modifiers }, vnode) {
    // Re-point the listener at the current vnode's assign function before the
    // value short-circuit: a re-render can change the binding target without
    // changing the displayed value.
    const state = modelState.get(el)
    const assign = getAssigner(vnode as VNode)
    if (state && assign) {
      state.assign = assign
    }

    if (value === oldValue) return

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
    // Remove exactly the listener this directive registered, leaving any other
    // subscriber on the same (node, event) pair untouched.
    const state = modelState.get(el)
    if (state) {
      NativeBridge.removeEventListener(el.id, state.eventName, state.listener)
      modelState.delete(el)
    }
  },
}
