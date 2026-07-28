# Theming

Vue Native ships a small, reactive theme system for consistent design tokens and
dark-mode support. It is built on Vue's `provide` / `inject`, so theme values
stay reactive and are scoped to the component tree — no global singletons.

The three building blocks:

| API | Purpose |
|-----|---------|
| `createTheme` | Defines light/dark token sets; returns a `<ThemeProvider>` component and a `useTheme` composable. |
| `createDynamicStyleSheet` | Builds a stylesheet that re-evaluates whenever the active theme changes. |
| `useColorScheme` | Reactively tracks the **system** light/dark setting. |

A complete working app lives in [`examples/theming/`](https://github.com/abdul-hamid-achik/vue-native/tree/main/examples/theming).

## 1. Define a theme

Call `createTheme` once in a dedicated module. It takes a `light` and a `dark`
variant of the same token shape and returns a `ThemeProvider` plus a `useTheme`
hook bound to that definition:

```ts
// theme.ts
import { createTheme } from '@thelacanians/vue-native-runtime'

export const { ThemeProvider, useTheme } = createTheme({
  light: {
    colors: {
      background: '#F2F2F7',
      surface: '#FFFFFF',
      text: '#1C1C1E',
      textSecondary: '#8E8E93',
      primary: '#007AFF',
      error: '#FF3B30',
    },
    spacing: { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 },
    borderRadius: { sm: 6, md: 10, lg: 16 },
    fontSize: { caption: 12, body: 16, title: 20, heading: 28 },
  },
  dark: {
    colors: {
      background: '#000000',
      surface: '#1C1C1E',
      text: '#F5F5F7',
      textSecondary: '#98989D',
      primary: '#0A84FF',
      error: '#FF453A',
    },
    spacing: { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 },
    borderRadius: { sm: 6, md: 10, lg: 16 },
    fontSize: { caption: 12, body: 16, title: 20, heading: 28 },
  },
})
```

The token shape is entirely yours — `colors`, `spacing`, `borderRadius`, and
`fontSize` above are just conventions. Both variants must have the same keys.

## 2. Provide the theme at the root

Wrap your app (or any subtree) with `<ThemeProvider>`. It accepts an optional
`initial-color-scheme` prop (`'light'` or `'dark'`, defaults to `'light'`):

```vue
<!-- App.vue -->
<script setup lang="ts">
import { ThemeProvider } from './theme'
import HomeScreen from './HomeScreen.vue'
</script>

<template>
  <ThemeProvider initial-color-scheme="light">
    <HomeScreen />
  </ThemeProvider>
</template>
```

## 3. Consume tokens with `useTheme`

Inside any descendant, `useTheme()` returns the reactive theme plus controls:

```ts
const { theme, colorScheme, toggleColorScheme, setColorScheme } = useTheme()
```

| Property | Type | Description |
|----------|------|-------------|
| `theme` | `ComputedRef<T>` | The resolved token set for the active scheme. |
| `colorScheme` | `Ref<'light' \| 'dark'>` | The currently active scheme. |
| `toggleColorScheme` | `() => void` | Flip between light and dark. |
| `setColorScheme` | `(scheme: 'light' \| 'dark') => void` | Set a specific scheme. |

Calling `useTheme()` outside a `<ThemeProvider>` throws — wrap your root first.

## 4. Theme-aware styles with `createDynamicStyleSheet`

`createDynamicStyleSheet` takes the reactive `theme` and a factory function, and
returns a `ComputedRef` stylesheet that re-computes whenever the theme changes.
No manual `watch` needed:

```vue
<script setup lang="ts">
import { createDynamicStyleSheet } from '@thelacanians/vue-native-runtime'
import { useTheme } from './theme'

const { theme, colorScheme, toggleColorScheme } = useTheme()

const styles = createDynamicStyleSheet(theme, (t) => ({
  container: {
    flex: 1,
    backgroundColor: t.colors.background,
    padding: t.spacing.lg,
  },
  title: {
    fontSize: t.fontSize.heading,
    fontWeight: 'bold',
    color: t.colors.text,
  },
  card: {
    backgroundColor: t.colors.surface,
    borderRadius: t.borderRadius.lg,
    padding: t.spacing.md,
  },
}))
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.title">{{ colorScheme }} mode</VText>
    <VButton :onPress="toggleColorScheme">
      <VText>Toggle theme</VText>
    </VButton>
  </VView>
</template>
```

`styles` is a `ComputedRef`, so it is auto-unwrapped in the template — bind
`styles.container`, not `styles.value.container`. In `<script>` code, access the
object via `styles.value`.

## 5. Follow the system setting

`useColorScheme()` reactively reports the OS appearance and updates when the
user toggles system dark mode. Sync it into the theme with a `watch`:

```vue
<script setup lang="ts">
import { watch } from 'vue'
import { useColorScheme } from '@thelacanians/vue-native-runtime'
import { useTheme } from './theme'

const { colorScheme: systemScheme } = useColorScheme()
const { setColorScheme } = useTheme()

// Apply the system setting now and whenever it changes.
watch(systemScheme, (scheme) => setColorScheme(scheme), { immediate: true })
</script>
```

`useColorScheme()` returns `{ colorScheme, isDark }`, both reactive refs.

## 6. Persist the user's preference

The simplest way to remember an explicit user choice across launches is the
`persist` prop on `<ThemeProvider>`. It stores the scheme (via
[`useAsyncStorage`](/composables/useAsyncStorage.md)) whenever
`setColorScheme`/`toggleColorScheme` is called and restores it on startup:

```vue
<!-- App.vue -->
<script setup lang="ts">
import { ThemeProvider } from './theme'
import HomeScreen from './HomeScreen.vue'
</script>

<template>
  <!-- true = default storage key; or pass a custom key string -->
  <ThemeProvider follow-system persist>
    <HomeScreen />
  </ThemeProvider>
</template>
```

With `follow-system` + `persist`, the theme follows the OS until the user makes an
explicit choice, which is then persisted and restored on the next launch.

### Advanced: manual control

For custom flows (e.g. resolving the initial scheme yourself, or a custom storage
backend), store the preference with [`useAsyncStorage`](/composables/useAsyncStorage.md)
and read it back before the provider mounts:

```ts
// theme.ts (additions)
import { useAsyncStorage } from '@thelacanians/vue-native-runtime'

const storage = useAsyncStorage()
const STORAGE_KEY = 'theme-preference'

export async function loadSavedScheme(): Promise<'light' | 'dark' | null> {
  const saved = await storage.getItem(STORAGE_KEY)
  return saved === 'light' || saved === 'dark' ? saved : null
}

export function saveScheme(scheme: 'light' | 'dark'): Promise<void> {
  return storage.setItem(STORAGE_KEY, scheme)
}
```

A child screen can call `useTheme().toggleColorScheme()` to flip the scheme; pair
that with `saveScheme(colorScheme.value)` to persist the explicit choice.

## Semantic colors

In addition to hex/rgb values, the style engine recognizes **semantic color names**
that resolve to platform dynamic colors (auto light/dark):
`background`, `label`, `secondaryLabel`, `tertiaryLabel`, `separator`, `systemBlue`,
`systemRed`, `systemGreen`, `systemOrange`, `systemGray`.

```ts
const styles = createStyleSheet({
  container: { backgroundColor: 'background' },
  title: { color: 'label' },
  divider: { backgroundColor: 'separator' },
})
```

These map to `UIColor.systemBackground`/`.label`/… on iOS, theme attributes on Android,
and `NSColor.windowBackgroundColor`/`.labelColor`/… on macOS.

## Summary

- `createTheme` → tokens + `<ThemeProvider>` + `useTheme`.
- `createDynamicStyleSheet(theme, factory)` → reactive, theme-aware styles.
- `useColorScheme` → follow the OS dark-mode setting.
- `useAsyncStorage` → persist an explicit user preference.
- Full runnable example: [`examples/theming/`](https://github.com/abdul-hamid-achik/vue-native/tree/main/examples/theming).

## See also

- [Styling](/guide/styling.md) — the full style property reference.
- [useColorScheme](/composables/useColorScheme.md) — system appearance detection.
- [useAsyncStorage](/composables/useAsyncStorage.md) — key/value persistence.
