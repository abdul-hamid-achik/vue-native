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

/**
 * Local notification scheduling and permission management.
 *
 * @example
 * const { requestPermission, scheduleLocal, onNotification } = useNotifications()
 * await requestPermission()
 * await scheduleLocal({ title: 'Reminder', body: 'Don\'t forget!', delay: 5 })
 */
export function useNotifications() {
  const isGranted = ref(false)

  async function requestPermission(): Promise<boolean> {
    const granted = await NativeBridge.invokeNativeModule<boolean>('Notifications', 'requestPermission')
    isGranted.value = granted
    return granted
  }

  async function getPermissionStatus(): Promise<string> {
    return NativeBridge.invokeNativeModule<string>('Notifications', 'getPermissionStatus')
  }

  async function scheduleLocal(notification: LocalNotification): Promise<string> {
    return NativeBridge.invokeNativeModule<string>('Notifications', 'scheduleLocal', [notification])
  }

  async function cancel(id: string): Promise<void> {
    return NativeBridge.invokeNativeModule<void>('Notifications', 'cancel', [id])
  }

  async function cancelAll(): Promise<void> {
    return NativeBridge.invokeNativeModule<void>('Notifications', 'cancelAll')
  }

  function onNotification(handler: (payload: NotificationPayload) => void): () => void {
    const unsubscribe = NativeBridge.onGlobalEvent<NotificationPayload>('notification:received', handler)
    onUnmounted(unsubscribe)
    return unsubscribe
  }

  return { isGranted, requestPermission, getPermissionStatus, scheduleLocal, cancel, cancelAll, onNotification }
}
