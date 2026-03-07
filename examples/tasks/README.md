# Tasks

A task management app demonstrating CRUD operations, filtering, and persistence.

## What It Demonstrates

- **Components:** VList, VInput, VButton, VSwitch, VView, VText, VModal
- **Composables:** `useAsyncStorage`, `useHaptics`
- **Patterns:**
  - CRUD operations
  - Filtering and sorting
  - Modal dialogs
  - Bulk operations

## Key Features

- Create/edit/delete tasks
- Mark complete/incomplete
- Filter by status
- Search functionality
- Persistent storage

## How to Run

```bash
cd examples/tasks
bun install
bun vue-native dev
```

## Key Concepts

### Task Management

```typescript
interface Task {
  id: string
  title: string
  completed: boolean
  dueDate?: Date
}

const tasks = ref<Task[]>([])

function addTask(title: string) {
  tasks.value.push({
    id: Date.now().toString(),
    title,
    completed: false,
  })
}
```

### Filtering

```typescript
const filter = ref<'all' | 'active' | 'completed'>('all')

const filteredTasks = computed(() => {
  switch (filter.value) {
    case 'active': return tasks.value.filter(t => !t.completed)
    case 'completed': return tasks.value.filter(t => t.completed)
    default: return tasks.value
  }
})
```

## Learn More

- [useAsyncStorage](../../docs/src/composables/useAsyncStorage.md)
- [Computed Properties](../../docs/src/guide/components.md#computed)
- [VModal Component](../../docs/src/components/VModal.md)
