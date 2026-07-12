# Todo App

A simple todo list demonstrating CRUD operations, local storage, and list rendering.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VList, VSwitch
- **Composables:** `useAsyncStorage` for persistence, `useHaptics` for feedback
- **Patterns:**
  - List rendering with `v-for`
  - Two-way binding with `v-model`
  - Persistent storage
  - Toggle completion state

## Key Features

- Add new todos
- Mark todos as complete/incomplete
- Delete todos
- Persistent storage (survives app restart)
- Clean, minimal UI

## How to Run

```bash
cd examples/todo
bun install
bun run dev:ios
```

Generate the included iOS project with `cd ios && xcodegen generate`, then open
`ios/VueNativeTodo.xcodeproj`. To use the Vue source on Android, run
`bun run dev:android` after copying it into a scaffold with an Android host.

## Key Concepts

### Persistent Storage

Uses `useAsyncStorage` to save todos:

```typescript
const { getItem, setItem } = useAsyncStorage()

// Load on mount
const saved = await getItem('todos')
todos.value = JSON.parse(saved) || []

// Save on change
watch(todos, async () => {
  await setItem('todos', JSON.stringify(todos.value))
}, { deep: true })
```

### List Rendering

Renders todos with `v-for`:

```vue
<VList
  :data="todos"
  :renderItem="(todo) => (
    <VView>
      <VText>{todo.text}</VText>
      <VSwitch v-model={todo.completed} />
    </VView>
  )}
/>
```

### Toggle Completion

Simple toggle with haptic feedback:

```typescript
function toggle(todo: Todo) {
  todo.completed = !todo.completed
  haptics.selection()
}
```

## File Structure

```
examples/todo/
├── app/
│   ├── main.ts
│   └── App.vue
├── ios/                 # XcodeGen iOS app specification
├── vite.config.ts
└── package.json
```

## Learn More

- [VList Component](../../docs/src/components/VList.md)
- [useAsyncStorage](../../docs/src/composables/useAsyncStorage.md)
- [State Persistence](../../docs/src/guide/state-persistence.md)

## Try This

Experiment with:
1. Add todo filtering (all/active/completed)
2. Add due dates
3. Add categories/tags
4. Implement search functionality
5. Add swipe-to-delete gesture
