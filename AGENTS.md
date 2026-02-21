# AGENTS.md — Vue Native

Guidelines for AI agents (Claude, Codex, Gemini, etc.) working on this codebase.

---

## What This Project Is

Vue Native renders Vue.js 3 SFCs to native iOS (UIKit) and Android (Android Views) using:
- **JavaScriptCore** (iOS) / **V8 via J2V8** (Android) — runs the Vue bundle
- A **custom Vue renderer** (`createRenderer()`) that emits native view operations instead of DOM mutations
- A **JSON bridge** that batches those operations and dispatches them to native on the main thread
- **Yoga / FlexLayout** (iOS) and **FlexboxLayout** (Android) for CSS Flexbox layout

It is **not** a WebView wrapper. Every component maps to a real native view.

---

## Architecture

```
Vue SFC → Vite IIFE bundle → JS Engine (JSC / V8)
       → Vue custom renderer → NativeBridge (batched JSON ops)
       → Swift (iOS): UIKit + Yoga
       → Kotlin (Android): Android Views + FlexboxLayout
```

**Three worlds that must stay separated:**

| World | Language | Entry point |
|-------|----------|-------------|
| JS runtime | TypeScript | `packages/runtime/src/` |
| Build tooling | TypeScript | `packages/vite-plugin/src/` |
| Native iOS | Swift | `native/Sources/VueNativeCore/` |
| Native Android | Kotlin | `native/android/VueNativeCore/src/` |

---

## Monorepo Layout

```
packages/runtime/          @vue-native/runtime
  src/
    renderer.ts            Vue createRenderer() — insert/patch/remove ops
    bridge.ts              JS-side bridge: batches ops, calls __VN_flushOperations
    node.ts                NativeNode type + markRaw() factory
    stylesheet.ts          createStyleSheet() helper
    components/            VView, VText, VButton, VInput, VImage, VList, VModal, …
    composables/           useNetwork, useHaptics, useCamera, useGeolocation, …
    directives/            v-show
    index.ts               Public API + createApp()

packages/navigation/       @vue-native/navigation
  src/
    index.ts               createRouter, useRouter, useRoute, RouterView,
                           VNavigationBar, VTabBar, createTabNavigator

packages/vite-plugin/      @vue-native/vite-plugin
  src/
    index.ts               IIFE build config, Vue alias, __PLATFORM__ define

packages/cli/              @vue-native/cli
  src/
    cli.ts                 Commander entry (vue-native create/dev/run)
    commands/              create.ts, dev.ts, run.ts

native/Sources/VueNativeCore/   iOS Swift package
  Bridge/                  JSRuntime, NativeBridge, JSPolyfills, HotReloadManager
  Components/              ComponentRegistry + 20 factory files (VViewFactory, etc.)
  Styling/                 StyleEngine.swift (Yoga prop mapping)
  Modules/                 19 native modules (Haptics, AsyncStorage, Geolocation, …)
  Helpers/                 GestureWrapper, TouchableView

native/android/VueNativeCore/   Android Kotlin library
  Bridge/                  JSRuntime, NativeBridge, JSPolyfills, HotReloadManager
  Components/              ComponentRegistry + 20 factory files
  Styling/                 StyleEngine.kt (FlexboxLayout prop mapping)
  Modules/                 16 native modules

examples/
  counter/                 Minimal counter — good starting point
  todo/                    Todo list with filtering
  calculator/              Calculator UI
  tasks/                   Multi-screen app with navigation
  settings/                Settings screen with sliders + toggles
  social/                  Social feed with tab navigation
```

---

## Bridge Protocol

JS calls `__VN_flushOperations(json)` with a JSON array of operations. Each op:

```typescript
type BridgeOp =
  | { op: 'createView';   id: number; type: string; props: Record<string, unknown> }
  | { op: 'updateProp';   id: number; key: string;  value: unknown }
  | { op: 'insertChild';  id: number; parentId: number; index: number }
  | { op: 'removeChild';  id: number; parentId: number }
  | { op: 'setText';      id: number; text: string }
  | { op: 'addEventListener';    id: number; event: string }
  | { op: 'removeEventListener'; id: number; event: string }
  | { op: 'invokeNativeModule';  module: string; method: string; args: unknown[]; callbackId: number }
```

Native resolves module callbacks by calling `__VN_resolveCallback(callbackId, result, error)` in JS.
Native fires view events by calling `__VN_handleEvent(nodeId, eventName, payloadJson)` in JS.

---

## Critical Rules

### JavaScript / TypeScript

1. **`markRaw()` on every NativeNode.** Vue's reactivity will track node internals without this, causing severe performance regressions. See `node.ts`.

2. **Never import from `@vue/runtime-dom`.** Use `@vue/runtime-core` only. `runtime-dom` is DOM-specific and fails in JSC/V8.

3. **No ESM dynamic imports in bundles.** JSC/V8-via-IIFE has no ESM loader. The Vite build produces an IIFE with `inlineDynamicImports: true`. Any `import()` will silently fail.

