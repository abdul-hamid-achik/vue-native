# Todo

A todo list app with persistent storage using AsyncStorage.

## What It Demonstrates

- **Components:** VScrollView, VView, VText, VButton, VInput
- **Composables:** `useAsyncStorage` (persistence across app restarts)
- **Patterns:** CRUD operations, `watch` for auto-save, `onMounted` for data loading, filter tabs

## Key Features

- Add, toggle, and delete todos
- Filter by All / Active / Done
- Automatic persistence via AsyncStorage
- Remaining count display

## How to Run

```bash
bun install
bun run dev
```
