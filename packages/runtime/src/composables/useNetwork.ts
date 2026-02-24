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

  // Track when the most recent event update occurred so the initial
  // async getStatus response does not overwrite a fresher event.
  let lastEventTime = 0

  // Subscribe to push updates first so we never miss an event.
  const unsubscribe = NativeBridge.onGlobalEvent('network:change', (payload: NetworkState) => {
    lastEventTime = Date.now()
    isConnected.value = payload.isConnected
    connectionType.value = payload.connectionType
  })

  // Fetch initial state, but skip if a more recent event already arrived.
  const initTime = Date.now()
  NativeBridge.invokeNativeModule('Network', 'getStatus').then((status: NetworkState) => {
    if (lastEventTime <= initTime) {
      isConnected.value = status.isConnected
      connectionType.value = status.connectionType
    }
  }).catch(() => {})

  onUnmounted(unsubscribe)

  return { isConnected, connectionType }
}
