# Tasks

A task management app demonstrating CRUD operations, filtering, and persistence.

> **Requires a native host.** This directory ships Vue source and build config
> only — there is no `ios/`, `android/`, or `macos/` app shell here. `bun run
> dev:ios`, `dev:android` and `dev:macos` build the JS bundle but have nothing
> to run it in. To see this app on a device or simulator:
>
> ```bash
> bunx vue-native create my-app   # scaffolds iOS + Android hosts
> ```
>
> Then copy `app/`, `vite.config.ts` and `env.d.ts` from this example over the
> scaffold's equivalents, run `bun run build` here, and open the generated
> project in Xcode or Android Studio. `vue-native create` does not scaffold a
> macOS shell yet.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VSegmentedControl, VAlertDialog, VProgressBar, VScrollView
- **Composables:** `useAsyncStorage`, `useColorScheme`, `useHaptics`, `useRouter`, `useRoute`
- **Navigation:** `createRouter`
- **Patterns:**
  - CRUD over a persisted task list (`useAsyncStorage`)
  - Filtering with a `VSegmentedControl`
  - Confirming destructive actions with `VAlertDialog`
  - A detail screen reached by route params
  - Dark mode and haptic feedback

## Key Features

- Create, edit and delete tasks
- Mark complete / incomplete
- Filter by status with a segmented control
- Confirm deletes with an alert dialog
- Persistent storage across restarts

## How to Run

```bash
cd examples/tasks
bun install
bun run dev:ios
# or: bun run dev:android
# or: bun run dev:macos
```

This directory contains Vue source only. Copy it into a generated project with
the corresponding native host before launching it.

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
