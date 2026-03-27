import { defineComponent, h, ref, type PropType } from '@vue/runtime-core'
import type { TextStyle } from '../types/styles'

interface TextPayload {
  text?: string
}

function extractText(payload: unknown): string {
  if (typeof payload === 'string') {
    return payload
  }

  if (typeof payload === 'object' && payload !== null && 'text' in payload) {
    const text = (payload as TextPayload).text
    return typeof text === 'string' ? text : ''
  }

  return ''
}

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

    const onCompositionend = (payload: unknown) => {
      isComposing.value = false
      emit('update:modelValue', extractText(payload))
    }

    const onChangetext = (payload: unknown) => {
      if (isComposing.value) return // Skip during IME composition
      emit('update:modelValue', extractText(payload))
    }

    const onFocus = (payload: unknown) => {
      emit('focus', payload)
    }

    const onBlur = (payload: unknown) => {
      emit('blur', payload)
    }

    const onSubmit = (payload: unknown) => {
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
