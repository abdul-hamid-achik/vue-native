# Lists

Comprehensive list examples demonstrating VList, VFlatList, and VSectionList.

## What It Demonstrates

- **Components:** VList, VFlatList, VSectionList, VView, VText, VImage
- **Composables:** `useHaptics` for pull-to-refresh
- **Patterns:**
  - Virtualized lists
  - Sectioned lists
  - Pull-to-refresh
  - Endless scrolling
  - List item optimization

## Key Features

- Basic list rendering
- Sectioned list with headers
- Pull-to-refresh
- Load more on scroll
- Swipe actions

## How to Run

```bash
cd examples/lists
bun install
bun run dev:ios
# or: bun run dev:android
# or: bun run dev:macos
```

This directory contains Vue source only. Copy it into a generated project with
the corresponding native host before launching it.

## Key Concepts

### VList Basic Usage

```vue
<VList
  :data="items"
  :renderItem="(item) => (
    <VView>
      <VText>{item.name}</VText>
    </VView>
  )}
/>
```

### Pull-to-Refresh

```vue
<VList
  :data="items"
  :renderItem={renderItem}
  @refresh={handleRefresh}
/>
```

### Endless Scrolling

```vue
<VList
  :data="items"
  :renderItem={renderItem}
  @endReached={loadMore}
  :endReachedThreshold={0.5}
/>
```

## Learn More

- [VList Component](../../docs/src/components/VList.md)
- [VFlatList Component](../../docs/src/components/VFlatList.md)
- [VSectionList Component](../../docs/src/components/VSectionList.md)
