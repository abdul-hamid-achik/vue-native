import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export type ConnectionType = 'wifi' | 'cellular' | 'ethernet' | 'none' | 'unknown'

export interface NetworkState {
  isConnected: boolean
  connectionType: ConnectionType
}

/**
 * Reactive network connectivity status.
 * Subscribes to native NWPathMonitor push events.
 *
 * @example
 * const { isConnected, connectionType } = useNetwork()
 */
export function useNetwork() {
  const isConnected = ref(true)
  const connectionType = ref<ConnectionType>('unknown')
  const error = ref<string | null>(null)

  // Fetch initial state
  NativeBridge.invokeNativeModule<NetworkState>('Network', 'getStatus').then(status => {
    isConnected.value = status.isConnected
    connectionType.value = status.connectionType
  }).catch((e: unknown) => {
    error.value = e instanceof Error ? e.message : String(e)
  })

  // Subscribe to push updates
  const unsubscribe = NativeBridge.onGlobalEvent<NetworkState>('network:change', payload => {
    isConnected.value = payload.isConnected
    connectionType.value = payload.connectionType
  })

  onUnmounted(unsubscribe)

  return { isConnected, connectionType, error }
}
