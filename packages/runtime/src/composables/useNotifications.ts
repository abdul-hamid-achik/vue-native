import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface LocalNotification {
  id?: string
  title: string
  body: string
  delay?: number
  sound?: 'default' | null
  badge?: number
  data?: Record<string, any>
}

export interface NotificationPayload {
  id: string
  title: string
  body: string
  data: Record<string, any>
  action?: string
}

export interface PushNotificationPayload {
  title: string
  body: string
  data: Record<string, any>
  remote: true
}

/**
 * Local and push notification management.
 *
 * @example
 * // Local notifications
 * const { requestPermission, scheduleLocal, onNotification } = useNotifications()
 * await requestPermission()
 * await scheduleLocal({ title: 'Reminder', body: 'Don\'t forget!', delay: 5 })
 *
 * // Push notifications
 * const { registerForPush, getToken, onPushReceived } = useNotifications()
 * await registerForPush()
 * const token = await getToken()
 * onPushReceived((notification) => {
 *   console.log('Push:', notification.title, notification.body)
 * })
 */
export function useNotifications() {
  const isGranted = ref(false)
  const pushToken = ref<string | null>(null)

  async function requestPermission(): Promise<boolean> {
    const granted: boolean = await NativeBridge.invokeNativeModule('Notifications', 'requestPermission')
    isGranted.value = granted
    return granted
  }

  async function getPermissionStatus(): Promise<string> {
    return NativeBridge.invokeNativeModule('Notifications', 'getPermissionStatus')
  }

  async function scheduleLocal(notification: LocalNotification): Promise<string> {
    return NativeBridge.invokeNativeModule('Notifications', 'scheduleLocal', [notification])
  }

  async function cancel(id: string): Promise<void> {
    return NativeBridge.invokeNativeModule('Notifications', 'cancel', [id])
  }

  async function cancelAll(): Promise<void> {
    return NativeBridge.invokeNativeModule('Notifications', 'cancelAll')
  }

  function onNotification(handler: (payload: NotificationPayload) => void): () => void {
    const unsubscribe = NativeBridge.onGlobalEvent('notification:received', handler)
    onUnmounted(unsubscribe)
    return unsubscribe
  }

  // ---------------------------------------------------------------------------
  // Push notifications
  // ---------------------------------------------------------------------------

  /**
   * Register for remote push notifications.
   * On iOS, this triggers the APNS registration flow.
   * On Android, FCM auto-registers; this is a no-op for API parity.
   */
  async function registerForPush(): Promise<void> {
    await NativeBridge.invokeNativeModule('Notifications', 'registerForPush')
  }

  /**
   * Get the device push token (APNS token on iOS, FCM token on Android).
   * Returns null if not yet registered.
   */
  async function getToken(): Promise<string | null> {
    return NativeBridge.invokeNativeModule('Notifications', 'getToken')
  }

  /**
   * Listen for the push token event (fired when token is first received or refreshed).
   */
  function onPushToken(handler: (token: string) => void): () => void {
    const unsubscribe = NativeBridge.onGlobalEvent('push:token', (payload: { token: string }) => {
      pushToken.value = payload.token
      handler(payload.token)
    })
    onUnmounted(unsubscribe)
    return unsubscribe
  }

  /**
   * Listen for incoming remote push notifications.
   */
  function onPushReceived(handler: (payload: PushNotificationPayload) => void): () => void {
    const unsubscribe = NativeBridge.onGlobalEvent('push:received', handler)
    onUnmounted(unsubscribe)
    return unsubscribe
  }

  return {
    // Local
    isGranted, requestPermission, getPermissionStatus,
    scheduleLocal, cancel, cancelAll, onNotification,
    // Push
    pushToken, registerForPush, getToken, onPushToken, onPushReceived,
  }
}
