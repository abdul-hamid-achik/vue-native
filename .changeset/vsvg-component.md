---
"@thelacanians/vue-native-runtime": minor
---

New `VSVG` component for rendering Scalable Vector Graphics natively (vector-crisp at any resolution).

- `<VSVG :source="{ svg | asset | uri }" />` accepts inline SVG markup, a bundled asset, or a remote URL, with an optional `tintColor` and `load`/`error` events. Exported `SVGSource` type.
- Backed by SVGKit on iOS/macOS and AndroidSVG on Android (the native factories and dependencies ship with the tag).
