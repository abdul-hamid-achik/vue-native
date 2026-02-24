import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

export interface ExecuteResult {
  rowsAffected: number
  insertId?: number
}

export type Row = Record<string, any>

export interface TransactionContext {
  execute: (sql: string, params?: any[]) => Promise<ExecuteResult>
  query: <T extends Row = Row>(sql: string, params?: any[]) => Promise<T[]>
}

// ─── useDatabase composable ───────────────────────────────────────────────

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

  async function ensureOpen(): Promise<void> {
    if (opened) return
    await NativeBridge.invokeNativeModule('Database', 'open', [name])
    opened = true
    isOpen.value = true
  }

  async function execute(sql: string, params?: any[]): Promise<ExecuteResult> {
    await ensureOpen()
    return NativeBridge.invokeNativeModule('Database', 'execute', [name, sql, params ?? []])
  }

  async function query<T extends Row = Row>(sql: string, params?: any[]): Promise<T[]> {
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
        execute: async (sql: string, params?: any[]): Promise<ExecuteResult> => {
          return NativeBridge.invokeNativeModule('Database', 'execute', [name, sql, params ?? []])
        },
        query: async <T extends Row = Row>(sql: string, params?: any[]): Promise<T[]> => {
          return NativeBridge.invokeNativeModule('Database', 'query', [name, sql, params ?? []])
        },
      }

      await callback(ctx)
      await NativeBridge.invokeNativeModule('Database', 'execute', [name, 'COMMIT', []])
    } catch (err) {
      // Best-effort rollback; suppress rollback errors to surface the original failure
      await NativeBridge.invokeNativeModule('Database', 'execute', [name, 'ROLLBACK', []]).catch(() => {})
      throw err
    }
  }

  async function close(): Promise<void> {
    if (!opened) return
    await NativeBridge.invokeNativeModule('Database', 'close', [name])
    opened = false
    isOpen.value = false
  }

  onUnmounted(() => {
    if (opened) {
      NativeBridge.invokeNativeModule('Database', 'close', [name]).catch(() => {})
      opened = false
      isOpen.value = false
    }
  })

  return { execute, query, transaction, close, isOpen }
}
