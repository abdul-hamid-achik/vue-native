# AGENTS.md — Vue Native

Guidelines for AI agents (Claude, Codex, etc.) working on this codebase. Read this before making any changes.

---

## What this project is

Vue Native is a framework for building **real native iOS and Android apps with Vue 3**. It is NOT a WebView wrapper. Vue components drive `UIKit` views on iOS and `Android Views` on Android via a custom `createRenderer()` bridge.

```
Vue SFC  →  Vue custom renderer  →  NativeBridge (TS)
                                          ↓  JSON batch
                                  iOS: Swift → UIKit + Yoga
                                  Android: Kotlin → Views + FlexboxLayout
```

---

## Repository layout

```
packages/
  runtime/          @thelacanians/vue-native-runtime — renderer, bridge, components, composables
  navigation/       @thelacanians/vue-native-navigation — createRouter, RouterView, useRouter
  vite-plugin/      @thelacanians/vue-native-vite-plugin — Vite build config for native targets
  cli/              @thelacanians/vue-native-cli — project scaffold + dev tooling
native/
  ios/VueNativeCore/         Swift Package (iOS 16+, UIKit, JavaScriptCore, Yoga)
    Package.swift
    Sources/VueNativeCore/
      Bridge/                JSRuntime, NativeBridge, VueNativeViewController,
                             HotReloadManager, JSPolyfills, ErrorOverlayView,
                             EventThrottle, CertificatePinning
      Components/Factories/  One Swift factory per component (VButtonFactory, etc.)
      Modules/               Native module implementations (Haptics, Camera, etc.)
      Styling/               StyleEngine.swift — CSS props → UIKit/Yoga
      Helpers/               Extensions, GestureWrapper, TouchableView, UIColor+Hex
    Tests/VueNativeCoreTests/
  android/VueNativeCore/     Android library (API 21+, Kotlin, J2V8/V8, FlexboxLayout)
    src/main/kotlin/com/vuenative/core/
      Bridge/                JSRuntime, NativeBridge, HotReloadManager, JSPolyfills,
                             ErrorOverlayView
      Components/Factories/  One Kotlin factory per component
      Modules/               Native module implementations
      Styling/               StyleEngine.kt — CSS props → FlexboxLayout/View
      Helpers/               EventThrottle, GestureHelper, TouchableView
      VueNativeActivity.kt   Base Activity for apps
    src/test/kotlin/com/vuenative/core/
docs/
  src/               VuePress 2.x documentation site (bun run dev in docs/)
examples/
  counter/  calculator/  settings/  social/  tasks/  todo/
  auth-flow/  chat/  camera-app/  forms/  lists/
  navigation-demo/  media-player/  theming/
tools/
  vscode-extension/  VS Code snippets + diagnostics
  nvim-plugin/       Neovim snippets + completion + diagnostics
```

---

## Pre-commit and pre-push checklist

**IMPORTANT:** Before committing or pushing ANY changes, you MUST verify the affected code passes all quality gates. Failing to do so will break CI and block other contributors.

### TypeScript / JavaScript / Vue changes (`packages/`, `examples/`, `docs/`)

```bash
# All three must pass before committing:
bun run lint              # ESLint — fix errors, don't ignore warnings
bun run typecheck         # tsc --noEmit via turbo — zero errors required
bun test                  # Bun test runner (640+ tests, 0 failures required)
```

The `lefthook` pre-commit hook runs lint + typecheck automatically, but **you must also run tests manually** before pushing. The hook does NOT run tests.

### Swift changes (`native/ios/`)

```bash
# Both must pass before committing:
cd native/ios/VueNativeCore && swift build    # Compilation check
cd native/ios/VueNativeCore && swift test     # XCTest suite — all tests must pass
```

### Kotlin changes (`native/android/`)

```bash
# Both must pass before committing:
cd native/android && ./gradlew :VueNativeCore:compileDebugKotlin      # Compilation check
cd native/android && ./gradlew :VueNativeCore:testDebugUnitTest       # JUnit + Robolectric — all tests must pass
```

### Cross-language changes

When a change spans multiple languages (e.g., adding a component requires TS + Swift + Kotlin), run ALL relevant checks before committing. Use the convenience scripts:

