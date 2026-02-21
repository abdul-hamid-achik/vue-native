import { NativeBridge } from '../bridge'

/**
 * Async key-value storage composable backed by UserDefaults.
 *
 * All operations are Promise-based and run on a background thread.
 *
 * @example
 * ```ts
 * const storage = useAsyncStorage()
 * await storage.setItem('theme', 'dark')
 * const theme = await storage.getItem('theme')
 * ```
 */
export function useAsyncStorage() {
  function getItem(key: string): Promise<string | null> {
    return NativeBridge.invokeNativeModule('AsyncStorage', 'getItem', [key])
  }

  function setItem(key: string, value: string): Promise<void> {
    return NativeBridge.invokeNativeModule('AsyncStorage', 'setItem', [key, value]).then(() => undefined)
  }

  function removeItem(key: string): Promise<void> {
    return NativeBridge.invokeNativeModule('AsyncStorage', 'removeItem', [key]).then(() => undefined)
  }

  function getAllKeys(): Promise<string[]> {
    return NativeBridge.invokeNativeModule('AsyncStorage', 'getAllKeys', [])
  }

  function clear(): Promise<void> {
    return NativeBridge.invokeNativeModule('AsyncStorage', 'clear', []).then(() => undefined)
  }

  return { getItem, setItem, removeItem, getAllKeys, clear }
}
