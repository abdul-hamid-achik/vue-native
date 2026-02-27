# Lists Example

Demonstrates all list components in Vue Native with a contacts-like interface.

## Components Used

- **VFlatList** — Virtualized list rendering 500 items efficiently (only visible + buffer)
- **VSectionList** — Grouped list with section headers (contacts grouped by letter)
- **VList** — Basic UITableView-backed list for simple data
- **VRefreshControl** — Pull-to-refresh on section and basic lists
- **VScrollView** — Scroll container

## Composables Used

- **useHaptics** — Haptic feedback on pull-to-refresh

## Features

- VFlatList with `renderItem` function, `@endReached` for infinite scroll
- VSectionList with `#sectionHeader` and `#item` slots
- Pull-to-refresh with loading state
- Tab bar to switch between list types
- 500 contacts generated for virtualization demo

## Running

```bash
bun run dev    # Watch mode
bun run build  # Production build
```
