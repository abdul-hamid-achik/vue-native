import {
  defineComponent,
  h,
  ref,
  onMounted,
  shallowRef,
  watch,
  provide,
  inject,
  type Component,
  type ShallowRef,
} from '@vue/runtime-core'

export interface AsyncComponentOptions {
  loader: () => Promise<Component>
  loadingComponent?: Component
  errorComponent?: Component
  delay?: number
  timeout?: number
  onError?: (error: Error) => void
}

interface SuspenseContext {
  hasError: ShallowRef<boolean>
  error: ShallowRef<Error | null>
  pendingCount: ShallowRef<number>
  resolve: () => void
  reject: (error: Error) => void
}

const suspenseContextKey = Symbol('suspense')

export const VSuspense = defineComponent({
  name: 'Suspense',
  props: {
    timeout: { type: Number, default: 30000 },
  },
  setup(_props, { slots }) {
    const hasError = ref(false)
    const error = shallowRef<Error | null>(null)
    const pendingCount = ref(0)

    const context: SuspenseContext = {
      hasError,
      error,
      pendingCount,
      resolve: () => {
        pendingCount.value--
      },
      reject: (err: Error) => {
        hasError.value = true
        error.value = err
      },
    }

    provide(suspenseContextKey, context)

    return () => {
      if (hasError.value) {
        return slots.fallback?.({ error: error.value }) ?? null
      }

      const defaultSlots = slots.default?.() ?? []
      return defaultSlots
    }
  },
})

export function defineAsyncComponent(options: AsyncComponentOptions): Component {
  const {
    loader,
    loadingComponent,
    errorComponent,
    delay = 200,
    onError,
  } = options

  let resolvedComponent: Component | undefined
  let loading = false

  const AsyncComponent = defineComponent({
    name: 'AsyncComponentWrapper',
    setup(_props, { slots }) {
      const componentRef = shallowRef<Component | null>(null)
      const errorRef = shallowRef<Error | null>(null)
      const showLoadingRef = ref(false)

      const suspenseContext = inject<SuspenseContext | null>(suspenseContextKey, null)

      let loadingDelayTimeout: ReturnType<typeof setTimeout> | null = null

      async function load() {
        if (resolvedComponent) {
          componentRef.value = resolvedComponent
          return
        }

        loading = true

        // Increment suspense pending count
        if (suspenseContext) {
          suspenseContext.pendingCount.value++
        }

        // Show loading after delay
        loadingDelayTimeout = setTimeout(() => {
          if (loading && !resolvedComponent) {
            showLoadingRef.value = true
          }
        }, delay)

        try {
          const loaded = await loader()
          resolvedComponent = loaded
          componentRef.value = loaded
          errorRef.value = null
        } catch (err) {
          const error = err instanceof Error ? err : new Error(String(err))
          errorRef.value = error
          onError?.(error)
          suspenseContext?.reject(error)
        } finally {
          loading = false
          if (loadingDelayTimeout) {
            clearTimeout(loadingDelayTimeout)
          }
          showLoadingRef.value = false
          suspenseContext?.resolve()
        }
      }

      onMounted(() => {
        load()
      })

      return () => {
        if (errorRef.value) {
          if (errorComponent) {
            return h(errorComponent, { error: errorRef.value })
          }
          return slots.fallback?.({ error: errorRef.value }) ?? null
        }

        if (showLoadingRef.value && loadingComponent) {
          return h(loadingComponent)
        }

        if (componentRef.value) {
          return h(componentRef.value, slots.default?.())
        }

        return null
      }
    },
  })

  return AsyncComponent
}

export function onSuspenseError(callback: (error: Error) => void) {
  const context = inject<SuspenseContext | null>(suspenseContextKey, null)
  if (context) {
    watch(context.error, (err: Error | null) => {
      if (err) callback(err)
    })
  }
}

export default VSuspense
