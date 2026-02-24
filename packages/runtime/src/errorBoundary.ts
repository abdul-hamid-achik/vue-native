import { defineComponent, ref, watch, onErrorCaptured, type PropType } from '@vue/runtime-core'

export const ErrorBoundary = defineComponent({
  name: 'ErrorBoundary',
  props: {
    onError: Function as unknown as PropType<(error: Error, info: string) => void>,
    resetKeys: {
      type: Array as PropType<any[]>,
      default: () => [],
    },
  },
  setup(props, { slots }) {
    const error = ref<Error | null>(null)
    const errorInfo = ref<string>('')

    onErrorCaptured((err: unknown, _instance, info: string) => {
      const normalizedError = err instanceof Error ? err : new Error(String(err))
      error.value = normalizedError
      errorInfo.value = info
      if (props.onError) {
        props.onError(normalizedError, info)
      }
      return false // prevent propagation to parent
    })

    function reset() {
      error.value = null
      errorInfo.value = ''
    }

    // Watch resetKeys — when any key changes, automatically reset error state
    watch(
      () => props.resetKeys,
      () => {
        if (error.value) {
          reset()
        }
      },
      { deep: true },
    )

    return () => {
      if (error.value && slots.fallback) {
        return slots.fallback({ error: error.value, errorInfo: errorInfo.value, reset })
      }
      return slots.default?.()
    }
  },
})
