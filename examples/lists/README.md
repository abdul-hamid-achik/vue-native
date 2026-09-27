# Lists

Comprehensive list examples demonstrating VList, VFlatList, and VSectionList.

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

- **Components:** VView, VText, VButton, VFlatList, VSectionList, VList, VSafeArea
- **Composables:** `useHaptics`
- **Patterns:**
  - `VFlatList` — 500 virtualized rows with the `:item-height` fast path and `@end-reached` pagination
  - `VSectionList` — grouped data with sticky `#sectionHeader` rows
  - `VList` — data-driven rows through `#item` (it has no default slot, so `v-for` children render nothing)
  - Each list is the scrolling root (`flex: 1`); none is nested inside a `VScrollView`, which would defeat virtualization and risk a re-entrant layout loop
  - Header content supplied through each list's own `#header` slot

Pull-to-refresh is not demonstrated. `VRefreshControl` only attaches inside
`VScrollView` on iOS (`VScrollViewFactory`); `VListFactory` /
`VSectionListFactory` treat every child as a table row, so a refresh control
inside a list becomes a row instead of an indicator. These lists use an explicit
Refresh button in their `#header` slot instead.

## Key Features

- `VFlatList` with 500 virtualized contacts and load-more on `@end-reached`
- `VSectionList` grouped alphabetically with sticky section headers
- `VList` rendering a small data-driven list
- A tab bar that switches between the three
- Each list owns the scroll position (no nested `VScrollView`)

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
