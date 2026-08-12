/**
 * Per-key write serialization shared by the storage composables.
 *
 * Each storage backend gets its own queue instance so identical key names in
 * different backends never serialize against each other.
 */
export function createWriteQueue() {
  const writeQueues = new Map<string, Promise<void>>()

  return function queueWrite(key: string, fn: () => Promise<void>): Promise<void> {
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
}
