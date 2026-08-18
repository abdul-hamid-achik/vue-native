import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

export interface ExecuteResult {
  rowsAffected: number
  insertId?: number
}

export type Row = Record<string, unknown>

export interface TransactionContext {
  execute: (sql: string, params?: unknown[]) => Promise<ExecuteResult>
  query: <T extends Row = Row>(sql: string, params?: unknown[]) => Promise<T[]>
}

// ─── useDatabase composable ───────────────────────────────────────────────

/**
 * Open-instance count per database name. Several components commonly share a
 * name ('default'); the native connection is only closed when the last open
 * instance closes or unmounts, so one unmount cannot pull the connection out
 * from under the others.
 */
const openInstanceCounts = new Map<string, number>()

/** @internal Reset the shared open-instance counts. Used by tests. */
export function __resetDatabaseInstanceCounts(): void {
  openInstanceCounts.clear()
}

function releaseInstance(name: string): boolean {
  const count = openInstanceCounts.get(name) ?? 0
  if (count <= 1) {
    openInstanceCounts.delete(name)
    return true
  }
  openInstanceCounts.set(name, count - 1)
  return false
}

/**
 * Reactive SQLite database access. Opens a named database on first use
 * and auto-closes on component unmount.
 *
 * @param name - Database name (defaults to "default"). Stored as `<name>.sqlite`.
 *
 * @example
 * const db = useDatabase('myapp')
 *
 * // Create table
 * await db.execute('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)')
 *
 * // Insert
 * const { insertId } = await db.execute('INSERT INTO users (name) VALUES (?)', ['Alice'])
 *
 * // Query
 * const users = await db.query<{ id: number; name: string }>('SELECT * FROM users')
 *
 * // Transaction
 * await db.transaction(async ({ execute }) => {
 *   await execute('INSERT INTO users (name) VALUES (?)', ['Bob'])
 *   await execute('INSERT INTO users (name) VALUES (?)', ['Charlie'])
 * })
 */
export function useDatabase(name: string = 'default') {
  const isOpen = ref(false)
  let opened = false
  let openPromise: Promise<void> | null = null

  async function ensureOpen(): Promise<void> {
    if (opened) return
    if (!openPromise) {
      openPromise = (async () => {
        await NativeBridge.invokeNativeModule('Database', 'open', [name])
        if (!opened) {
          opened = true
          isOpen.value = true
          openInstanceCounts.set(name, (openInstanceCounts.get(name) ?? 0) + 1)
        }
      })()
    }
    try {
      await openPromise
    } finally {
      if (opened) {
        openPromise = null
      }
    }
  }

  async function execute(sql: string, params?: unknown[]): Promise<ExecuteResult> {
    await ensureOpen()
    return NativeBridge.invokeNativeModule('Database', 'execute', [name, sql, params ?? []])
  }

  async function query<T extends Row = Row>(sql: string, params?: unknown[]): Promise<T[]> {
    await ensureOpen()
    return NativeBridge.invokeNativeModule('Database', 'query', [name, sql, params ?? []])
  }

  async function transaction(callback: (ctx: TransactionContext) => Promise<void>): Promise<void> {
    await ensureOpen()

    // Use explicit SQL transaction control so ALL operations (reads and writes)
    // run within the same database transaction, ensuring proper isolation.
    await NativeBridge.invokeNativeModule('Database', 'execute', [name, 'BEGIN TRANSACTION', []])
    try {
      const ctx: TransactionContext = {
        execute: async (sql: string, params?: unknown[]): Promise<ExecuteResult> => {
          return NativeBridge.invokeNativeModule('Database', 'execute', [name, sql, params ?? []])
        },
        query: async <T extends Row = Row>(sql: string, params?: unknown[]): Promise<T[]> => {
          return NativeBridge.invokeNativeModule('Database', 'query', [name, sql, params ?? []])
        },
      }

      await callback(ctx)
      await NativeBridge.invokeNativeModule('Database', 'execute', [name, 'COMMIT', []])
    } catch (err) {
      // Best-effort rollback; suppress rollback errors to surface the original failure
      await NativeBridge.invokeNativeModule('Database', 'execute', [name, 'ROLLBACK', []]).catch((err: unknown) => {
        if (__DEV__) console.warn('[vue-native] Database ROLLBACK failed:', err)
      })
      throw err
    }
  }

  async function close(): Promise<void> {
    if (!opened) return
    opened = false
    isOpen.value = false
    // Only the last open instance actually closes the shared native connection.
    if (releaseInstance(name)) {
      await NativeBridge.invokeNativeModule('Database', 'close', [name])
    }
  }

  onUnmounted(() => {
    if (opened) {
      opened = false
      isOpen.value = false
      if (releaseInstance(name)) {
        NativeBridge.invokeNativeModule('Database', 'close', [name]).catch((err: unknown) => {
          if (__DEV__) console.warn('[vue-native] Database.close failed:', err)
        })
      }
    }
  })

  return { execute, query, transaction, close, isOpen }
}
