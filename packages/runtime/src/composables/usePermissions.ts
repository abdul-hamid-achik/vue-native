import { NativeBridge } from '../bridge'

export type Permission =
  | 'camera'
  | 'microphone'
  | 'photos'
  | 'location'
  | 'locationAlways'
  | 'notifications'
  | 'contacts'
  | 'calendar'

export type PermissionStatus =
  | 'granted'
  | 'denied'
  | 'restricted'
  | 'limited'
  | 'notDetermined'

/**
 * Check and request runtime permissions.
 *
 * 'contacts' and 'calendar' flow through the same native Permissions module
 * as every other domain; `useContacts().requestAccess()` and
 * `useCalendar().requestAccess()` remain as boolean-returning conveniences.
 * Android reports only granted/denied/notDetermined for contacts/calendar —
 * restricted/limited are Apple-platform statuses.
 *
 * @example
 * const { request, check } = usePermissions()
 * const status = await request('camera')
 * if (status === 'granted') { ... }
 */
export function usePermissions() {
  async function request(permission: Permission): Promise<PermissionStatus> {
    return NativeBridge.invokeNativeModule('Permissions', 'request', [permission])
  }

  async function check(permission: Permission): Promise<PermissionStatus> {
    return NativeBridge.invokeNativeModule('Permissions', 'check', [permission])
  }

  return { request, check }
}
