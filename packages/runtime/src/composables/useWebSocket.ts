import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export type WebSocketStatus = 'CLOSED' | 'CONNECTING' | 'OPEN' | 'CLOSING'

export interface WebSocketOptions {
  /** Automatically connect on creation. Defaults to true. */
  autoConnect?: boolean
  /** Automatically reconnect on close. Defaults to false. */
  autoReconnect?: boolean
  /** Max reconnect attempts. Defaults to 3. */
  maxReconnectAttempts?: number
  /** Reconnect interval in ms. Defaults to 1000. */
  reconnectInterval?: number
}

let connectionCounter = 0

/**
 * Reactive WebSocket connection.
 *
 * @example
 * const { status, lastMessage, send, open, close } = useWebSocket('wss://echo.example.com')
 *
 * watch(lastMessage, (msg) => {
 *   console.log('Received:', msg)
 * })
 *
 * send('Hello!')
 * send({ type: 'ping' }) // Objects are auto-stringified
 */
export function useWebSocket(url: string, options: WebSocketOptions = {}) {
  const {
    autoConnect = true,
    autoReconnect = false,
    maxReconnectAttempts = 3,
    reconnectInterval = 1000,
  } = options

  const connectionId = `ws_${++connectionCounter}_${Date.now()}`
  const status = ref<WebSocketStatus>('CLOSED')
  const lastMessage = ref<string | null>(null)
  const error = ref<string | null>(null)

  let reconnectAttempts = 0
  let reconnectTimer: ReturnType<typeof setTimeout> | null = null

  const unsubscribers: (() => void)[] = []

  // Subscribe to native WebSocket events for this connection
  unsubscribers.push(
    NativeBridge.onGlobalEvent('websocket:open', (payload: { connectionId: string }) => {
      if (payload.connectionId !== connectionId) return
      status.value = 'OPEN'
      error.value = null
      reconnectAttempts = 0
    }),
  )

  unsubscribers.push(
    NativeBridge.onGlobalEvent('websocket:message', (payload: { connectionId: string, data: string }) => {
      if (payload.connectionId !== connectionId) return
      lastMessage.value = payload.data
    }),
  )

  unsubscribers.push(
    NativeBridge.onGlobalEvent('websocket:close', (payload: { connectionId: string, code: number, reason: string }) => {
      if (payload.connectionId !== connectionId) return
      status.value = 'CLOSED'

      // Try reconnect if enabled and wasn't a deliberate close
      if (autoReconnect && reconnectAttempts < maxReconnectAttempts && payload.code !== 1000) {
        reconnectAttempts++
        reconnectTimer = setTimeout(() => {
          open()
        }, reconnectInterval)
      }
    }),
  )

  unsubscribers.push(
    NativeBridge.onGlobalEvent('websocket:error', (payload: { connectionId: string, message: string }) => {
      if (payload.connectionId !== connectionId) return
      error.value = payload.message
    }),
  )

  function open(): void {
    if (status.value === 'OPEN' || status.value === 'CONNECTING') return
    status.value = 'CONNECTING'
    error.value = null
    NativeBridge.invokeNativeModule('WebSocket', 'connect', [url, connectionId]).catch((err: Error) => {
      status.value = 'CLOSED'
      error.value = err.message
    })
  }

  function send(data: string | object): void {
    if (status.value !== 'OPEN') return
    const message = typeof data === 'string' ? data : JSON.stringify(data)
    NativeBridge.invokeNativeModule('WebSocket', 'send', [connectionId, message]).catch((err: Error) => {
      error.value = err.message
    })
  }

  function close(code?: number, reason?: string): void {
    if (status.value === 'CLOSED' || status.value === 'CLOSING') return
    status.value = 'CLOSING'
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
      reconnectTimer = null
    }
    reconnectAttempts = maxReconnectAttempts // Prevent auto-reconnect on deliberate close
    NativeBridge.invokeNativeModule('WebSocket', 'close', [connectionId, code ?? 1000, reason ?? '']).catch(() => {
      status.value = 'CLOSED'
    })
  }

  if (autoConnect) {
    open()
  }

  onUnmounted(() => {
    if (reconnectTimer) {
      clearTimeout(reconnectTimer)
    }
    // Close connection if still open
    if (status.value === 'OPEN' || status.value === 'CONNECTING') {
      reconnectAttempts = maxReconnectAttempts // Prevent reconnect
      NativeBridge.invokeNativeModule('WebSocket', 'close', [connectionId, 1000, '']).catch(() => {})
    }
    // Unsubscribe from all events
    unsubscribers.forEach(unsub => unsub())
  })

  return { status, lastMessage, error, send, close, open }
}
