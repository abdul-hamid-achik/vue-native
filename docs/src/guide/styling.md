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

**Properties supporting percentages:** `width`, `height`, `minWidth`, `minHeight`, `maxWidth`, `maxHeight`, `flexBasis`, `top`, `right`, `bottom`, `left`.

**Note:** Type definitions require casting for percentages on some properties: `maxWidth: '75%' as any`. This will be improved in a future release.

::: warning Breaking change in v0.8.0
`padding` and `margin` (and their `padding*` / `margin*` variants) are now
**numbers only** — percentage strings are no longer accepted. If you previously
used a percentage, compute the value from the parent dimension yourself (for
example with [`useDimensions`](/composables/useDimensions.md)).
:::

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
| `paddingStart`, `paddingEnd` | number (RTL-aware: map to left/right based on `direction`) |
| `margin`, `marginHorizontal`, `marginVertical`, `marginTop`, `marginBottom`, `marginLeft`, `marginRight` | number |
| `marginStart`, `marginEnd` | number (RTL-aware: map to left/right based on `direction`) |
| `gap`, `rowGap`, `columnGap` | number |
| `display` | `'flex'` \| `'none'` |
| `overflow` | `'hidden'` \| `'visible'` |
| `direction` | `'ltr'` \| `'rtl'` \| `'inherit'` |

::: warning Removed style properties (v0.8.0)
`borderStyle`, `textDecorationStyle`, and `textDecorationColor` were removed —
they were never implemented by the native renderers. `overflow: 'scroll'` was
also removed; `overflow` only accepts `'visible'` or `'hidden'`. For scrollable
content use [`<VScrollView>`](/components/VScrollView.md) or a list component.
:::

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

`elevation` is Android-only and is a no-op on iOS/macOS. It is **required** for
shadows to render on Android — the iOS `shadow*` properties have no effect
there, so set `elevation` alongside them for cross-platform cards:

```ts
const styles = createStyleSheet({
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 16,
    // iOS / macOS
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    // Android
    elevation: 3,
  },
})
```

## Transforms

The `transform` style accepts an array of transform objects. Transforms are
applied in array order and do not affect layout (the view's measured box stays
the same).

```ts
{
  transform: [
    { translateX: 10 },
    { rotate: '45deg' },
    { scale: 1.2 },
  ],
}
```

### Supported transform values

| Key | Type | Description |
|-----|------|-------------|
| `translateX`, `translateY` | `number` | Translation in points. |
| `scale`, `scaleX`, `scaleY` | `number` | Scale factor (`1` = unchanged). |
| `rotate`, `rotateX`, `rotateY`, `rotateZ` | `string` | Rotation angle, e.g. `'45deg'` or `'1.5rad'`. `rotateX`/`rotateY`/`rotateZ` are 3D rotations around each axis. |
| `perspective` | `number` | Perspective depth for 3D transforms (sets the `m34` term). Larger values look flatter; smaller values exaggerate depth. |
| `skewX`, `skewY` | `string` | Skew angle, e.g. `'45deg'`. |

### 3D transforms

Combine `perspective` with `rotateX` / `rotateY` for flip and tilt effects:

```ts
const styles = createStyleSheet({
  card: {
    transform: [
      { perspective: 800 },
      { rotateY: '25deg' },
    ],
  },
})
```

::: warning Platform notes: skew on Android
`skewX` and `skewY` work on all three platforms. On Android, a transform list
containing skew is composed into a single native matrix that renders
identically to iOS (same composition order and center pivot), with two
caveats:

- **Touch mapping** — Android hit-testing does not follow the skewed
  geometry, so touches land on the view's unskewed bounds. Prefer skew for
  decorative content rather than skewed touch targets.
- **Skew + 3D rotation** — combining `skewX`/`skewY` with `rotateX`,
  `rotateY`, or `perspective` in the same transform list is not supported on
  Android; that combination falls back to ignoring the skew and logs a
  one-time warning.
:::

## Hairline borders

Use the exported `hairlineWidth` constant for the thinnest border the platform
can render — useful for 1px-look dividers and separators:

```ts
import { createStyleSheet, hairlineWidth } from '@thelacanians/vue-native-runtime'

const styles = createStyleSheet({
  separator: {
    height: hairlineWidth,
    backgroundColor: '#C6C6C8',
  },
  bordered: {
    borderWidth: hairlineWidth,
    borderColor: '#E5E5E5',
  },
})
```

`hairlineWidth` is `0.5` and mirrors React Native's `StyleSheet.hairlineWidth`.

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

Vue Native ships a built-in theme system: `createTheme` defines light/dark
design tokens, `<ThemeProvider>` provides them via Vue's provide/inject, and
`createDynamicStyleSheet` builds stylesheets that re-evaluate reactively when
the active theme changes. Pair it with `useColorScheme` to follow the system
dark-mode setting.

```ts
import { createTheme, createDynamicStyleSheet } from '@thelacanians/vue-native-runtime'

export const { ThemeProvider, useTheme } = createTheme({
  light: { colors: { background: '#FFFFFF', text: '#1A1A1A' }, spacing: { md: 16 } },
  dark: { colors: { background: '#000000', text: '#F5F5F5' }, spacing: { md: 16 } },
})
```

For the full walkthrough — token design, system sync, and persisting the user's
preference — see the [Theming guide](/guide/theming.md).

## Platform differences

| Property | iOS | Android |
|----------|-----|---------|
| `shadowColor/Offset/Opacity/Radius` | Native `CALayer` shadow | No effect (use `elevation`) |
| `elevation` | No effect | Native `View.elevation` |
| `fontWeight` | Full range `'100'`–`'900'` | Only `'normal'` and `'bold'` on some devices |
| `letterSpacing` | Points | Treated as `em` on some Android versions |