```bash
bun run test:all          # Runs TS tests + iOS tests + Android tests
```

### Documentation changes (`docs/`)

```bash
cd docs && bun run build  # VuePress must build without errors
```

---

## Architecture rules — do not break these

### Bridge protocol
- JS batches operations via `queueMicrotask` then calls `__VN_flushOperations(json)`
- Each operation is `{ op: string, args: any[] }`
- Operations are processed on the **main thread** (Swift `@MainActor` / Kotlin `mainHandler.post`)
- Valid ops: `create`, `createText`, `setText`, `setElementText`, `updateProp`, `updateStyle`, `appendChild`, `insertBefore`, `removeChild`, `setRootView`, `addEventListener`, `removeEventListener`, `invokeNativeModule`, `invokeNativeModuleSync`

### Thread model — iOS
- `JSRuntime` runs the JSContext on a dedicated serial `jsQueue` (DispatchQueue)
- **Never pass a `JSValue` across threads** — extract primitives first
- Always use `[weak self]` in closures registered with JSContext
- UI updates must be dispatched to `DispatchQueue.main`

### Thread model — Android
- V8 runs exclusively on `HandlerThread("VueNative-JS")`
- **Never pass a J2V8 `V8Object` or `V8Array` across threads** — release on the JS thread
- All view operations must run on the main thread (`mainHandler.post`)

### Vue renderer (`packages/runtime/src/renderer.ts`)
- **Always call `markRaw(node)`** when creating a `NativeNode` — prevents Vue from tracking node internals as reactive state, which would cause infinite loops
- The scheduler uses only `Promise.resolve().then()` — no DOM APIs needed
- `mountElement` → `bridge.enqueue('create', ...)`, `patchProp` → `bridge.enqueue('updateProp', ...)`, etc.

### Native module callbacks
- Async modules: JS side calls `invokeNativeModule` with a `callbackId`; native calls back via `nodeId=-1, eventName="__callback__"` with `{ callbackId, result, error }`
- `bridge.ts` has a **30-second timeout** on all async module calls — do not remove it
- Sync modules: use `invokeNativeModuleSync` — blocks the JS thread, use sparingly

### Layout
- **iOS:** Yoga via `layoutBox/FlexLayout` SPM. Use `view.flex.xxx` to set Yoga props. Call `view.flex.layout(mode:)` to trigger layout. Percentage widths/heights: use `view.flex.width(50%)` (postfix `%` operator, not `FPercent(value:)`).
- **Android:** `FlexboxLayout` 3.0.0. Use `StyleEngine.kt` to set flex props. Percentage widths/heights use `FlexboxLayout.LayoutParams.widthPercent` / `heightPercent` — **not** `ViewGroup.LayoutParams.WRAP_CONTENT`.

### VList — special child management
Both platforms override `insertChild`/`removeChild` in VListFactory. Item views are stored in a separate array (`itemViews` on iOS, adapter items on Android) — they are **not** regular ViewGroup/subview children. Use targeted row operations (`insertRows`, `deleteRows`) instead of `reloadData`/`notifyDataSetChanged` to avoid layout loops.

---

## Coding conventions

### TypeScript (`packages/`)
- Use `bun` (not npm or pnpm) for all package operations
- All exports go through `packages/runtime/src/index.ts`
- Component files: `packages/runtime/src/components/V<Name>.ts`
- Composables: `packages/runtime/src/composables/use<Name>.ts`
- Tests use Vitest (run via `bun test` or `bunx vitest run`)
- Testing utilities: `import { installMockBridge } from '@thelacanians/vue-native-runtime/testing'`
- Tests in `packages/runtime/src/__tests__/`, `packages/navigation/src/__tests__/`, `packages/cli/src/__tests__/`

### Swift (`native/ios/VueNativeCore/`)
- Swift 5.9+, iOS 16+, UIKit only (no SwiftUI)
- No force-unwraps (`!`) in production paths — use `guard let` or `if let`
- Factories implement `NativeComponentFactory` — always implement `insertChild` and `removeChild` (default impls use `addSubview`/`removeFromSuperview`, but override if needed)
- `StyleEngine.apply(key:value:to:)` is the single entry point for all style props — call it for unknown props from within a factory's `updateProp`
- Tests use XCTest with `@MainActor`, `#if canImport(UIKit)` guard
- Tests in `Tests/VueNativeCoreTests/`

