# AGENTS.md — Vue Native

Guidelines for AI agents (Claude, Codex, etc.) working on this codebase. Read this before making any changes.

---

## What this project is

Vue Native is a framework for building **real native iOS, Android, and macOS apps with Vue 3**. It is NOT a WebView wrapper. Vue components drive `UIKit` views on iOS, `Android Views` on Android, and `AppKit` views on macOS via a custom `createRenderer()` bridge.

```
Vue SFC  →  Vue custom renderer  →  NativeBridge (TS)
                                          ↓  JSON batch
                                  iOS: Swift → UIKit + Yoga
                                  Android: Kotlin → Views + FlexboxLayout
                                  macOS: Swift → AppKit + LayoutNode
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
  shared/VueNativeShared/    Cross-platform Swift (iOS 16+, macOS 13+)
    Sources/VueNativeShared/
      JSRuntime, EventThrottle, HotReloadManager, CertificatePinning,
      SharedJSPolyfills, NativeModule protocol, NativeModuleRegistry,
      NativeEventDispatcher, Modules/ (9 shared modules)
    Tests/VueNativeSharedTests/
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
  macos/VueNativeMacOS/      Swift Package (macOS 15+, AppKit, JavaScriptCore, LayoutNode)
    Package.swift             (depends on VueNativeShared)
    Sources/VueNativeMacOS/
      Bridge/                NativeBridge, JSPolyfills, VueNativeWindowController,
                             ErrorOverlayView, HotReloadManager, EventThrottle
      Components/Factories/  28 component factories (AppKit equivalents)
      Modules/               16 modules (12 cross-platform + 4 macOS-only)
      Styling/               StyleEngine.swift — CSS props → LayoutNode + NSView.layer
      Layout/                LayoutNode (custom flexbox), FlippedView (isFlipped=true)
      Helpers/               ClickableView, GestureWrapper, NSColor+Hex, Extensions
    Tests/VueNativeMacOSTests/
docs/
  src/               VuePress 2.x documentation site (bun run dev in docs/)
examples/
  counter/  calculator/  settings/  social/  tasks/  todo/
  auth-flow/  chat/  camera-app/  forms/  lists/
  navigation-demo/  media-player/  theming/  macos-showcase/
tools/
  vscode-extension/  VS Code snippets + diagnostics
  nvim-plugin/       Neovim snippets + completion + diagnostics
```

---

## Progress, changelog, and backlog notes

Deep reviews and long-running uncommitted work need a local handoff trail. Keep that trail outside the repository so it can guide future work without becoming a release artifact:

```bash
~/notes/projects/vue-native/
```

This is the canonical handoff location. `~/notes/vue-native-backlog/` is a
legacy compatibility mirror only; new notes should be organized under the
project-specific directory above.

These notes are for agents and maintainers continuing the same branch. They should answer four questions quickly:

- What changed in the current uncommitted tree?
- What was reviewed and what validation passed?
- What is still risky, blocked, or unverified?
- What should the next agent do first?

### Current local notes

- `~/notes/projects/vue-native/progress-2026-07-10.md`
- `~/notes/projects/vue-native/handoff-2026-07-10.md`
- `~/notes/projects/vue-native/CHANGELOG-draft-2026-07-10.md`
- Historical notes: `~/notes/projects/vue-native/archive/2026-05-26/` and `~/notes/projects/vue-native/archive/2026-07-09/`

### When to create or update notes

Update the notes whenever you do any of the following:

- Perform a broad codebase review or audit.
- Touch more than one platform or package in one task.
- Leave work uncommitted with known follow-ups.
- Run only a subset of the required quality gates.
- Discover a blocker that future agents need to know about.

Prefer updating the latest progress file in `~/notes/projects/vue-native/` over creating a duplicate. Create a new dated file only when starting a distinct review, release draft, or investigation.

### Required note types

Use these names by default:

```bash
~/notes/projects/vue-native/CHANGELOG-draft-YYYY-MM-DD.md
~/notes/projects/vue-native/progress-YYYY-MM-DD.md
```

`CHANGELOG-draft-*` should be release-note shaped:

- Added
- Changed
- Fixed
- Tests and validation
- Known risks before commit

`progress-*` should be handoff shaped:

- Review scope
- Current uncommitted work summary
- Feature map
- Findings with priority (`P1`, `P2`, `P3`)
- Validation results
- Blocked or not-run checks
- Suggested next work

### Workflow for future agents

Before changing code:

1. Run `git status --short` to understand the current working tree.
2. Read the latest `~/notes/projects/vue-native/progress-*.md`.
3. Confirm whether any listed blocker affects the requested task.
4. Avoid reverting existing uncommitted work unless the user explicitly asks.

After changing code:

1. Update the latest progress file with what changed.
2. Move resolved findings out of the active backlog or mark them resolved with the validation that proved it.
3. Add new validation results, including exact commands and whether they passed, failed, or were blocked.
4. Keep `CHANGELOG-draft-*` aligned with user-facing changes.

Do not commit files from `~/notes`; they are local working notes, not repository artifacts.

### Current review objectives and open risks

