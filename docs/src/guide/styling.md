# Styling

Vue Native uses **Yoga Flexbox** on iOS and **FlexboxLayout** on Android — the same mental model as CSS Flexbox.

## createStyleSheet

Use `createStyleSheet` to define styles as typed objects. Styles are validated and frozen for performance:

```ts
import { createStyleSheet } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  container: {
    flex: 1,
    flexDirection: 'column',
    backgroundColor: '#F5F5F5',
    padding: 16,
    gap: 12,
  },
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
  },
  title: {
    fontSize: 20,
    fontWeight: '600',
    color: '#1A1A1A',
  },
})
```

## Inline styles

You can also pass style objects directly:

```vue
<VView :style="{ flex: 1, padding: 16 }">
  <VText :style="{ fontSize: 16, color: '#333' }">Hello</VText>
</VView>
```

## Units

All numeric values are in **density-independent points (dp)**:

| Platform | 1 dp equals |
|----------|-------------|
| iOS @2x (iPhone SE, 8) | 2 physical pixels |
| iOS @3x (iPhone 12+) | 3 physical pixels |
| Android mdpi (160 dpi) | 1 physical pixel |
| Android xxhdpi (480 dpi) | 3 physical pixels |

The framework automatically converts dp to pixels using the device's scale factor. You don't need to handle retina/density differences.

```ts
// 16 dp ≈ 16 CSS pixels ≈ 32-48 physical pixels depending on device
{ padding: 16, fontSize: 16, borderWidth: 1 }
```

## Percentage values

Some layout properties accept percentage strings relative to the parent's dimension:

```ts
{
  width: '50%',       // 50% of parent's width
  height: '100%',     // 100% of parent's height
  maxWidth: '75%',    // At most 75% of parent's width
  minHeight: '25%',   // At least 25% of parent's height
}
```

**Properties supporting percentages:** `width`, `height`, `minWidth`, `minHeight`, `maxWidth`, `maxHeight`, `flexBasis`, `top`, `right`, `bottom`, `left`, `margin*`, `padding*`.

**Note:** Type definitions require casting for percentages on some properties: `maxWidth: '75%' as any`. This will be improved in a future release.

## Color formats

Colors are specified as strings. Supported formats:

| Format | Example | Notes |
|--------|---------|-------|
| Hex (6-digit) | `'#FF5733'` | RGB |
| Hex (8-digit) | `'#FF573380'` | RGBA (last 2 digits = alpha) |
| Hex (3-digit) | `'#F53'` | Shorthand RGB |
| `rgb()` | `'rgb(255, 87, 51)'` | |
| `rgba()` | `'rgba(255, 87, 51, 0.5)'` | Alpha 0–1 |
| Named | `'red'`, `'blue'`, `'transparent'` | CSS named colors |

```ts
{
  backgroundColor: '#007AFF',
  color: 'rgba(0, 0, 0, 0.87)',
  borderColor: 'transparent',
}
```

## Supported properties

### Layout (Flexbox)
| Property | Values |
|----------|--------|
| `flex` | number |
| `flexDirection` | `'row'` \| `'column'` \| `'row-reverse'` \| `'column-reverse'` |
| `flexWrap` | `'wrap'` \| `'nowrap'` |
| `flexGrow` | number |
| `flexShrink` | number |
| `flexBasis` | number or `'auto'` |
| `alignItems` | `'flex-start'` \| `'center'` \| `'flex-end'` \| `'stretch'` \| `'baseline'` |
| `alignSelf` | same as alignItems \| `'auto'` |
| `alignContent` | `'flex-start'` \| `'center'` \| `'flex-end'` \| `'stretch'` \| `'space-between'` \| `'space-around'` |
| `justifyContent` | `'flex-start'` \| `'center'` \| `'flex-end'` \| `'space-between'` \| `'space-around'` \| `'space-evenly'` |
| `width`, `height` | number (dp) or `'50%'` |
| `minWidth`, `minHeight` | number or `'auto'` |
| `maxWidth`, `maxHeight` | number or percentage string |
| `aspectRatio` | number (e.g. `1` for square, `16/9` for widescreen) |
| `position` | `'relative'` (default) \| `'absolute'` |
| `top`, `right`, `bottom`, `left` | number |
| `padding`, `paddingHorizontal`, `paddingVertical`, `paddingTop`, `paddingBottom`, `paddingLeft`, `paddingRight` | number |
| `margin`, `marginHorizontal`, `marginVertical`, `marginTop`, `marginBottom`, `marginLeft`, `marginRight` | number |
| `gap`, `rowGap`, `columnGap` | number |
| `display` | `'flex'` \| `'none'` |
| `overflow` | `'hidden'` \| `'visible'` \| `'scroll'` |
| `direction` | `'ltr'` \| `'rtl'` \| `'inherit'` |