### Kotlin (`native/android/VueNativeCore/`)
- Kotlin 1.9+, API 21+, AppCompat
- Prefer `?.` safe calls over `!!` — treat `!!` as a code smell
- Factories implement `ComponentFactory` interface — same `insertChild`/`removeChild` pattern as Swift
- `StyleEngine.apply(view, key, value)` is the single entry point for style props
- Tests use JUnit4 + Robolectric (`@RunWith(RobolectricTestRunner::class)`, `@Config(sdk = [34])`)
- Tests in `src/test/kotlin/com/vuenative/core/`

---

## How to add a component

1. **TypeScript** — add `packages/runtime/src/components/V<Name>.ts` and export from `index.ts`
2. **iOS** — add `native/ios/VueNativeCore/Sources/VueNativeCore/Components/Factories/V<Name>Factory.swift` and register in `ComponentRegistry.swift`
3. **Android** — add `native/android/VueNativeCore/src/main/kotlin/.../Components/Factories/V<Name>Factory.kt` and register in `ComponentRegistry.kt`
4. **Tests** — add test cases in all three languages (TS component test, Swift factory test, Kotlin factory test)
5. **Docs** — add `docs/src/components/V<Name>.md` with props/events table and examples; add to sidebar in `.vuepress/config.ts`
6. Keep both platforms in parity — if a prop or event exists on one, it must exist on the other

## How to add a native module

1. **TypeScript** — add `packages/runtime/src/composables/use<Name>.ts`, export from `index.ts`
2. **iOS** — add `native/ios/VueNativeCore/Sources/VueNativeCore/Modules/<Name>Module.swift`, register in `NativeModuleRegistry.swift`
3. **Android** — add `.../Modules/<Name>Module.kt`, register in `NativeModuleRegistry.kt`
4. **Tests** — add test cases in all three languages
5. **Docs** — add `docs/src/composables/use<Name>.md` with API reference; add to sidebar
6. Async methods: use `invokeNativeModule` (returns a Promise with 30s timeout)
7. Sync methods: use `invokeNativeModuleSync` only when the result is needed immediately and latency is guaranteed low

## How to add an example app

1. Create `examples/<name>/` with: `package.json`, `vite.config.ts`, `tsconfig.json`, `env.d.ts`, `app/main.ts`, `app/App.vue`, `README.md`
2. Package name: `@thelacanians/vue-native-example-<name>`
3. Match the structure of existing examples (see `examples/counter/` as template)
4. Vite config: use `vue()` + `vueNative()` plugins, `build.rollupOptions.output.format: 'iife'`
5. Add a `README.md` listing what components/composables the example demonstrates

---

## Build & dev commands

```bash
# ── TypeScript ──────────────────────────────────────────────
bun install                  # Install all workspace dependencies
bun run build                # Build all packages (turbo)
bun run lint                 # ESLint across all packages
bun run typecheck            # TypeScript type-check (turbo)
bun test                     # Run TS tests (Bun runner, all packages)
bun run test                 # Run TS tests (turbo → vitest in each package)

# ── iOS (Swift) ─────────────────────────────────────────────
swift build --package-path native/ios/VueNativeCore    # Build Swift package
swift test --package-path native/ios/VueNativeCore     # Run XCTest suite
bun run test:ios                                       # Shortcut from root

# ── Android (Kotlin) ────────────────────────────────────────
cd native/android && ./gradlew :VueNativeCore:compileDebugKotlin       # Build
cd native/android && ./gradlew :VueNativeCore:testDebugUnitTest        # Test
bun run test:android                                                   # Shortcut from root

# ── All platforms ───────────────────────────────────────────
bun run test:native          # iOS + Android native tests
bun run test:all             # TS + iOS + Android — run before pushing

# ── CLI ─────────────────────────────────────────────────────
vue-native create <name>     # Scaffold a new project
vue-native dev               # Vite watch + hot reload WebSocket server
vue-native run ios|android   # Build and run on simulator/device
vue-native build ios|android # Production build (--mode, --output, --scheme, --aab)

# ── Docs ────────────────────────────────────────────────────
cd docs && bun install && bun run dev    # Dev server
cd docs && bun run build                 # Production build

# ── Example app dev ─────────────────────────────────────────
cd examples/counter && bun run dev       # Vite watch + hot reload
# Then open the native project in Xcode / Android Studio and run
```

