# VSVG

Renders Scalable Vector Graphics natively — vector-crisp at any resolution. Backed by
[SVGKit](https://github.com/SVGKit/SVGKit) on iOS/macOS and
[AndroidSVG](https://github.com/BigBadaboom/androidsvg) on Android.

## Native host setup (iOS/macOS)

`<VSVG>` is the only component that needs SVGKit, so on iOS and macOS it ships in an
optional add-on product — `VueNativeCoreSVG` / `VueNativeMacOSSVG` — instead of the core
framework, and an app that never renders an SVG never resolves SVGKit. Projects made with
`vue-native create` already link the product and call `VueNativeCoreSVG.register()` /
`VueNativeMacOSSVG.register()` at launch, so they need nothing. If you integrate the
framework by hand, add the add-on product to your app target and call its `register()`
once before the first view (or window) is created; without it `<VSVG>` renders nothing and
the framework logs an error naming the product and the call that fixes it. Android ships
VSVG in the core library and needs no extra setup.

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `source` | `SVGSource` | — | The SVG to render. Provide exactly one of `svg`, `asset`, or `uri` (see below). |
| `tintColor` | `string` | — | Optional hex color applied as a tint to the rendered SVG. |
| `style` | `ViewStyle` | `{}` | Layout/visual style. Set `width`/`height` to size the SVG. |
| `testID` | `string` | — | Test identifier for end-to-end testing. |
| `accessibilityLabel` | `string` | — | Accessibility label. |
| `accessibilityRole` | `string` | `'image'` | Accessibility role. |
| `accessibilityHint` | `string` | — | Additional accessibility context. |
| `accessibilityState` | `object` | — | Accessibility state (e.g. `{ disabled: true }`). |

### `SVGSource`

Provide **exactly one** of:

| Field | Type | Description |
|-------|------|-------------|
| `svg` | `string` | Inline SVG markup. |
| `asset` | `string` | Bundled SVG asset name (iOS/macOS main bundle, Android `assets/`). |
| `uri` | `string` | Remote SVG URL (loaded asynchronously). |

## Events

| Event | Payload | Description |
|-------|---------|-------------|
| `load` | — | Emitted when the SVG renders successfully. |
| `error` | — | Emitted when parsing or loading fails. |

## Examples

### Inline markup

```vue
<template>
  <VSVG
    :source="{ svg: icon }"
    :style="{ width: 24, height: 24 }"
    tintColor="#007AFF"
  />
</template>

<script setup lang="ts">
const icon = '<svg viewBox="0 0 24 24"><path d="M12 2 2 22h20Z"/></svg>'
</script>
```

### Bundled asset

```vue
<VSVG :source="{ asset: 'icons/logo' }" :style="{ width: 120, height: 40 }" />
```

### Remote URI

```vue
<VSVG
  :source="{ uri: 'https://example.com/diagram.svg' }"
  :style="{ width: 300, height: 200 }"
  @load="onLoad"
  @error="onError"
/>
```

## Notes

- Set an explicit `width`/`height` in `style`; the SVG scales to fit while preserving its
  aspect ratio (from its `viewBox`).
- Invalid SVG markup emits `error` rather than crashing.
- `tintColor` support depends on the SVG structure; simple single-color icons tint reliably.