### Appearance
| Property | Values |
|----------|--------|
| `backgroundColor` | color string |
| `opacity` | 0–1 |
| `borderRadius`, `borderTopLeftRadius`, `borderTopRightRadius`, `borderBottomLeftRadius`, `borderBottomRightRadius` | number |
| `borderWidth`, `borderTopWidth`, `borderRightWidth`, `borderBottomWidth`, `borderLeftWidth` | number |
| `borderColor` | color string |
| `overflow` | `'hidden'` \| `'visible'` |
| `zIndex` | number |
| `transform` | array of transform objects |

### Text (on VText / VInput)
| Property | Values |
|----------|--------|
| `fontSize` | number (dp) |
| `fontWeight` | `'normal'` \| `'bold'` \| `'100'`–`'900'` |
| `fontStyle` | `'normal'` \| `'italic'` |
| `color` | color string |
| `textAlign` | `'left'` \| `'center'` \| `'right'` |
| `lineHeight` | number (dp) |
| `letterSpacing` | number |
| `textDecorationLine` | `'underline'` \| `'line-through'` \| `'none'` |
| `textTransform` | `'none'` \| `'uppercase'` \| `'lowercase'` \| `'capitalize'` |

### Shadow (iOS)
| Property | Values |
|----------|--------|
| `shadowColor` | color string |
| `shadowOffset` | `{ width: number, height: number }` |
| `shadowOpacity` | 0–1 |
| `shadowRadius` | number |

### Elevation (Android)
| Property | Values |
|----------|--------|
| `elevation` | number (higher = more shadow) |

## Common Layout Patterns

### Center content

```ts
const styles = createStyleSheet({
  centered: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
})
```

### Equal-width grid (2 columns)

```ts
const styles = createStyleSheet({
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  gridItem: {
    width: '48%',  // Slightly less than 50% to account for gap
  },
})
```

### Sticky header + scrollable content

```ts
const styles = createStyleSheet({
  screen: { flex: 1 },
  header: {
    padding: 16,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderColor: '#E5E5E5',
  },
  content: { flex: 1 },  // Applied to VScrollView
})
```

```vue
<VView :style="styles.screen">
  <VView :style="styles.header">
    <VText>Header</VText>
  </VView>
  <VScrollView :style="styles.content">
    <!-- Scrollable content here -->
  </VScrollView>
</VView>
```

### Card with shadow

```ts
const styles = createStyleSheet({
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    marginHorizontal: 16,
    marginVertical: 8,
    // iOS shadow
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    // Android shadow
    elevation: 3,
  },
})
```

### Row with spacer (left text, right button)

```ts
const styles = createStyleSheet({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
  },
})
```

## Theming & Dark Mode

Vue Native provides a built-in theme system via `createTheme`:

```ts
// theme.ts
import { createTheme } from '@thelacanians/vue-native-runtime'

export const { ThemeProvider, useTheme } = createTheme({
  light: {
    colors: {
      background: '#FFFFFF',
      surface: '#F5F5F5',
      text: '#1A1A1A',
      textSecondary: '#8E8E93',
      primary: '#007AFF',
      error: '#FF3B30',
    },
    spacing: { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 },
    borderRadius: { sm: 4, md: 8, lg: 12, xl: 16 },
  },
  dark: {
    colors: {
      background: '#000000',
      surface: '#1C1C1E',
      text: '#F5F5F5',
      textSecondary: '#8E8E93',
      primary: '#0A84FF',
      error: '#FF453A',
    },
    spacing: { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 },
    borderRadius: { sm: 4, md: 8, lg: 12, xl: 16 },
  },
})
```

Wrap your app root:

```vue
<!-- App.vue -->
<template>
  <ThemeProvider>
    <RouterView />
  </ThemeProvider>
</template>
```

Use `createDynamicStyleSheet` for theme-aware styles that update reactively:

```vue
<script setup>
import { useTheme } from '../theme'
import { createDynamicStyleSheet } from '@thelacanians/vue-native-runtime'

const { theme, colorScheme, toggleColorScheme } = useTheme()

const styles = createDynamicStyleSheet(theme, (t) => ({
  container: {
    flex: 1,
    backgroundColor: t.colors.background,
    padding: t.spacing.md,
  },
  title: {
    fontSize: 24,
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
      <VText>Toggle Theme</VText>
    </VButton>
  </VView>
</template>
```

### Syncing with system dark mode

Use `useColorScheme` to detect the system setting and sync with the theme:

```vue
<script setup>
import { watch } from '@thelacanians/vue-native-runtime'
import { useColorScheme } from '@thelacanians/vue-native-runtime'
import { useTheme } from '../theme'

const { colorScheme: systemScheme } = useColorScheme()
const { setColorScheme } = useTheme()

// Sync theme with system setting
watch(() => systemScheme.value, (scheme) => {
  if (scheme) setColorScheme(scheme)
}, { immediate: true })
</script>
```

## Platform differences

| Property | iOS | Android |
|----------|-----|---------|
| `shadowColor/Offset/Opacity/Radius` | Native `CALayer` shadow | No effect (use `elevation`) |
| `elevation` | No effect | Native `View.elevation` |
| `fontWeight` | Full range `'100'`–`'900'` | Only `'normal'` and `'bold'` on some devices |
| `letterSpacing` | Points | Treated as `em` on some Android versions |
