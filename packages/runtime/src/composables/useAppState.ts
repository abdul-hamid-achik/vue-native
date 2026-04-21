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

  // Fetch initial state
  NativeBridge.invokeNativeModule('AppState', 'getState').then((s: string) => {
    state.value = s as AppStateStatus
  }).catch((err: unknown) => {
    if (__DEV__) console.warn('[vue-native] AppState.getState failed:', err)
  })

  const unsubscribe = NativeBridge.onGlobalEvent('appState:change', (payload: { state: AppStateStatus }) => {
    state.value = payload.state
  })

  onUnmounted(unsubscribe)

  return { state }
}
