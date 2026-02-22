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
    return NativeBridge.invokeNativeModule<string | null>('AsyncStorage', 'getItem', [key])
  }

  function setItem(key: string, value: string): Promise<void> {
    return NativeBridge.invokeNativeModule<void>('AsyncStorage', 'setItem', [key, value])
  }

  function removeItem(key: string): Promise<void> {
    return NativeBridge.invokeNativeModule<void>('AsyncStorage', 'removeItem', [key])
  }

  function getAllKeys(): Promise<string[]> {
    return NativeBridge.invokeNativeModule<string[]>('AsyncStorage', 'getAllKeys', [])
  }

  function clear(): Promise<void> {
    return NativeBridge.invokeNativeModule<void>('AsyncStorage', 'clear', [])
  }

  return { getItem, setItem, removeItem, getAllKeys, clear }
}