---

## Common pitfalls

| Mistake | Why it breaks | Fix |
|---------|---------------|-----|
| Forgetting `markRaw(node)` on NativeNode | Vue tracks node internals as reactive, causes infinite re-renders | Always call `markRaw` in `createNode` |
| Passing `JSValue` across threads (iOS) | JSContext is not thread-safe, crashes | Extract primitives before crossing thread boundary |
| Passing J2V8 objects across threads (Android) | V8 objects are thread-local, crashes | Serialize to primitives on the JS thread before posting to main |
| Using `reloadData()` on VList | Causes re-entrant layout loops | Use `insertRows`/`deleteRows`/`reloadRows` at specific index paths |
| Using `WRAP_CONTENT` for percentage dims (Android) | Percentage sizing silently broken | Use `LayoutParams.widthPercent` / `heightPercent` |
| Duplicate Vue instances | Two copies of Vue produce two reactivity systems | Ensure `@thelacanians/vue-native-runtime` re-exports from one `@vue/runtime-core` |
| `FPercent(value:)` in FlexLayout (iOS) | Internal type, not public API | Use the postfix `%` operator: `50%` |
| Removing `invokeNativeModule` timeout | Promise hangs forever if native never replies | The 30s timeout in `bridge.ts` is intentional |
| Pushing without running tests | CI breaks, blocks other contributors | Run `bun run test:all` before pushing |
| Adding a component without tests/docs | Feature is undiscoverable and untested | Always add tests (all 3 languages) + doc page + sidebar entry |
| Committing `.env` or credentials | Leaks secrets to the repository | Never commit secrets; use `.gitignore` and env vars |

---

## Key file locations

| What | Path |
|------|------|
| Vue custom renderer | `packages/runtime/src/renderer.ts` |
| JS bridge (TS) | `packages/runtime/src/bridge.ts` |
| NativeNode definition | `packages/runtime/src/node.ts` |
| StyleSheet helper | `packages/runtime/src/stylesheet.ts` |
| Theme system | `packages/runtime/src/theme.ts` |
| All component exports | `packages/runtime/src/components/` |
| All composable exports | `packages/runtime/src/composables/` |
| Testing utilities | `packages/runtime/src/testing.ts` (subpath: `/testing`) |
| Navigation (router, tabs, drawer) | `packages/navigation/src/index.ts` |
| Vite plugin | `packages/vite-plugin/src/index.ts` |
| CLI commands | `packages/cli/src/commands/` |
| iOS Swift bridge | `native/ios/VueNativeCore/Sources/VueNativeCore/Bridge/NativeBridge.swift` |
| iOS JS runtime | `native/ios/VueNativeCore/Sources/VueNativeCore/Bridge/JSRuntime.swift` |
| iOS style engine | `native/ios/VueNativeCore/Sources/VueNativeCore/Styling/StyleEngine.swift` |
| iOS component registry | `native/ios/VueNativeCore/Sources/VueNativeCore/Components/ComponentRegistry.swift` |
| iOS base VC | `native/ios/VueNativeCore/Sources/VueNativeCore/Bridge/VueNativeViewController.swift` |
| iOS tests | `native/ios/VueNativeCore/Tests/VueNativeCoreTests/` |
| Android bridge | `native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Bridge/NativeBridge.kt` |
| Android JS runtime | `native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Bridge/JSRuntime.kt` |
| Android style engine | `native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Styling/StyleEngine.kt` |
| Android component registry | `native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Components/ComponentRegistry.kt` |
| Android base Activity | `native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/VueNativeActivity.kt` |
| Android tests | `native/android/VueNativeCore/src/test/kotlin/com/vuenative/core/` |
| Docs sidebar config | `docs/src/.vuepress/config.ts` |
| Lefthook pre-commit | `lefthook.yml` |
