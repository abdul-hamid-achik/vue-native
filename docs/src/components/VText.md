# VText

Displays text. Maps to `UILabel` on iOS and `TextView` on Android.

All text in Vue Native must be wrapped in a `VText` component -- raw text outside of `VText` will not be rendered.

## Usage

```vue
<VText :style="{ fontSize: 16, color: '#333', fontWeight: '600' }">
  Hello, world!
</VText>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `style` | `StyleProp` | -- | Text + layout styles |
| `numberOfLines` | `number` | `0` (unlimited) | Truncate after N lines |
| `selectable` | `boolean` | `false` | Allow the user to select and copy text |
| `accessibilityLabel` | `string` | -- | Accessible description (overrides displayed text) |
| `accessibilityRole` | `string` | -- | Accessibility role (e.g. `'header'`) |
| `accessibilityHint` | `string` | -- | Additional accessibility context |
| `accessibilityState` | `object` | -- | Accessibility state |

## Text styles

| Property | Type | Description |
|----------|------|-------------|
| `fontSize` | `number` | Font size in points |
| `fontWeight` | `'normal'` \| `'bold'` \| `'100'`--`'900'` | Font weight |
| `fontStyle` | `'normal'` \| `'italic'` | Font style |
| `color` | `string` | Text color |
| `textAlign` | `'left'` \| `'center'` \| `'right'` | Horizontal alignment |
| `lineHeight` | `number` | Line height |
| `letterSpacing` | `number` | Letter spacing |
| `textDecorationLine` | `'underline'` \| `'line-through'` \| `'none'` | Text decoration |

## Events

VText does not emit any events.

## Example

```vue
<VView :style="{ gap: 8 }">
  <VText :style="{ fontSize: 24, fontWeight: 'bold' }">Title</VText>
  <VText :style="{ fontSize: 14, color: '#666' }" :numberOfLines="2">
    This is a subtitle that may span multiple lines but will be
    truncated after two lines with an ellipsis.
  </VText>
  <VText :style="{ fontSize: 14, color: '#007AFF' }" :selectable="true">
    This text can be selected and copied.
  </VText>
</VView>
```
