# Task Manager

A full-featured task manager with persistent storage, dark mode, and stack navigation.

## What It Demonstrates

- **Components:** VView, VText, VButton, VInput, VScrollView, VProgressBar, VSegmentedControl, VAlertDialog
- **Composables:** `useAsyncStorage` (persistence), `useColorScheme` (dark mode), `useHaptics`
- **Navigation:** Stack navigation with `createRouter`, `useRouter`, `useRoute`
- **Patterns:** CRUD with detail screen, computed dark-mode styles, delete confirmation dialog

## Key Features

- Add, toggle, and delete tasks with priority levels (low / medium / high)
- Task detail screen with edit form (title, notes, priority)
- Persistent storage across app restarts
- Dark mode support with reactive styles
- Progress bar showing completion percentage
- Segmented filter (All / Active / Done)

## How to Run

```bash
bun install
bun run dev
```
