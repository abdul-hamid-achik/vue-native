# Vue Native — Master Implementation Plan

**Generated:** February 20, 2026
**Based on:** SPEC.md v1.0 + Research from 4 expert agents
**Target:** Phase 1 Proof of Concept — Counter app with native UIKit rendering

---

## Table of Contents

1. [Research Synthesis & Key Decisions](#1-research-synthesis--key-decisions)
2. [Risks & Mitigations](#2-risks--mitigations)
3. [Phase 1 Scope (PoC)](#3-phase-1-scope-poc)
4. [Implementation Order (File-by-File)](#4-implementation-order-file-by-file)
5. [Step 0: Monorepo & Tooling Setup](#step-0-monorepo--tooling-setup)
6. [Step 1: Swift Native Foundation](#step-1-swift-native-foundation)
7. [Step 2: JS Runtime & Vue Custom Renderer](#step-2-js-runtime--vue-custom-renderer)
8. [Step 3: Bridge Integration](#step-3-bridge-integration)
9. [Step 4: Layout Engine (Yoga)](#step-4-layout-engine-yoga)
10. [Step 5: Core Components](#step-5-core-components)
11. [Step 6: Vite Build Pipeline](#step-6-vite-build-pipeline)
12. [Step 7: Demo App & Xcode Project](#step-7-demo-app--xcode-project)
13. [Step 8: Testing & Validation](#step-8-testing--validation)
14. [Dependency Graph](#dependency-graph)
15. [Package Versions & Dependencies](#package-versions--dependencies)
16. [What's Deferred to Phase 2](#whats-deferred-to-phase-2)

---

## 1. Research Synthesis & Key Decisions

### Vue 3 Custom Renderer (from vue-renderer-researcher)

- **`createRenderer()`** is well-designed for non-DOM targets. Required methods: `createElement`, `createText`, `createComment`, `setText`, `setElementText`, `patchProp`, `insert`, `remove`, `parentNode`, `nextSibling`. Optional: `setScopeId`, `cloneNode`, `insertStaticContent`.
- **`@vue/runtime-core` has NO DOM dependencies.** It's the correct import (not `@vue/runtime-dom`). Works in any JS environment. Only needs `Promise` and `globalThis` which JSC provides natively.
- **CRITICAL: `markRaw()` on all nodes.** Vue's `@vue/runtime-test` (the gold standard reference) wraps every created node with `markRaw()` from `@vue/reactivity`. Without this, Vue's reactivity system tries to make node internals reactive, causing massive performance issues. Our `createNativeNode()` MUST call `markRaw(node)`.
- **Features that work automatically:** Composition API (ref, reactive, computed, watch, watchEffect), Pinia, provide/inject, v-model (via emits), Suspense, component lifecycle hooks, v-for, v-if, slots, async components, error boundaries.
- **Features needing special handling:** Teleport (needs `querySelector` in RendererOptions or string targets won't work), Transition/TransitionGroup (runtime-core exports `BaseTransition` which is platform-agnostic — we build native animations on top), `v-show` (DOM directive — needs custom native directive mapping to `isHidden`), KeepAlive (works at component level but native view caching needs thought).
- **Vue's scheduler uses ONLY `Promise.resolve().then()`** for async batching — NO MutationObserver, NO setTimeout. Since JSC supports Promises natively (iOS 13+), the scheduler works perfectly.
- **Existing custom renderers** (TresJS/vue-three, NativeScript-Vue, vue-pdf, runtime-test) all follow the same pattern: lightweight JS proxy objects that mirror the native structure. NativeScript-Vue is the most relevant — it runs JS in an embedded engine and maps to native views.
- **Bundling risk:** Must externalize `@vue/runtime-core` to avoid duplicate Vue instances. If two copies exist, internal state like `currentRenderingInstance` becomes null, causing `resolveComponent` errors.

### JavaScriptCore + Swift (from ios-native-researcher)

- **Threading:** JSContext is NOT thread-safe. Use a dedicated serial `DispatchQueue` for all JS operations. Never pass `JSValue` across threads — extract primitives first.
- **Function calls:** Use `@convention(block)` closures for registering Swift functions. Use `objectForKeyedSubscript().call()` instead of `evaluateScript()` for repeated calls (avoids re-parsing).
- **Memory:** Use `[weak self]` in all closures registered with JSContext. Use proxy objects to avoid retain cycles. Never store `JSValue` long-term.
- **Polyfills required:** setTimeout/clearTimeout, setInterval/clearInterval, queueMicrotask, requestAnimationFrame (via CADisplayLink), console.log/warn/error, performance.now(), globalThis.
- **Promise:** Built into JSC since iOS 13+. No polyfill needed.
- **Critical risk:** JSC's microtask queue only drains when control returns to the JSC runloop. We need to implement a proper event loop that alternates between processing native events and draining JS microtasks.
- **Batch pattern:** Accumulate UI commands in JS, flush to Swift in one call. This is validated by React Native's approach and real-world production apps (Cash App, Lucid).

### Yoga/FlexLayout (from layout-researcher)

- **Recommended package:** `layoutBox/FlexLayout` v2.x (wraps Yoga 3.0.4). 2.1k stars, actively maintained (last release Dec 2025), full SPM support including dynamic linking, iOS 13+, MIT license.
  - GitHub: https://github.com/layoutBox/FlexLayout
  - Alternative: Use facebook/yoga C API directly with custom Swift wrapper (more control but more work)
- **FlexLayout API is chainable-builder style** (`view.flex.direction(.row).padding(10)`), which doesn't map well to our programmatic property-setter needs. For Phase 1, we can work around this. For Phase 2+, consider building our own thin Yoga wrapper with setter API.
- **Shadow tree recommended over direct UIView yoga:** React Native uses a shadow tree (YGNode tree in C++) separate from the UIView tree. Layout is computed on the shadow tree (can be background thread), then only changed frames are applied to UIViews. Direct Yoga-on-UIView forces main-thread layout. For Phase 1 PoC, direct UIView yoga is simpler and acceptable. Phase 2 should move to shadow tree.
- **Performance:** Yoga is 8-12x faster than UIStackView. Sub-millisecond for 500+ nodes. Layout is O(n) for most cases. Background-thread layout is possible (Yoga C core is thread-safe).
- **Yoga has built-in dirty flagging:** Changed nodes are auto-marked dirty. `HasNewLayout` flag lets us skip unchanged subtrees when applying frames.
- **CRITICAL: Enable web defaults.** Yoga defaults differ from CSS: `flexDirection` defaults to `column` (fine), `flexShrink` defaults to `0` (CSS is `1`), `flexBasis` defaults to `0` (CSS is `auto`). Use `useWebDefaults: true` for CSS-like behavior that Vue developers expect.
- **CRITICAL: Text measurement.** Yoga needs a measure function for text nodes (UILabel/UITextView). Without it, text nodes have zero intrinsic size. Must implement Yoga's `YGMeasureFunc` callback that calls `sizeThatFits()` on the UILabel.
- **Set `PointScaleFactor`** to `UIScreen.main.scale` (2.0/@2x, 3.0/@3x) for pixel-perfect rendering.
- **Gotchas:**
  - UIScrollView: Don't yoga the scroll view itself. Use content-view pattern inside it.
  - UITableView/UICollectionView: Use native cell recycling, not Yoga for the list.
  - Don't mix Auto Layout constraints with Yoga in the same view hierarchy subtree.
  - Safe areas: Yoga doesn't know about `safeAreaInsets` — must account manually.
  - FlexLayout Dec 2025 fixed a bug with dynamic view removal — critical for our Vue-driven dynamic views.
  - Gap/row-gap/column-gap fully supported in Yoga 3.0+ (FlexLayout v2.x includes this).

### Build Tooling (from build-tooling-researcher)

- **Monorepo:** pnpm workspaces + turborepo. Use `workspace:*` protocol for inter-package deps. Install deps in packages, not root.
- **Vite build produces TWO outputs:**
  1. Standard ESM/CJS for npm package consumption (`vite build` in library mode)
  2. IIFE bundle for JSC evaluation (`vite build --config vite.config.bundle.ts`)
- **IIFE is CRITICAL:** `format: 'iife'` + `inlineDynamicImports: true` wraps everything in a single self-executing function. JSC cannot use ESM imports. The IIFE exposes a global `VueNativeApp` object.
- **Target ES2020:** JSC on iOS 16+ supports optional chaining, nullish coalescing, BigInt, Promise.allSettled, globalThis.
- **Vue compiler:** `@vue/compiler-sfc` handles SFC compilation. Configure `isNativeTag` and `isCustomElement` in template compiler options so our native tags don't warn. Alias `vue` → `@vue-native/runtime`.
- **CSS-to-StyleObject transformation** must happen at compile time (Vite plugin), not runtime. JSC has no CSS engine. For Phase 1, developers use `createStyleSheet()` JS objects directly (no CSS blocks). Phase 2 adds a Vite plugin that transforms `<style native>` blocks.
- **Swift Package Manager:** Package.swift with FlexLayout dependency. JS bundle embedded as SPM resource via `.copy("Resources/vue-native-bundle.js")`.
- **Xcode integration:** Add local SPM package reference. Optional "Run Script" build phase to rebuild JS bundle before each Xcode build. AppDelegate initializes bridge and loads bundle.
- **Dev server strategy:** Start with full-reload on save (rebuild entire IIFE via Vite watch mode, reload in JSC). This avoids the complexity of ESM module loading in JSC. Granular HMR with WebSocket client added in Phase 2.

---

## 2. Risks & Mitigations

| # | Risk | Severity | Mitigation |
|---|------|----------|------------|
| 1 | **JSC microtask queue doesn't drain properly** → Vue's reactivity batching breaks | **HIGH** | Vue's scheduler uses ONLY `Promise.resolve().then()` — no DOM APIs. JSC has native Promise support. Test early: evaluate a script that uses `queueMicrotask`, verify it runs before next `evaluateScript()` call. If not, force drain with `context.evaluateScript("Promise.resolve().then(() => {})")`. |
| 2 | **Missing `markRaw()` on nodes** → Vue reactivity tracks node internals, causing perf crash | **HIGH** | Every `NativeNode` created by the renderer MUST be wrapped with `markRaw()` from `@vue/reactivity`. This is validated by Vue's own `runtime-test` implementation. Add to `createNativeNode()` factory. |
| 3 | **JSC threading crashes from JSValue cross-thread access** | **HIGH** | Strict rule: ALL JSValue usage on the JS DispatchQueue. Extract to Dictionary/String/Int before dispatching to main thread. Cash App learned this the hard way in production. |
| 4 | **Text measurement missing** → Text nodes have zero size in Yoga | **HIGH** | Must implement Yoga's `YGMeasureFunc` callback for text nodes that calls `UILabel.sizeThatFits()`. Without this, VText will collapse to 0x0. |
| 5 | **FlexLayout SPM package API mismatch** | MEDIUM | FlexLayout uses chainable builder API, not property setters. For Phase 1, use FlexLayout's API directly. For Phase 2, evaluate building thin Yoga C wrapper with setter API. Verify package builds on Xcode 15+ / iOS 16+. |
| 6 | **Vite IIFE bundle incompatible with JSC** | MEDIUM | Test a minimal Vue 3 IIFE bundle in JSC early (Step 0 validation). Check for unsupported ES features. Must use `inlineDynamicImports: true`. |
| 7 | **Duplicate Vue instances in bundle** | MEDIUM | If two copies of `@vue/runtime-core` exist at runtime, internal state breaks (`currentRenderingInstance` is null). Must externalize Vue in library builds or ensure single copy in IIFE. |
| 8 | **Retain cycles between JSContext and Swift objects** | MEDIUM | Use `[weak self]` in ALL closures registered with JSContext. Use proxy objects. Never store JSValue long-term. Implement `invalidate()` teardown. |
| 9 | **Yoga defaults differ from CSS** | MEDIUM | `flexShrink` defaults to 0 (CSS: 1), `flexBasis` defaults to 0 (CSS: auto). Enable `useWebDefaults: true` in Yoga config, or translate values in StyleEngine. |
| 10 | **Vue's Teleport/Transition break without DOM** | LOW | Exclude from Phase 1. `BaseTransition` from runtime-core is available for Phase 2 native animations. |

---

## 3. Phase 1 Scope (PoC)

### What We Build

A Vue SFC renders a **counter app** with:
- A text display showing "Count: N"
- A text input with v-model (two-way binding)
- Increment/decrement buttons
- Styled layout using flexbox (centered, padded, colored)
- All rendered as native UIKit views (UILabel, UITextField, UIView, TouchableView)

### What We DON'T Build in Phase 1

- Navigation system
- VList (view recycling)
- VImage (async loading)
- Native modules (Camera, Geolocation, etc.)
- Hot reload / dev server
- CLI tool
- Animations
- 20+ additional components
- Android anything

### Component Set (Phase 1: 5 components)

| Component | UIKit View | Props |
|-----------|-----------|-------|
| `VView` | `UIView` | style |
| `VText` | `UILabel` | style, text (via children) |
| `VButton` | `TouchableView` (custom) | style, disabled, onPress |
| `VInput` | `UITextField` | style, modelValue, placeholder, onChangeText |
| `__ROOT__` | `UIView` (root container) | — |

### Style Properties (Phase 1 subset)

**Layout:** flex, flexDirection, justifyContent, alignItems, alignSelf, width, height, padding (all), margin (all), gap
**Visual:** backgroundColor, borderRadius, borderWidth, borderColor, opacity
**Text:** fontSize, fontWeight, color, textAlign

---

## 4. Implementation Order (File-by-File)

```
STEP 0: Monorepo & Tooling Setup
  ├── package.json (root workspace)
  ├── pnpm-workspace.yaml
  ├── turbo.json
  ├── tsconfig.base.json
  ├── packages/runtime/package.json
  ├── packages/runtime/tsconfig.json
  └── packages/vite-plugin/package.json

STEP 1: Swift Native Foundation
  ├── native/Package.swift
  ├── native/Sources/VueNativeCore/Bridge/JSRuntime.swift        [NEW - wraps JSContext + DispatchQueue]
  ├── native/Sources/VueNativeCore/Bridge/JSPolyfills.swift
  ├── native/Sources/VueNativeCore/Bridge/NativeBridge.swift
  └── native/Sources/VueNativeCore/Helpers/UIColor+Hex.swift

STEP 2: JS Runtime & Vue Custom Renderer
  ├── packages/runtime/src/node.ts          [NativeNode interface + factory]
  ├── packages/runtime/src/bridge.ts        [NativeBridge JS side]
  ├── packages/runtime/src/renderer.ts      [Vue createRenderer implementation]
  └── packages/runtime/src/index.ts         [createApp + re-exports]

STEP 3: Bridge Integration (connecting Step 1 + Step 2)
  └── Validate: JS bridge calls reach Swift, operations are batched and processed

STEP 4: Layout Engine
  ├── native/Sources/VueNativeCore/Styling/StyleEngine.swift
  └── Validate: Yoga layout works on dynamically created UIViews

STEP 5: Core Components
  ├── native/Sources/VueNativeCore/Components/ComponentRegistry.swift
  ├── native/Sources/VueNativeCore/Components/NativeComponentFactory.swift  [protocol]
  ├── native/Sources/VueNativeCore/Components/Factories/VViewFactory.swift
  ├── native/Sources/VueNativeCore/Components/Factories/VTextFactory.swift
  ├── native/Sources/VueNativeCore/Components/Factories/VButtonFactory.swift
  ├── native/Sources/VueNativeCore/Components/Factories/VInputFactory.swift
  ├── native/Sources/VueNativeCore/Helpers/TouchableView.swift
  ├── native/Sources/VueNativeCore/Helpers/GestureWrapper.swift
  ├── packages/runtime/src/components/VView.ts
  ├── packages/runtime/src/components/VText.ts
  ├── packages/runtime/src/components/VButton.ts
  ├── packages/runtime/src/components/VInput.ts
  └── packages/runtime/src/components/index.ts

STEP 6: Vite Build Pipeline
  ├── packages/vite-plugin/src/index.ts
  └── vite.config.ts (for demo app)

STEP 7: Demo App + Xcode Project
  ├── examples/counter/app/main.ts
  ├── examples/counter/app/App.vue
  ├── examples/counter/ios/CounterApp.xcodeproj/
  ├── examples/counter/ios/CounterApp/AppDelegate.swift
  ├── examples/counter/ios/CounterApp/SceneDelegate.swift
  └── examples/counter/ios/CounterApp/Info.plist

STEP 8: Testing & Validation
  ├── packages/runtime/tests/renderer.test.ts
  ├── packages/runtime/tests/bridge.test.ts
  └── native/Tests/VueNativeCoreTests/BridgeTests.swift
```

---

## Step 0: Monorepo & Tooling Setup

**Goal:** Working monorepo where `pnpm install` succeeds and TypeScript compiles.

### Files to Create

**`/package.json`** (root)
```json
{
  "name": "vue-native-monorepo",
  "private": true,
  "packageManager": "pnpm@9.15.0",
  "scripts": {
    "build": "turbo run build",
    "dev": "turbo run dev",
    "test": "turbo run test",
    "lint": "turbo run lint",
    "clean": "turbo run clean"
  },
  "devDependencies": {
    "turbo": "^2.4.0",
    "typescript": "^5.7.0"
  }
}
```

**`/pnpm-workspace.yaml`**
```yaml
packages:
  - 'packages/*'
  - 'examples/*'
```

**`/turbo.json`**
```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "test": {
      "dependsOn": ["build"]
    },
    "clean": {
      "cache": false
    }
  }
}
```

**`/tsconfig.base.json`**
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true,
    "lib": ["ES2020"]
  }
}
```

**`/packages/runtime/package.json`**
```json
{
  "name": "@vue-native/runtime",
  "version": "0.1.0",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "files": ["dist"],
  "scripts": {
    "build": "tsup src/index.ts --format esm --dts",
    "dev": "tsup src/index.ts --format esm --dts --watch",
    "test": "vitest run",
    "clean": "rm -rf dist"
  },
  "dependencies": {
    "@vue/runtime-core": "^3.5.0",
    "@vue/reactivity": "^3.5.0",
    "@vue/shared": "^3.5.0"
  },
  "devDependencies": {
    "tsup": "^8.4.0",
    "vitest": "^2.2.0",
    "typescript": "^5.7.0"
  }
}
```

**`/packages/runtime/tsconfig.json`**
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist", "tests"]
}
```

**`/packages/vite-plugin/package.json`**
```json
{
  "name": "@vue-native/vite-plugin",
  "version": "0.1.0",
  "type": "module",
  "main": "./dist/index.js",
  "types": "./dist/index.d.ts",
  "files": ["dist"],
  "scripts": {
    "build": "tsup src/index.ts --format esm --dts",
    "dev": "tsup src/index.ts --format esm --dts --watch",
    "clean": "rm -rf dist"
  },
  "dependencies": {
    "vite": "^6.1.0"
  },
  "peerDependencies": {
    "vite": "^6.0.0"
  },
  "devDependencies": {
    "tsup": "^8.4.0",
    "typescript": "^5.7.0"
  }
}
```

### Validation Checkpoint
```bash
pnpm install
pnpm build  # Should compile all TS packages
```

---

## Step 1: Swift Native Foundation

**Goal:** Swift package that compiles, with JSContext running JS code and polyfills working.

### Files to Create

**`/native/Package.swift`**
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VueNativeCore",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "VueNativeCore", targets: ["VueNativeCore"])
    ],
    dependencies: [
        // Yoga layout engine — layoutBox/FlexLayout v2.x wraps Yoga 3.0.4
        // 2.1k stars, actively maintained (last release Dec 2025), full SPM support
        .package(url: "https://github.com/layoutBox/FlexLayout.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "VueNativeCore",
            dependencies: [
                .product(name: "FlexLayout", package: "FlexLayout")
            ],
            path: "Sources/VueNativeCore",
            resources: [
                .copy("Resources/vue-native-bundle.js")
            ]
        ),
        .testTarget(
            name: "VueNativeCoreTests",
            dependencies: ["VueNativeCore"],
            path: "Tests/VueNativeCoreTests"
        )
    ]
)
```

> **CONFIRMED:** `layoutBox/FlexLayout` is the correct repo (2.1k stars, Dec 2025 release). FlexLayout uses a chainable builder API; for Phase 1 we work with it directly, Phase 2 may add a thin property-setter wrapper.

**Key Swift files in this step:**

1. **`JSRuntime.swift`** — Wraps JSContext on a dedicated serial queue. Manages lifecycle, error handling, and thread safety. This is the single point of access for all JS execution.

2. **`JSPolyfills.swift`** — Registers setTimeout, setInterval, clearTimeout, clearInterval, queueMicrotask, requestAnimationFrame, console, performance.now, globalThis.

3. **`NativeBridge.swift`** — Registers `__VN_flushOperations`, `__VN_invokeModule`, `__VN_invokeModuleSync` on JSContext. Processes operation batches on main thread. Dispatches events back to JS thread.

4. **`UIColor+Hex.swift`** — Hex string to UIColor conversion utility.

### Validation Checkpoint
```bash
cd native && swift build  # Package compiles
# Write a test that creates JSContext, loads a simple JS script, and calls a Swift function
swift test
```

### Critical: Microtask Drain Test
```swift
// MUST validate this works before proceeding:
let context = JSContext()!
// Register polyfills...
context.evaluateScript("""
    let result = [];
    queueMicrotask(() => result.push('micro'));
    result.push('sync');
    // After this evaluateScript returns, 'result' should be ['sync', 'micro']
""")
let result = context.objectForKeyedSubscript("result")!.toArray()!
assert(result as! [String] == ["sync", "micro"])
```

If microtasks DON'T drain automatically after evaluateScript, we need to add a manual drain:
```swift
context.evaluateScript("Promise.resolve().then(() => {})") // Force drain
```

---

## Step 2: JS Runtime & Vue Custom Renderer

**Goal:** Vue's `createRenderer()` implemented with all required RendererOptions methods. Bridge JS side batches operations.

### Files to Create

**`/packages/runtime/src/node.ts`**
- `NativeNode` interface (id, type, props, children, parent, isText, text)
- `createNativeNode()` factory function — **MUST call `markRaw(node)` from `@vue/reactivity`**
- Node ID counter
- Pattern from Vue's `runtime-test`: nodes are lightweight proxy objects, never reactive

**`/packages/runtime/src/bridge.ts`**
- `NativeBridgeImpl` class
- Operation batching via `queueMicrotask`
- Event handler registry (`Map<string, EventCallback>`)
- `handleNativeEvent()` — called from Swift
- `resolveCallback()` — called from Swift for async operations
- Global exports: `__VN_handleEvent`, `__VN_resolveCallback`

**`/packages/runtime/src/renderer.ts`**
- `RendererOptions` implementation:
  - `createElement(type)` → creates NativeNode, calls bridge.createNode
  - `createText(text)` → creates text NativeNode, calls bridge.createTextNode
  - `createComment(text)` → returns placeholder (no-op on native)
  - `setText(node, text)` → updates text node, calls bridge.setText
  - `setElementText(node, text)` → calls bridge.setElementText
  - `patchProp(el, key, prevValue, nextValue)` → routes to event handlers, style diffing, or prop updates
  - `insert(child, parent, anchor?)` → manages children array, calls bridge.appendChild/insertBefore
  - `remove(child)` → removes from parent, calls bridge.removeChild
  - `parentNode(node)` → returns node.parent
  - `nextSibling(node)` → returns next child in parent's children array
  - `setScopeId(el, id)` → stores scope ID (for potential scoped styling)
- Export `createRenderer(rendererOptions)` result

**`/packages/runtime/src/index.ts`**
- `createApp()` wrapper that registers built-in components and adds `.start()` method
- Re-export all of `@vue/runtime-core` (ref, reactive, computed, watch, etc.)
- Export `createStyleSheet()`

### Validation Checkpoint
```bash
cd packages/runtime && pnpm test
# Test: Create a simple Vue component, render it through our renderer,
# verify the correct bridge operations are generated in order
```

### Unit Test: Renderer Operations
```typescript
// packages/runtime/tests/renderer.test.ts
import { createApp, ref, h } from '../src'

test('createElement generates bridge create operation', () => {
  const ops: any[] = []
  // Mock the bridge to capture operations
  // Render a VView with a VText child
  // Assert ops = [
  //   { op: 'create', args: [1, '__ROOT__'] },
  //   { op: 'create', args: [2, 'VView'] },
  //   { op: 'createText', args: [3, 'Hello'] },
  //   { op: 'appendChild', args: [2, 3] },
  //   { op: 'appendChild', args: [1, 2] },
  //   { op: 'setRootView', args: [1] },
  // ]
})
```

---

## Step 3: Bridge Integration

**Goal:** JS bridge calls successfully reach Swift, operations are batched, UI updates happen on main thread.

This step is primarily integration work — connecting Step 1 (Swift) and Step 2 (JS).

### Tasks

1. **Build the JS runtime bundle** using Vite (or manually with esbuild for now) into an IIFE that JSC can evaluate.
2. **Load the bundle in JSContext** via `evaluateScript()`.
3. **Verify the full cycle:**
   - JS: `NativeBridge.createNode(1, 'VView')` → enqueue operation
   - JS: microtask flushes → calls `__VN_flushOperations('[{"op":"create","args":[1,"VView"]}]')`
   - Swift: `__VN_flushOperations` receives JSON → parses → dispatches to main thread → creates UIView
4. **Verify event round-trip:**
   - Swift: user taps a view → `dispatchEventToJS(nodeId, "press", nil)`
   - JS: `__VN_handleEvent(1, 'press', null)` → handler fires → state updates → new operations batch

### Validation Checkpoint
```
Run in Xcode Simulator:
- App launches
- JSContext loads Vue runtime
- A UIView appears on screen (even just a colored rectangle)
```

---

## Step 4: Layout Engine (Yoga)

**Goal:** Style properties from JS translate to Yoga layout properties on UIViews. `applyLayout()` computes and applies frames. Text nodes have correct intrinsic sizes.

### Files to Create/Update

**`/native/Sources/VueNativeCore/Styling/StyleEngine.swift`**

Phase 1 subset of style properties:
- **Layout:** flex, flexDirection, justifyContent, alignItems, alignSelf, width, height, padding*, margin*, gap
- **Visual:** backgroundColor, borderRadius, borderWidth, borderColor, opacity
- **Text:** fontSize, fontWeight, color, textAlign

### Integration with NativeBridge

After `processOperations()` completes a batch:
```swift
// Trigger layout recalculation
rootView.flex.layout()
```

### CRITICAL: Text Measurement

Yoga needs a measure function for text nodes. Without it, UILabels collapse to 0x0 size.

```swift
// When creating a VText (UILabel), register a Yoga measure function:
// FlexLayout handles this automatically when you use .markDirty() on text changes,
// but we must ensure the UILabel's intrinsic content size is respected.
// FlexLayout's UIView+Yoga extension uses sizeThatFits() internally.
label.flex.markDirty()  // Call after any text/font change to trigger remeasurement
```

### Yoga Configuration

```swift
// Enable web defaults so CSS developers get expected behavior:
// - flexShrink defaults to 1 (not 0)
// - flexBasis defaults to auto (not 0)
// Set point scale factor for pixel-perfect rendering:
// YGConfigSetPointScaleFactor(config, Float(UIScreen.main.scale))
```

### Validation Checkpoint
```
In Xcode Simulator:
- Create 3 VViews with flexDirection: 'column', different background colors
- They should stack vertically with correct sizing
- Add padding/margin — layout adjusts correctly
- VText displays text with correct intrinsic size (not collapsed to 0x0)
- VText with numberOfLines=1 truncates correctly
```

---

## Step 5: Core Components

**Goal:** 5 components working: VView, VText, VButton, VInput, __ROOT__

### Swift Side — Component Factories

Each factory implements the `NativeComponentFactory` protocol:
```swift
protocol NativeComponentFactory {
    func createView() -> UIView
    func updateProp(view: UIView, key: String, value: Any?)
    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void)
}
```

| Factory | Key Props | Key Events |
|---------|-----------|------------|
| `VViewFactory` | style (via StyleEngine) | press (tap gesture) |
| `VTextFactory` | text, numberOfLines, fontSize, fontWeight, color, textAlign | — |
| `VButtonFactory` | disabled, activeOpacity | press, longPress |
| `VInputFactory` | text (value), placeholder, secureTextEntry, keyboardType | changeText, focus, blur, submit |
| `VRootFactory` | — | — |

### JS Side — Component Definitions

Thin Vue `defineComponent` wrappers that render to native element types:
```typescript
// VView: h('VView', { style }, slots.default?.())
// VText: h('VText', { ...props }, slots.default?.())
// VButton: h('VButton', { ...props, onPress }, slots.default?.())
// VInput: h('VInput', { text: modelValue, onChangetext: emit }, [])
```

### VInput v-model Support

The VInput component must support Vue's `v-model` via:
- Prop: `modelValue` → mapped to native `text` property
- Event: `update:modelValue` → emitted when native text changes via `onChangetext`

### TouchableView (Custom UIView)

Custom UIView subclass for VButton that handles:
- Touch began: animate to `activeOpacity`
- Touch ended: animate back to 1.0, fire `onPress` if touch is within bounds
- Touch cancelled: animate back to 1.0
- Long press via UILongPressGestureRecognizer

### Validation Checkpoint
```
In Xcode Simulator:
- VText displays "Hello Vue Native"
- VButton responds to tap with opacity feedback
- VInput accepts text entry
- All styled with backgroundColor, padding, borderRadius
```

---

## Step 6: Vite Build Pipeline

**Goal:** `pnpm build` produces `vue-native-bundle.js` (IIFE) loadable by JSC.

### Files to Create

**`/packages/vite-plugin/src/index.ts`**
```typescript
// Vite plugin that:
// 1. Aliases 'vue' → '@vue-native/runtime'
// 2. Defines __DEV__ and __PLATFORM__
// 3. Configures IIFE output with inlineDynamicImports
// 4. Strips <style> CSS blocks (we use JS style objects)
```

**`/examples/counter/vite.config.ts`**
```typescript
// Uses @vue-native/vite-plugin
// Entry: app/main.ts
// Output: dist/vue-native-bundle.js (IIFE format)
```

### Key Vite Configuration

```typescript
{
  build: {
    target: 'es2020',
    lib: {
      entry: 'app/main.ts',
      formats: ['iife'],
      name: 'VueNativeApp',
      fileName: 'vue-native-bundle',
    },
    rollupOptions: {
      output: { inlineDynamicImports: true }
    }
  },
  resolve: {
    alias: { 'vue': '@vue-native/runtime' }
  },
  define: {
    __DEV__: 'true',
    __PLATFORM__: '"ios"'
  }
}
```

### Validation Checkpoint
```bash
cd examples/counter && pnpm build
# Produces dist/vue-native-bundle.js
# File is valid JS loadable by JSC (no import/export, no DOM APIs)
```

---

## Step 7: Demo App & Xcode Project

**Goal:** The counter app runs on iOS Simulator as a native UIKit app.

### Demo App Files

**`/examples/counter/app/main.ts`**
```typescript
import { createApp, ref, computed } from 'vue-native'
import App from './App.vue'
const app = createApp(App)
app.start()
```

**`/examples/counter/app/App.vue`**
```vue
<template>
  <VView :style="styles.container">
    <VText :style="styles.title">{{ greeting }}</VText>
    <VInput v-model="name" placeholder="Enter your name" :style="styles.input" />
    <VText :style="styles.counter">Count: {{ count }}</VText>
    <VView :style="styles.buttonRow">
      <VButton :style="styles.button" @press="count++">
        <VText :style="styles.buttonText">+</VText>
      </VButton>
      <VButton :style="styles.button" @press="count--">
        <VText :style="styles.buttonText">-</VText>
      </VButton>
    </VView>
  </VView>
</template>

<script setup>
import { ref, computed, createStyleSheet } from 'vue-native'

const name = ref('')
const count = ref(0)
const greeting = computed(() => name.value ? `Hello, ${name.value}!` : 'Hello, Vue Native!')

const styles = createStyleSheet({
  container: { flex: 1, padding: 24, justifyContent: 'center', backgroundColor: '#f8f9fa' },
  title: { fontSize: 28, fontWeight: 'bold', color: '#1a1a2e', textAlign: 'center', marginBottom: 16 },
  input: { backgroundColor: '#fff', borderRadius: 12, padding: 14, fontSize: 16, borderWidth: 1, borderColor: '#e0e0e0', marginBottom: 16 },
  counter: { fontSize: 20, fontWeight: 'bold', textAlign: 'center', marginBottom: 12, color: '#1a1a2e' },
  buttonRow: { flexDirection: 'row', gap: 12, justifyContent: 'center' },
  button: { backgroundColor: '#4361ee', borderRadius: 8, padding: 12, width: 60, alignItems: 'center' },
  buttonText: { color: '#fff', fontSize: 18, fontWeight: '600' },
})
</script>
```

### Xcode Project

**`/examples/counter/ios/`** — Minimal Xcode project:

- **AppDelegate.swift**: Initializes `NativeBridge.shared.initialize(rootViewController:)`
- **SceneDelegate.swift**: Creates the root UIViewController and passes to NativeBridge
- **Info.plist**: Bundle ID, display name, etc.
- **Dependency**: VueNativeCore Swift package (local path reference)
- **Resource**: `vue-native-bundle.js` (copied from Vite build output)

### Build & Run Process
```bash
# 1. Build JS bundle
cd examples/counter && pnpm build

# 2. Copy bundle to Xcode project
cp dist/vue-native-bundle.js ios/CounterApp/

# 3. Open and run in Xcode
open ios/CounterApp.xcodeproj
# Cmd+R to build and run on Simulator
```

### Validation Checkpoint (Phase 1 Success Criteria)
```
On iOS Simulator:
✅ App launches and shows "Hello, Vue Native!"
✅ Text input accepts keyboard entry
✅ Greeting updates reactively as you type
✅ Counter displays "Count: 0"
✅ Tapping "+" increments the counter
✅ Tapping "-" decrements the counter
✅ Buttons show opacity feedback on press
✅ Layout is centered with proper padding/spacing
✅ Background colors and border radius render correctly
✅ 60 FPS (no visible lag/jank on interactions)
```

---

## Step 8: Testing & Validation

### JS Unit Tests (Vitest)

| Test | What It Validates |
|------|------------------|
| `renderer.test.ts` | createElement, createText, insert, remove generate correct bridge ops |
| `bridge.test.ts` | Operations batch via microtask, flush produces correct JSON |
| `patchProp.test.ts` | Style diffing, event handler registration, prop updates |
| `components.test.ts` | VView, VText, VButton, VInput render correct elements with props |

### Swift Unit Tests (XCTest)

| Test | What It Validates |
|------|------------------|
| `JSRuntimeTests.swift` | JSContext creates, polyfills work, evaluateScript works |
| `BridgeTests.swift` | Operation JSON parsing, view creation, event dispatch |
| `StyleEngineTests.swift` | Style props map to correct Yoga values and UIView properties |
| `ComponentRegistryTests.swift` | Factory lookup, prop updates, event wiring |

### Integration Test

| Test | What It Validates |
|------|------------------|
| Full render cycle | Vue component → bridge ops → native view hierarchy |
| Event round-trip | Tap → JS handler → state update → re-render → UI update |
| Reactivity | ref() change → computed updates → patchProp → native view updates |

---

## Dependency Graph

```
                    ┌──────────────┐
                    │  Demo App    │
                    │  (App.vue)   │
                    └──────┬───────┘
                           │ imports
                    ┌──────▼───────┐
                    │ Vite Plugin  │──── builds ────┐
                    └──────┬───────┘                │
                           │ transforms             │
                    ┌──────▼───────┐         ┌──────▼───────┐
                    │   Runtime    │         │  JS Bundle   │
                    │ (renderer,  │         │  (IIFE)      │
                    │  bridge JS, │         └──────┬───────┘
                    │  components)│                │ loaded by
                    └──────┬───────┘         ┌──────▼───────┐
                           │                 │  JSContext    │
                    ┌──────▼───────┐         │  (JSRuntime) │
                    │ @vue/runtime │         └──────┬───────┘
                    │    -core     │                │ calls
                    └──────────────┘         ┌──────▼───────┐
                                             │ NativeBridge │
                                             │   (Swift)    │
                                             └──────┬───────┘
                                                    │ uses
                                   ┌────────────────┼────────────────┐
                            ┌──────▼──────┐  ┌──────▼──────┐  ┌─────▼──────┐
                            │ Component   │  │   Style     │  │  FlexLayout│
                            │  Registry   │  │   Engine    │  │   (Yoga)   │
                            └─────────────┘  └─────────────┘  └────────────┘
```

---

## Package Versions & Dependencies

### JS Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `@vue/runtime-core` | ^3.5.0 | Vue 3 core (createRenderer, reactivity) |
| `@vue/reactivity` | ^3.5.0 | Transitive via runtime-core |
| `@vue/shared` | ^3.5.0 | Transitive via runtime-core |
| `@vue/compiler-sfc` | ^3.5.0 | SFC compilation (dev dependency) |
| `vite` | ^6.1.0 | Build tool |
| `@vitejs/plugin-vue` | ^5.2.0 | Vue SFC support in Vite |
| `typescript` | ^5.7.0 | Type checking |
| `tsup` | ^8.4.0 | TypeScript bundling for packages |
| `vitest` | ^2.2.0 | Testing |
| `turbo` | ^2.4.0 | Monorepo task runner |
| `pnpm` | ^9.15.0 | Package manager |

### Swift Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `FlexLayout` (layoutBox/FlexLayout) | ^2.0.0 | Yoga 3.0.4 flexbox layout, Swift wrapper, SPM |
| iOS SDK | 16.0+ | Minimum deployment target |
| Xcode | 15.0+ | Build tool |
| Swift | 5.9+ | Language version |

### System Requirements

| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | 20+ | JS tooling |
| pnpm | 9+ | Package manager |
| Xcode | 15+ | iOS build |
| macOS | 14+ (Sonoma) | Development machine |
| iOS Simulator | 16+ | Testing |

---

## What's Deferred to Phase 2

| Feature | Why Deferred |
|---------|-------------|
| Navigation system | Requires UINavigationController integration + router |
| VImage (async loading) | Needs URLSession integration + caching layer |
| VList (view recycling) | Complex UITableView/UICollectionView integration |
| VScroll | UIScrollView + Yoga interaction has edge cases |
| Native modules (Camera, etc.) | Requires NativeModuleRegistry + composables |
| Hot reload / dev server | WebSocket server + bundle reloading |
| CLI tool | Project scaffolding, run/build commands |
| Animations | Native UIView.animate + spring physics |
| VSwitch, VSlider, etc. | Additional component factories |
| Hermes engine | Alternative JS engine option |
| MessagePack bridge | Binary serialization optimization |
| Pinia integration testing | Should work but needs validation |
| TypeScript declarations | Full type defs for components |
| Error overlay | Dev-mode error display |
| Dark mode | Dynamic color scheme support |
| Accessibility | VoiceOver, Dynamic Type |

---

## Parallelization Opportunities

The following can be developed in parallel by separate developers:

| Track A (JS) | Track B (Swift) |
|--------------|----------------|
| Step 0: Monorepo setup | Step 1: Swift package setup |
| Step 2: Renderer + Bridge JS | Step 1: JSRuntime + Polyfills + Bridge Swift |
| Step 5: JS component defs | Step 5: Component factories |
| Step 6: Vite plugin | Step 4: StyleEngine |

**Step 3 (Bridge Integration)** is a sync point — both tracks must be complete.
**Step 7 (Demo App)** requires all previous steps.

---

## Summary

This plan targets a **focused, achievable PoC** that proves Vue 3 can render to native UIKit views through a JS bridge. The key technical risks are:

1. **JSC microtask draining** — must validate early (Step 1)
2. **Bridge performance** — batching pattern is well-proven but needs our implementation
3. **Yoga SPM package availability** — need to verify the exact package URL

The PoC should be achievable in **2-3 weeks** with focused effort, producing a working counter app that demonstrates:
- Vue's reactivity driving native UI updates
- Two-way data binding (v-model) across the JS↔Swift bridge
- Flexbox layout via Yoga
- Touch event handling with visual feedback
- Clean, composable developer API

Once Phase 1 is validated, Phase 2 scales the component set, adds navigation, native modules, and developer tooling.
