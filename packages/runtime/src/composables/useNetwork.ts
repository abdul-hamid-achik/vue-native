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

  // Fetch initial state
  NativeBridge.invokeNativeModule('Network', 'getStatus').then((status: NetworkState) => {
    isConnected.value = status.isConnected
    connectionType.value = status.connectionType
  }).catch(() => {})

  // Subscribe to push updates
  const unsubscribe = NativeBridge.onGlobalEvent('network:change', (payload: NetworkState) => {
    isConnected.value = payload.isConnected
    connectionType.value = payload.connectionType
  })

  onUnmounted(unsubscribe)

  return { isConnected, connectionType }
}
