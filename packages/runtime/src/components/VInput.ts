import { defineComponent, h, type PropType } from '@vue/runtime-core'
import type { TextStyle } from '../types/styles'

/**
 * VInput — a text input component with v-model support.
 *
 * Maps to UITextField (single-line) or UITextView (multiline) on iOS.
 * Implements Vue's v-model convention by accepting a `modelValue` prop
 * and emitting `update:modelValue` on text change.
 *
 * The component maps `modelValue` to the native `text` prop and listens
 * for `changetext` events from the native side to update the model.
 *
 * @example
 * ```vue
 * <VInput
 *   v-model="username"
 *   placeholder="Enter your name"
 *   :style="{ borderWidth: 1, borderColor: '#ccc', padding: 8 }"
 *   @focus="onFocus"
 *   @blur="onBlur"
 * />
 * ```
 */
export const VInput = defineComponent({
  name: 'VInput',
  props: {
    modelValue: {
      type: String,
      default: '',
    },
    placeholder: String,
    secureTextEntry: {
      type: Boolean,
      default: false,
    },
    keyboardType: {
      type: String,
      default: 'default',
    },
    returnKeyType: {
      type: String,
      default: 'done',
    },
    autoCapitalize: {
      type: String,
      default: 'sentences',
    },
    autoCorrect: {
      type: Boolean,
      default: true,
    },
    maxLength: Number,
    multiline: {
      type: Boolean,
      default: false,
    },
    style: Object as PropType<TextStyle>,
    accessibilityLabel: String,
    accessibilityRole: String,
    accessibilityHint: String,
    accessibilityState: Object,
  },
  emits: ['update:modelValue', 'focus', 'blur', 'submit'],
  setup(props, { emit }) {
    const onChangetext = (payload: any) => {
      const text = typeof payload === 'string' ? payload : payload?.text ?? ''
      emit('update:modelValue', text)
    }

    const onFocus = (payload: any) => {
      emit('focus', payload)
    }

    const onBlur = (payload: any) => {
      emit('blur', payload)
    }

    const onSubmit = (payload: any) => {
      emit('submit', payload)
    }

    return () =>
      h('VInput', {
        text: props.modelValue,
        placeholder: props.placeholder,
        secureTextEntry: props.secureTextEntry,
        keyboardType: props.keyboardType,
        returnKeyType: props.returnKeyType,
        autoCapitalize: props.autoCapitalize,
        autoCorrect: props.autoCorrect,
        maxLength: props.maxLength,
        multiline: props.multiline,
        style: props.style,
        accessibilityLabel: props.accessibilityLabel,
        accessibilityRole: props.accessibilityRole,
        accessibilityHint: props.accessibilityHint,
        accessibilityState: props.accessibilityState,
        onChangetext,
        onFocus,
        onBlur,
        onSubmit,
      })
  },
})
