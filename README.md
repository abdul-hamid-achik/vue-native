# Vue Native

Build truly native iOS apps with Vue.js 3 — no WebViews.

Vue Native lets Vue developers write `.vue` Single File Components that render to native UIKit views, achieving performance comparable to React Native while using the Vue ecosystem they already know.

> **Status:** Active development — Phase 1 (Proof of Concept) in progress.

---

## Why Vue Native?

Vue 3's `createRenderer()` API was designed for exactly this: targeting non-DOM environments. Vue Native uses it to map Vue's virtual node operations to native iOS UIKit views through a high-performance bridge.

**Vue's advantages for native:**

- **Fine-grained reactivity** — Vue knows exactly which property changed. Only the affected native view gets updated — no full subtree diffing like React Native.
- **Smaller runtime** — `@vue/runtime-core` is ~10KB gzipped vs React's ~40KB. Matters on mobile.
- **Composition API** — No rules-of-hooks restrictions. Composables can be called conditionally and composed freely, mapping perfectly to native module access patterns.
- **SFC compiler** — Static analysis at build time hoists static content and reduces runtime work, critical on mobile.
- **2M+ Vue developers** with no production-grade native mobile story — until now.

---

## Architecture

```
┌──────────────────────────────────┐
│        Your .vue Files           │
│  <template> + <script setup>     │
└──────────────┬───────────────────┘
               │  Vite + @vue-native/vite-plugin
               ▼
┌──────────────────────────────────┐
│     Compiled IIFE Bundle         │
│     (loaded by JavaScriptCore)   │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────────┐
│   @vue/runtime-core              │
│   + Vue Native Custom Renderer   │  ← JavaScript (JSC)
│                                  │
│   createElement() → Bridge       │
│   patchProp()     → Bridge       │
│   insert()        → Bridge       │
└──────────────┬───────────────────┘
               │  JSON / JSContext calls
               ▼
┌──────────────────────────────────┐
│   VueNativeCore (Swift)          │
│   + Yoga layout engine           │  ← Native (Swift/UIKit)
│   + UIKit component registry     │
└──────────────────────────────────┘
```

**10-layer stack:**

| Layer | Responsibility |
|-------|---------------|
| 1 | JavaScriptCore runtime + Vue custom renderer |
| 2 | Bridge (JS ↔ Swift via JSContext) |
| 3 | Native component registry (Swift/UIKit factories) |
| 4 | Layout engine (Yoga via FlexLayout) |
| 5 | Native module system (composables) |
| 6 | Navigation (Phase 2) |
| 7 | Styling (JS style objects → Yoga + UIView props) |
| 8 | Developer tooling (CLI, scaffold) |
| 9 | Build system (Vite + custom plugin → IIFE) |
| 10 | Hot reload / dev server |

---

## Monorepo Structure

```
vue-native/
├── packages/
│   ├── runtime/          # @vue-native/runtime — Vue custom renderer
│   └── vite-plugin/      # @vue-native/vite-plugin — Build tooling
├── native/               # VueNativeCore Swift Package
│   ├── Sources/          # Bridge, ComponentRegistry, LayoutEngine
│   └── Package.swift
├── examples/
│   └── counter/          # Phase 1 demo: counter app
├── SPEC.md               # Full technical specification
├── PLAN.md               # Implementation plan
└── package.json          # Bun workspaces + Turborepo
```

---

## Quick Start

> **Prerequisites:** macOS 13+, Xcode 15+, Bun, iOS 16+ device or simulator.

### 1. Clone and install

```bash
git clone https://github.com/abdul-hamid-achik/vue-native.git
cd vue-native
bun install
```

### 2. Build JS packages

```bash
bun run build
```

### 3. Open the example in Xcode

```bash
open examples/counter/ios/VueNativeCounter.xcodeproj
```

### 4. Run on simulator

Select an iOS 16+ simulator in Xcode and hit **Run**.

---

## Writing an App

```vue
<script setup lang="ts">
import { ref } from 'vue'

const count = ref(0)
</script>

<template>
  <VView :style="styles.container">
    <VText :style="styles.counter">Count: {{ count }}</VText>
    <VButton :style="styles.button" @press="count++">
      <VText>Increment</VText>
    </VButton>
  </VView>
</template>

<script>
const styles = createStyleSheet({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#fff',
  },
  counter: {
    fontSize: 32,
    marginBottom: 20,
  },
  button: {
    backgroundColor: '#42b883',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
})
</script>
```

---

## Component Reference (Phase 1)

| Component | UIKit View | Key Props |
|-----------|-----------|-----------|
| `VView` | `UIView` | `style` |
| `VText` | `UILabel` | `style` |
| `VButton` | Custom `TouchableView` | `style`, `disabled`, `@press` |
| `VInput` | `UITextField` | `style`, `v-model`, `placeholder`, `@change-text` |

---

## Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| JS engine (Phase 1) | JavaScriptCore | Built into iOS, zero size overhead |
| JS engine (Phase 2) | Hermes (optional) | AOT compilation, faster cold starts |
| Layout | Yoga via FlexLayout | React Native battle-tested, Flexbox familiar to web devs |
| Bridge (Phase 1) | JSON over JSContext calls | Simple, fast to implement |
| Bridge (Phase 2) | MessagePack binary | Lower serialization overhead |
| Component framework | UIKit | Mature, imperatively controllable from JS |
| Build | Vite + IIFE bundle | IIFE required — JSC has no ESM support |

---

## Roadmap

### Phase 1 — Proof of Concept (current)

- [x] Monorepo setup (Bun + Turborepo)
- [x] Swift Package with Yoga/FlexLayout
- [ ] JSC runtime + polyfills
- [ ] Vue custom renderer (`@vue-native/runtime`)
- [ ] JS↔Swift bridge
- [ ] VView, VText, VButton, VInput
- [ ] Vite IIFE build pipeline
- [ ] Counter demo app running on iOS simulator

### Phase 2 — Production Foundation

- [ ] Navigation system (stack + tab)
- [ ] Hot module replacement over WebSocket
- [ ] VList (virtualized list, native recycling)
- [ ] VImage with async loading
- [ ] Native modules (camera, geolocation, haptics, storage)
- [ ] Shadow tree layout (background-thread Yoga)
- [ ] MessagePack bridge

### Phase 3 — Ecosystem

- [ ] CLI (`vue-native create`)
- [ ] Animations (`VAnimated`)
- [ ] Accessibility
- [ ] Android / Kotlin port

---

## Development

```bash
# Watch mode for JS packages
bun run dev

# Type checking
bun run typecheck

# Tests
bun run test

# Clean all build artifacts
bun run clean
```

### Package requirements

- **Bun** >= 1.3.8
- **Node.js** >= 20 (for some tooling)
- **TypeScript** >= 5.7
- **Xcode** >= 15
- **iOS target** >= 16.0
- **Swift** >= 5.9

---

## Contributing

This project is in early development. The [SPEC.md](./SPEC.md) contains the full technical specification and [PLAN.md](./PLAN.md) the implementation roadmap.

Before contributing:

1. Read `SPEC.md` for architecture decisions and rationale
2. Read `AGENTS.md` for AI-assisted development conventions
3. Open an issue to discuss significant changes before implementing

---

## License

MIT