The active review tracks broad uncommitted cross-platform hardening: runtime
lifecycle and event behavior, native bridge cleanup, Android layout and module
ownership, Apple certificate pinning, macOS exports, generated native-module
registration, release automation, documentation, and examples.

Primary objectives:

- Preserve cross-platform parity for runtime APIs, native modules, and generated module registration.
- Keep every TypeScript and native platform gate green after the final integrated diff.
- Record device-only or external-service verification that cannot be proven in unit tests.
- Keep a clear handoff before any commit or push.

Current release risks from the notes:

- Physical-device app-shell smoke tests have not been run for iOS, Android, or macOS.
- Certificate pinning has deterministic key-vector coverage but still needs a live TLS fixture smoke test.
- Android camera capture and biometric authentication require documented Activity-level integrations in an app host.
- Multi-registry publication is not atomic; a failure after one registry publishes requires deliberate manual recovery.

---

## Pre-commit and pre-push checklist

**IMPORTANT:** Before committing or pushing ANY changes, you MUST verify the affected code passes all quality gates. Failing to do so will break CI and block other contributors.

### TypeScript / JavaScript / Vue changes (`packages/`, `examples/`, `docs/`)

```bash
# All three must pass before committing:
bun run lint              # ESLint — fix errors, don't ignore warnings
bun run typecheck         # tsc --noEmit via turbo — zero errors required
bun run test              # Turbo orchestrated tests via Vitest across packages — 0 failures required
                          # NOTE: Do NOT use `bun test` directly — it uses Bun's built-in runner
                          # which behaves differently (e.g., `node:fs` module resolution).
```

The Lefthook pre-commit hook runs lint + typecheck. The pre-push hook runs the
complete `bun run check:ts` gate (lint, typecheck, native-module contract
check, build, integrated packed-scaffold smoke, TypeScript tests, Knip, and
hook validation). Native gates remain explicit and must be run for
every affected platform before pushing.

### Swift changes (`native/ios/` or `native/shared/`)

```bash
# Both must pass before committing:
cd native/ios/VueNativeCore && xcodebuild build -scheme VueNativeCore -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
cd native/ios/VueNativeCore && xcodebuild test -scheme VueNativeCore -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Do not use plain `swift build` / `swift test` for the iOS package on macOS. They target the host platform by default and fail to resolve `UIKit`. Run `xcodebuild` from inside `native/ios/VueNativeCore/`.

### Swift changes (`native/macos/` or `native/shared/`)

```bash
# Both must pass before committing:
cd native/shared/VueNativeShared && swift build && swift test
cd native/macos/VueNativeMacOS && swift build && swift test
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
bun run test              # Runs TS tests + iOS tests + Android tests
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