4. **Externalize `@vue/runtime-core` in library builds.** Two copies break `resolveComponent()` everywhere.

5. **All bridge calls must be batched.** Never flush per-property. Accumulate ops and call `__VN_flushOperations` once per microtask tick.

### Swift (iOS)

6. **JSContext is NOT thread-safe.** All JS evaluation and all `JSValue` access must happen on the dedicated `jsQueue` (serial DispatchQueue). Never capture a `JSValue` cross-thread — extract primitives first.

7. **`[weak self]` in every JSContext closure.** Missing weak references create retain cycles that prevent JSContext from deallocating.

8. **Never store `JSValue` long-term.** Extract what you need immediately; stored `JSValue` keeps the entire JSContext alive.

9. **Do not mix Auto Layout with Yoga in the same hierarchy.** Use Yoga exclusively for all Vue-managed views.

10. **Text nodes require a Yoga measure function.** Without `YGMeasureFunc`, `UILabel` dimensions are zero and layout collapses.

### Kotlin (Android)

11. **V8 (J2V8) is NOT thread-safe.** All V8 operations must run on the dedicated `HandlerThread` (`VueNative-JS`). Never call `v8.executeScript()` from the main thread.

12. **`View` operations must run on the main thread.** Use `Handler(Looper.getMainLooper()).post { }` to dispatch from the JS thread to UI.

13. **Never pass `V8Object` or `V8Array` across threads.** Extract primitives (String, Int, Map) before dispatching to another thread.

---

## Coding Conventions

### TypeScript

- Use `interface` for public-facing types, `type` for unions/aliases
- No `any` — use `unknown` and narrow explicitly
- Export types separately: `export type { Foo }`

### Swift

- Follow Swift API Design Guidelines (no Hungarian notation, clear argument labels)
- All public types exposed to JSC prefixed `VN` (e.g., `VNBridge`)
- Error handling: `Result<T, Error>` for bridge operations; never swallow errors silently
- Log prefix: `[VueNative]` for all `os_log` calls

### Kotlin

- Standard Kotlin style; prefer `?.` safe calls over `!!`
- All bridge callbacks dispatched through `bridge.onFireEvent` — never directly call V8 from other threads
- Factory `createView()` must be called on the main thread and return a fully initialized `View`

### File naming

- TypeScript: `camelCase.ts` for modules, `PascalCase.ts` for class files
- Swift: `PascalCase.swift` matching the primary type
- Kotlin: `PascalCase.kt` matching the primary class
- Tests: `*.test.ts` (Vitest), `*Tests.swift` (XCTest)

---

## Common Pitfalls

| Symptom | Likely cause |
|---------|-------------|
| `resolveComponent` returns null at runtime | Duplicate Vue instances. Externalize `@vue/runtime-core`. |
| Vue reactivity becomes extremely slow | Missing `markRaw()` on NativeNode. |
| Text nodes have zero height | Yoga measure function not set for text nodes. |
| JSC crashes with `EXC_BAD_ACCESS` | `JSValue` accessed off `jsQueue`. |
| Layout doesn't match CSS | Yoga web defaults not enabled (`useWebDefaults: true`). |
| Dynamic imports fail silently | ESM not supported. Use `inlineDynamicImports: true`. |
| Bridge calls cause UI jank | Not batching bridge commands — accumulate per frame, flush once. |
| Memory leak after JSContext teardown | Retain cycle from missing `[weak self]` in JSContext closures. |
| Android crash: `UnsatisfiedLinkError` | J2V8 `.so` not present for target ABI. Check `j2v8` artifact includes arm64-v8a. |
| Android fetch concurrent calls resolve to same value | Always pass a unique request ID to `__vnFetch`. See `JSPolyfills.kt`. |

---

## Running the Project

```bash
# Install JS dependencies
bun install

# Build all packages
bun run build

# Watch mode
bun run dev

# Type check
bun run typecheck

# Tests
bun run test
```

**iOS:** Open `examples/counter/ios/` in Xcode 15+, build for iOS 16+ simulator.
The SPM package resolves `VueNativeCore` from `../../native/`.

**Android:** Open `native/android/` in Android Studio, run on API 21+ emulator.
The library is referenced via `include(":VueNativeCore")` in `settings.gradle.kts`.

---

## References

- [Vue `@vue/runtime-test`](https://github.com/vuejs/core/tree/main/packages/runtime-test) — reference implementation for custom renderers
- [FlexLayout (Yoga Swift wrapper)](https://github.com/layoutBox/FlexLayout) — iOS layout engine
- [JavaScriptCore docs](https://developer.apple.com/documentation/javascriptcore) — Apple's JSC Swift API
- [J2V8](https://github.com/eclipsesource/J2V8) — V8 for Android (Java/Kotlin bindings)
- [FlexboxLayout](https://github.com/google/flexbox-layout) — Android CSS Flexbox
