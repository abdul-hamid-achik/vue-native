# Theming

Demonstrates theming, dark mode, and dynamic styles.

## What It Demonstrates

- **Components:** VView, VText, VButton, VSwitch, VPicker
- **Composables:** `useColorScheme`, `createTheme`, `createDynamicStyleSheet`
- **Patterns:**
  - Theme provider pattern
  - Dynamic styles
  - Dark mode support
  - Color scheme detection

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
bun vue-native dev
```

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
│   └── theme.ts
├── native/
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
