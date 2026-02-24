import { NativeBridge } from '../bridge'

// Per-key write queue to prevent concurrent access race conditions.
// Each key gets its own Promise chain; writes are serialized per key.
const writeQueues = new Map<string, Promise<void>>()

function queueWrite(key: string, fn: () => Promise<void>): Promise<void> {
  const prev = writeQueues.get(key) ?? Promise.resolve()
  const next = prev.then(fn, fn) // Continue chain even on error
  writeQueues.set(key, next)
  // Clean up completed chains
  next.then(() => {
    if (writeQueues.get(key) === next) {
      writeQueues.delete(key)
    }
  })
  return next
}

/**
 * Async key-value storage composable backed by UserDefaults.
 *
 * All operations are Promise-based and run on a background thread.
 * Write operations (setItem, removeItem) are serialized per key to
 * prevent race conditions from concurrent access.
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
    return queueWrite(key, () =>
      NativeBridge.invokeNativeModule('AsyncStorage', 'setItem', [key, value]).then(() => undefined),
    )
  }

  function removeItem(key: string): Promise<void> {
    return queueWrite(key, () =>
      NativeBridge.invokeNativeModule('AsyncStorage', 'removeItem', [key]).then(() => undefined),
    )
  }

  function getAllKeys(): Promise<string[]> {
    return NativeBridge.invokeNativeModule('AsyncStorage', 'getAllKeys', [])
  }

  function clear(): Promise<void> {
    return NativeBridge.invokeNativeModule('AsyncStorage', 'clear', []).then(() => undefined)
  }

  return { getItem, setItem, removeItem, getAllKeys, clear }
}
