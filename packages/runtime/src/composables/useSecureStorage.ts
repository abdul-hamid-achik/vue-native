import { NativeBridge } from '../bridge'

/**
 * Secure key-value storage composable backed by Keychain (iOS) and
 * EncryptedSharedPreferences (Android).
 *
 * All operations are Promise-based and run on a background thread.
 *
 * @example
 * ```ts
 * const secureStorage = useSecureStorage()
 * await secureStorage.setItem('token', 'abc123')
 * const token = await secureStorage.getItem('token')
 * ```
 */
export function useSecureStorage() {
  function getItem(key: string): Promise<string | null> {
    return NativeBridge.invokeNativeModule('SecureStorage', 'get', [key])
  }

  function setItem(key: string, value: string): Promise<void> {
    return NativeBridge.invokeNativeModule('SecureStorage', 'set', [key, value]).then(() => undefined)
  }

  function removeItem(key: string): Promise<void> {
    return NativeBridge.invokeNativeModule('SecureStorage', 'remove', [key]).then(() => undefined)
  }

  function clear(): Promise<void> {
    return NativeBridge.invokeNativeModule('SecureStorage', 'clear', []).then(() => undefined)
  }

  return { getItem, setItem, removeItem, clear }
}
