import { defineComponent, h, ref, type PropType } from '@vue/runtime-core'
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
 * Handles CJK IME composition correctly: during composition, model updates
 * are deferred until the user commits the composed character to avoid
 * v-model desync.
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
    // Track IME composition state to avoid emitting intermediate values
    // during CJK input. Without this, every keystroke during composition
    // triggers update:modelValue, causing v-model desync.
    const isComposing = ref(false)

    const onCompositionstart = () => {
      isComposing.value = true
    }

    const onCompositionend = (payload: any) => {
      isComposing.value = false
      const text = typeof payload === 'string' ? payload : payload?.text ?? ''
      emit('update:modelValue', text)
    }

    const onChangetext = (payload: any) => {
      if (isComposing.value) return // Skip during IME composition
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
        onCompositionstart,
        onCompositionend,
        onFocus,
        onBlur,
        onSubmit,
      })
  },
})
