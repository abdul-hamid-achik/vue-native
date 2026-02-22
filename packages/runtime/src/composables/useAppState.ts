import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export type AppStateStatus = 'active' | 'inactive' | 'background' | 'unknown'

/**
 * Reactive app foreground/background state.
 * Subscribes to native UIApplication lifecycle notifications.
 *
 * @example
 * const { state } = useAppState()
 * watch(state, s => { if (s === 'background') saveData() })
 */
export function useAppState() {
  const state = ref<AppStateStatus>('active')
  const error = ref<string | null>(null)

  // Fetch initial state
  NativeBridge.invokeNativeModule<string>('AppState', 'getState').then(s => {
    state.value = s as AppStateStatus
  }).catch((e: unknown) => {
    error.value = e instanceof Error ? e.message : String(e)
  })

  const unsubscribe = NativeBridge.onGlobalEvent<{ state: AppStateStatus }>('appState:change', payload => {
    state.value = payload.state
  })

  onUnmounted(unsubscribe)

  return { state, error }
}
