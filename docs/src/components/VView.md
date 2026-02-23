# VView

A container view. The basic building block of every Vue Native layout.

Equivalent to `<div>` in web, `UIView` on iOS, `FlexboxLayout` on Android.

## Usage

```vue
<VView :style="{ flex: 1, padding: 16, backgroundColor: '#fff' }">
  <VText>Hello</VText>
</VView>
```

## Props

| Prop | Type | Description |
|------|------|-------------|
| `style` | `StyleProp` | Flexbox layout + appearance styles |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `@press` | `{ x, y }` | Tap on the view |
| `@longPress` | `{ x, y }` | Long press |

## Flexbox

`VView` supports all Flexbox layout properties. See [Styling](../guide/styling.md) for the full list.

```vue
<VView :style="{
  flex: 1,
  flexDirection: 'row',
  alignItems: 'center',
  justifyContent: 'space-between',
  padding: 16,
  gap: 8,
}">
  <VText>Left</VText>
  <VText>Right</VText>
</VView>
```
