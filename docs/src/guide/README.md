# Introduction

Vue Native lets you build **real native iOS and Android apps** with Vue 3.

Unlike hybrid frameworks that render HTML in a WebView, Vue Native drives native UI components directly — `UIKit` on iOS and `Android Views` on Android. Your Vue components produce actual native views with native performance and look.

## How it works

```
Vue Component (SFC)
      ↓  Vue custom renderer  (createRenderer)
  NativeBridge (TypeScript)
      ↓  JSON batch via queueMicrotask
      ├── iOS:     Swift → UIKit  → Yoga layout
      └── Android: Kotlin → Android Views → FlexboxLayout
```

The JavaScript engine runs your Vue app:

- **iOS** — JavaScriptCore (built into the OS, zero download overhead)
- **Android** — V8 via J2V8

## Key features

- **Vue 3 Composition API** — `ref`, `computed`, `watch`, `<script setup>` all work as expected
- **Real native UI** — No DOM, no WebView, no HTML
- **Cross-platform** — One Vue codebase, both platforms
- **20 built-in components** — VView, VText, VButton, VInput, VList, and more
- **Native modules** — Haptics, AsyncStorage, Camera, Geolocation, and more
- **Navigation** — Stack navigation via `@vue-native/navigation`
- **Hot reload** — Edit Vue files, see changes instantly
- **TypeScript** — Full type coverage

## Next steps

- [Installation →](./installation.md)
- [Your first app →](./your-first-app.md)
