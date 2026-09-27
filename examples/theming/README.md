# Theming

Demonstrates theming, dark mode, and dynamic styles.

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

- **Components:** VView, VText, VButton, VSwitch, VSlider, VScrollView
- **Composables:** `useTheme`, `useColorScheme`, `useI18n`
- **APIs:** `createTheme`, `createDynamicStyleSheet`, `ErrorBoundary`
- **Patterns:**
  - Theme provider pattern with design tokens
  - Dynamic style sheets derived from the active theme
  - System color-scheme detection and manual override
  - An `ErrorBoundary` around a deliberately crashing subtree, with reset
  - RTL / LTR layout preview

`useI18n()` returns read-only `locale` and `isRTL` refs that it fills from
DeviceInfo on mount — there is no `setLocale()`. The RTL buttons here drive those
refs directly through a local `previewLocale()` helper.

## Key Features

- Light/dark theme switching
- Custom color palettes
- Dynamic style sheets
- System color scheme detection
- Manual theme override

## How to Run

```bash
cd examples/theming
bun install
bun run dev:ios
# or: bun run dev:android
# or: bun run dev:macos
```

This directory contains Vue source only. Copy it into a generated project with
the corresponding native host before launching it.

## Key Concepts

### Theme Definition

```typescript
import { createTheme } from '@thelacanians/vue-native-runtime'

const { ThemeProvider, useTheme } = createTheme({
  light: {
    colors: {
      primary: '#007AFF',
      background: '#FFFFFF',
      text: '#000000',
    },
  },
  dark: {
    colors: {
      primary: '#0A84FF',
      background: '#000000',
      text: '#FFFFFF',
    },
  },
})
```

### Theme Provider

```vue
<script setup>
import { ThemeProvider } from './theme'
</script>

<template>
  <ThemeProvider :initialColorScheme="'light'">
    <App />
  </ThemeProvider>
</template>
```

### Dynamic Styles

```typescript
import { createDynamicStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createDynamicStyleSheet(theme, (t) => ({
  container: {
    flex: 1,
    backgroundColor: t.colors.background,
  },
  text: {
    color: t.colors.text,
  },
}))
```

### System Color Scheme

```typescript
const { colorScheme, isDark } = useColorScheme()

watch(isDark, () => {
  console.log('Dark mode:', isDark.value)
})
```

### Manual Theme Switching

```typescript
const { colorScheme, setColorScheme } = useTheme()

// Toggle theme
setColorScheme(colorScheme.value === 'light' ? 'dark' : 'light')
```

## File Structure

```
examples/theming/
├── app/
│   ├── main.ts
│   ├── App.vue
│   ├── ThemeDemo.vue
│   └── theme.ts
├── vite.config.ts
└── package.json
```

## Learn More

- [createTheme](../../docs/src/guide/styling.md#theming)
- [useColorScheme](../../docs/src/composables/useColorScheme.md)
- [Dynamic Styles](../../docs/src/guide/styling.md#dynamic-styles)

## Try This

Experiment with:
1. Add more theme variants (e.g., "midnight", "ocean")
2. Implement theme animations
3. Add font size preferences
4. Create theme preview screen
5. Add accent color customization