### Thread model — macOS
- Same as iOS: JSContext on dedicated serial `jsQueue` (via VueNativeShared's JSRuntime)
- Same rules: never pass JSValue across threads, always `[weak self]` in JSContext closures
- UI updates on `DispatchQueue.main`

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
- **macOS:** Custom `LayoutNode` (pure-Swift flexbox engine, no Yoga dependency). Properties use `LayoutValue` enum: `.points(CGFloat)`, `.percent(CGFloat)`, `.auto`, `.undefined` — NOT raw Int/CGFloat. All views use `FlippedView` base class (`isFlipped=true`) for CSS-compatible top-left origin coordinates.

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
- Factories that own tasks, observers, controllers, overlays, or other resources outside the normal view hierarchy must implement `destroyView(view:)`; it runs for permanent removal/reset, never for reparenting moves
- `StyleEngine.apply(key:value:to:)` is the single entry point for all style props — call it for unknown props from within a factory's `updateProp`
- Tests use XCTest with `@MainActor`, `#if canImport(UIKit)` guard
- Tests in `Tests/VueNativeCoreTests/`

### Swift — macOS (`native/macos/VueNativeMacOS/`)
- Swift 5.9+ (swiftLanguageMode .v5), macOS 15+, AppKit only (no SwiftUI)
- Depends on `VueNativeShared` — use `import VueNativeShared` for NativeModule, EventThrottle, etc.
- Factories implement `NativeComponentFactory` — same protocol as iOS but returns `NSView`
- Factories that attach windows, toolbars, tasks, observers, or other external resources must implement `destroyView(view:)`; cleanup must be idempotent and must not fire user events during unmount
- `StyleEngine.apply(key:value:to:)` routes layout props to LayoutNode and visual props to NSView.layer
- Associated object keys accessed from `@objc` proxy classes must use `nonisolated(unsafe) static var`
- Use `NSColor.fromHex()` (not UIColor) for hex color parsing
- Tests use XCTest with `@MainActor`, `#if canImport(AppKit)` guard

### Kotlin (`native/android/VueNativeCore/`)
- Kotlin 1.9+, API 21+, AppCompat
- Prefer `?.` safe calls over `!!` — treat `!!` as a code smell
- Factories implement `ComponentFactory` interface — same `insertChild`/`removeChild` pattern as Swift
- Factories that own players, WebViews, handlers, dialogs, or other external resources must implement idempotent `destroyView`; permanent removal/reset invokes it, while reparenting moves do not
- `StyleEngine.apply(view, key, value)` is the single entry point for style props
- Tests use JUnit4 + Robolectric (`@RunWith(RobolectricTestRunner::class)`, `@Config(sdk = [34])`)
- Tests in `src/test/kotlin/com/vuenative/core/`

---

## How to add a component

1. **TypeScript** — add `packages/runtime/src/components/V<Name>.ts` and export from `index.ts`
2. **iOS** — add `native/ios/VueNativeCore/Sources/VueNativeCore/Components/Factories/V<Name>Factory.swift` and register in `ComponentRegistry.swift`
3. **Android** — add `native/android/VueNativeCore/src/main/kotlin/.../Components/Factories/V<Name>Factory.kt` and register in `ComponentRegistry.kt`
4. **macOS** — add `native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Components/Factories/V<Name>Factory.swift` and register in `ComponentRegistry.swift`
5. **Tests** — add test cases in all languages (TS component test, Swift factory test, Kotlin factory test)
6. **Docs** — add `docs/src/components/V<Name>.md` with props/events table and examples; add to sidebar in `.vuepress/config.ts`
7. Keep all platforms in parity — if a prop or event exists on one, it must exist on the others (except platform-specific no-ops)

## How to add a native module

1. **TypeScript** — add `packages/runtime/src/composables/use<Name>.ts`, export from `index.ts`
2. **iOS** — add `native/ios/VueNativeCore/Sources/VueNativeCore/Modules/<Name>Module.swift`, register in `NativeModuleRegistry.swift`
3. **Android** — add `.../Modules/<Name>Module.kt`, register in `NativeModuleRegistry.kt`
4. **macOS** — add `native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Modules/<Name>Module.swift`, register in `NativeModuleRegistry.swift`
5. **Tests** — add test cases in all languages
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
bun run test                 # Run ALL tests (TS + iOS + Android)
bun run test:ts              # Run TS tests only (turbo → vitest in each package)

# ── Shared (Swift) ──────────────────────────────────────────
swift build --package-path native/shared/VueNativeShared  # Build shared package
swift test --package-path native/shared/VueNativeShared   # Run shared tests
bun run test:shared                                       # Shortcut from root

# ── iOS (Swift) ─────────────────────────────────────────────
cd native/ios/VueNativeCore && xcodebuild build -scheme VueNativeCore -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
cd native/ios/VueNativeCore && xcodebuild test -scheme VueNativeCore -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
bun run build:ios                                      # Shortcut from root
bun run test:ios                                       # Shortcut from root

# ── Android (Kotlin) ────────────────────────────────────────
cd native/android && ./gradlew :VueNativeCore:compileDebugKotlin       # Build
cd native/android && ./gradlew :VueNativeCore:testDebugUnitTest        # Test
bun run test:android                                                   # Shortcut from root

# ── macOS (Swift) ───────────────────────────────────────────
swift build --package-path native/macos/VueNativeMacOS # Build macOS package
swift test --package-path native/macos/VueNativeMacOS  # Run macOS tests
bun run test:macos                                     # Shortcut from root

# ── All platforms ───────────────────────────────────────────

# ── CLI ─────────────────────────────────────────────────────
vue-native create <name>           # Scaffold a new project
vue-native dev                     # Vite watch + hot reload WebSocket server
vue-native run ios|android|macos   # Build and run on simulator/device
vue-native build ios|android|macos # Production build (--mode, --output, --scheme, --aab)

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
| `node.width = 0` on macOS LayoutNode | LayoutNode props are `LayoutValue` enum, not raw Int | Use `node.width = .points(0)` |
| `private static var` for ObjC keys (macOS) | Proxy classes can't access `private` members | Use `nonisolated(unsafe) static var` |
| Defining `NativeModule` in macOS | Duplicates the shared protocol from VueNativeShared | Import VueNativeShared; don't redefine |
| Missing `isFlipped=true` (macOS) | NSView origin is bottom-left; layout breaks | Use FlippedView base class |
| NSScrollView child management | Children go to documentView, not the scroll view | Override insertChild/removeChild |
| Pushing without running tests | CI breaks, blocks other contributors | Run `bun run test` before pushing |
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
| Shared package | `native/shared/VueNativeShared/Sources/VueNativeShared/` |
| Shared NativeModule protocol | `native/shared/VueNativeShared/Sources/VueNativeShared/NativeModule.swift` |
| Shared tests | `native/shared/VueNativeShared/Tests/VueNativeSharedTests/` |
| macOS Swift bridge | `native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Bridge/NativeBridge.swift` |
| macOS style engine | `native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Styling/StyleEngine.swift` |
| macOS component registry | `native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Components/ComponentRegistry.swift` |
| macOS layout engine | `native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Layout/LayoutNode.swift` |
| macOS base WC | `native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Bridge/VueNativeWindowController.swift` |
| macOS tests | `native/macos/VueNativeMacOS/Tests/VueNativeMacOSTests/` |
| Docs sidebar config | `docs/src/.vuepress/config.ts` |
| Lefthook pre-commit | `lefthook.yml` |
