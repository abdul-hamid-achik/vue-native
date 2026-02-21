import { NativeBridge } from '../bridge'

export type Permission =
  | 'camera'
  | 'microphone'
  | 'photos'
  | 'location'
  | 'locationAlways'
  | 'notifications'

export type PermissionStatus =
  | 'granted'
  | 'denied'
  | 'restricted'
  | 'limited'
  | 'notDetermined'

/**
 * Check and request runtime permissions.
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
