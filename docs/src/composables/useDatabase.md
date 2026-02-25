# useDatabase

Reactive SQLite database access. Opens a named database on first use and auto-closes when the component unmounts.

## Usage

```vue
<script setup>
import { useDatabase } from '@thelacanians/vue-native-runtime'

const db = useDatabase('myapp')

async function setup() {
  await db.execute('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)')
  const users = await db.query('SELECT * FROM users')
  console.log(users)
}
</script>
```

## API

```ts
useDatabase(name?: string): {
  execute: (sql: string, params?: any[]) => Promise<ExecuteResult>
  query: <T>(sql: string, params?: any[]) => Promise<T[]>
  transaction: (callback: (ctx: TransactionContext) => Promise<void>) => Promise<void>
  close: () => Promise<void>
  isOpen: Ref<boolean>
}
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `string` | `'default'` | Database name. Stored as `<name>.sqlite` on disk. |

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `execute` | `(sql, params?) => Promise<ExecuteResult>` | Execute a write statement (INSERT, UPDATE, DELETE, CREATE, etc.). |
| `query` | `<T>(sql, params?) => Promise<T[]>` | Execute a read query. Returns an array of row objects. |
| `transaction` | `(callback) => Promise<void>` | Run multiple operations in a single transaction. Rolls back on error. |
| `close` | `() => Promise<void>` | Manually close the database connection. |
| `isOpen` | `Ref<boolean>` | Whether the database is currently open. |

**ExecuteResult:**

| Property | Type | Description |
|----------|------|-------------|
| `rowsAffected` | `number` | Number of rows affected by the statement. |
| `insertId` | `number?` | The row ID of the last inserted row (for INSERT statements). |

**TransactionContext:**

The callback passed to `transaction()` receives a context object with `execute` and `query` methods that run within the same database transaction.

## Parameterized Queries

Always use parameterized queries to prevent SQL injection:

```ts
// Good — parameterized
await db.execute('INSERT INTO users (name, email) VALUES (?, ?)', ['Alice', 'alice@example.com'])
await db.query('SELECT * FROM users WHERE name = ?', ['Alice'])

// Bad — string interpolation (SQL injection risk)
await db.execute(`INSERT INTO users (name) VALUES ('${name}')`)
```

## Transactions

Use `transaction()` to group multiple operations atomically. If any operation fails, all changes are rolled back:

```ts
await db.transaction(async ({ execute, query }) => {
  await execute('INSERT INTO accounts (name, balance) VALUES (?, ?)', ['Alice', 1000])
  await execute('INSERT INTO accounts (name, balance) VALUES (?, ?)', ['Bob', 500])

  const accounts = await query('SELECT * FROM accounts')
  console.log('Created accounts:', accounts.length)
})
```

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | SQLite via native Database module. |
| Android | SQLite via native Database module. |

## Example

```vue
<script setup>
import { ref, onMounted } from '@thelacanians/vue-native-runtime'
import { useDatabase } from '@thelacanians/vue-native-runtime'

interface Todo {
  id: number
  title: string
  done: number
}

const db = useDatabase('todos')
const todos = ref<Todo[]>([])

onMounted(async () => {
  await db.execute(`
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      done INTEGER DEFAULT 0
    )
  `)
  await loadTodos()
})

async function loadTodos() {
  todos.value = await db.query<Todo>('SELECT * FROM todos ORDER BY id DESC')
}

async function addTodo(title: string) {
  await db.execute('INSERT INTO todos (title) VALUES (?)', [title])
  await loadTodos()
}

async function toggleTodo(id: number, done: boolean) {
  await db.execute('UPDATE todos SET done = ? WHERE id = ?', [done ? 1 : 0, id])
  await loadTodos()
}

async function deleteTodo(id: number) {
  await db.execute('DELETE FROM todos WHERE id = ?', [id])
  await loadTodos()
}
</script>

<template>
  <VView :style="{ flex: 1, padding: 20 }">
    <VText :style="{ fontSize: 24, fontWeight: 'bold', marginBottom: 16 }">
      Todos ({{ todos.length }})
    </VText>

    <VView v-for="todo in todos" :key="todo.id" :style="{ flexDirection: 'row', alignItems: 'center', marginBottom: 8 }">
      <VCheckbox :value="!!todo.done" @change="toggleTodo(todo.id, !todo.done)" />
      <VText :style="{ flex: 1, marginLeft: 8, textDecorationLine: todo.done ? 'line-through' : 'none' }">
        {{ todo.title }}
      </VText>
    </VView>
  </VView>
</template>
```

## Notes

- The database is opened lazily on the first `execute` or `query` call, not when `useDatabase()` is called.
- The database is automatically closed when the owning component unmounts. Call `close()` manually if you need to close it earlier.
- Database files persist across app launches. Use `DROP TABLE` or delete the file to clear data.
- Transaction isolation uses `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK` under the hood.
