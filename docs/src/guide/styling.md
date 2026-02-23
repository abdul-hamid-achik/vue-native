# Styling

Vue Native uses **Yoga Flexbox** on iOS and **FlexboxLayout** on Android — the same mental model as CSS Flexbox.

## createStyleSheet

Use `createStyleSheet` to define styles as typed objects:

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

## Supported properties

### Layout (Flexbox)
| Property | Values |
|----------|--------|
| `flex` | number |
| `flexDirection` | `'row'` \| `'column'` \| `'row-reverse'` \| `'column-reverse'` |
| `flexWrap` | `'wrap'` \| `'nowrap'` |
| `alignItems` | `'flex-start'` \| `'center'` \| `'flex-end'` \| `'stretch'` |
| `alignSelf` | same as alignItems |
| `justifyContent` | `'flex-start'` \| `'center'` \| `'flex-end'` \| `'space-between'` \| `'space-around'` |
| `width`, `height` | number (dp) or `'50%'` |
| `padding`, `paddingHorizontal`, `paddingVertical`, `paddingTop`, `paddingBottom`, `paddingLeft`, `paddingRight` | number |
| `margin`, `marginHorizontal`, `marginVertical`, `marginTop`, `marginBottom`, `marginLeft`, `marginRight` | number |
| `gap`, `rowGap`, `columnGap` | number |

### Appearance
| Property | Values |
|----------|--------|
| `backgroundColor` | color string (`'#fff'`, `'rgba(0,0,0,0.5)'`, `'transparent'`) |
| `opacity` | 0–1 |
| `borderRadius`, `borderTopLeftRadius`, etc. | number |
| `borderWidth`, `borderColor` | number / color |
| `overflow` | `'hidden'` \| `'visible'` |

### Text (on VText / VInput)
| Property | Values |
|----------|--------|
| `fontSize` | number |
| `fontWeight` | `'normal'` \| `'bold'` \| `'100'`–`'900'` |
| `fontStyle` | `'normal'` \| `'italic'` |
| `color` | color string |
| `textAlign` | `'left'` \| `'center'` \| `'right'` |
| `lineHeight` | number |
| `letterSpacing` | number |
| `textDecorationLine` | `'underline'` \| `'line-through'` \| `'none'` |

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
| `elevation` | number |
