# AGENTS.md — Vue Native

Guidelines for AI agents (Claude, Codex, Gemini, etc.) working on this codebase.

---

## Project Context

Vue Native is a framework that renders Vue.js 3 SFCs to native iOS UIKit views using JavaScriptCore and a custom Vue renderer. It is **not** a WebView wrapper.

Before making changes, read:
- `SPEC.md` — Full technical specification (3000+ lines, authoritative)
- `PLAN.md` — Implementation plan with phase breakdown and file-by-file order
- This file — Conventions and pitfalls specific to this codebase

---

## Architecture in 30 Seconds

```
Vue SFC → Vite IIFE bundle → JavaScriptCore → Vue custom renderer
       → NativeBridge (JSON/JSContext) → Swift → UIKit + Yoga layout
```

**Three worlds that must stay separated:**

| World | Language | Entry point |
|-------|----------|-------------|
| JS runtime | TypeScript | `packages/runtime/src/` |
| Build tooling | TypeScript | `packages/vite-plugin/src/` |
| Native | Swift | `native/Sources/` |

---

## Critical Rules (Do Not Violate)

### JavaScript / TypeScript

1. **`markRaw()` on every NativeNode.** Vue's reactivity will try to track node internals without this, causing massive performance regressions. See `PLAN.md §1` and Vue's own `@vue/runtime-test` for the pattern.

2. **Never import from `@vue/runtime-dom`.** Use `@vue/runtime-core` only. `runtime-dom` is DOM-specific and will not work in JSC.

3. **No ESM dynamic imports in JSC bundles.** JSC has no ESM loader. The Vite build must produce an IIFE with `inlineDynamicImports: true`. Any `import()` calls will silently fail at runtime.

4. **Externalize `@vue/runtime-core` in library builds.** If two copies end up in the bundle, `currentRenderingInstance` becomes null and `resolveComponent()` breaks everywhere.

5. **All bridge calls must be batched.** Never call into Swift per-property. Accumulate a batch of UI operations and flush once per frame. See `BridgeProtocol` in SPEC.md.

### Swift

6. **JSContext is NOT thread-safe.** All JS evaluation and all `JSValue` access must happen on the dedicated `jsQueue` (serial DispatchQueue). Never capture a `JSValue` and use it on another thread. Extract primitives (String, Int, Dictionary) before dispatching.

7. **Use `[weak self]` in every closure registered with JSContext.** Failing to do so creates retain cycles that prevent the bridge and JSContext from being deallocated.

8. **Never store `JSValue` long-term.** Extract the value you need immediately. Stored `JSValue` references keep the entire JSContext alive and can dangle after context teardown.

9. **Do not mix Auto Layout with Yoga in the same view hierarchy.** They fight each other. All views managed by Vue Native must use Yoga exclusively for layout. Host app views outside the Vue root can use Auto Layout.

10. **Text nodes require a Yoga measure function.** Without `YGMeasureFunc` set on text node's flex item, `UILabel` dimensions are zero and layout collapses. This is non-optional.

---

## Monorepo Layout

```
packages/runtime/          @vue-native/runtime
  src/
    renderer.ts            Vue createRenderer() implementation
    bridge.ts              JS-side bridge client
    nodes.ts               NativeNode types + markRaw factory
    components/            VView, VText, VButton, VInput
    composables/           useNativeModule, etc.
    index.ts               Public API

packages/vite-plugin/      @vue-native/vite-plugin
  src/
    index.ts               Vite plugin entry
    transform.ts           SFC → native render fn transform
    iife-bundle.ts         IIFE build config helper

native/Sources/
  VueNativeCore/
    Bridge/
      JSBridge.swift       JSContext setup + function registration
      BridgeProtocol.swift JSON command types
    Components/
      ComponentRegistry.swift  Tag → UIView factory
      VView.swift, VText.swift, etc.
    Layout/
      LayoutEngine.swift   Yoga/FlexLayout wrapper
      StyleParser.swift    JS style object → Yoga props
    Runtime/
      JSRuntime.swift      JSContext lifecycle + polyfills
      Polyfills.swift      setTimeout, console, requestAnimationFrame

examples/counter/          Phase 1 demo
  App.vue                  Counter SFC
  main.ts                  App entry point
  ios/                     Xcode project
```

---

## Key Interfaces

### NativeNode (JS side)

```typescript
interface NativeNode {
  id: number           // Unique, assigned by renderer
  type: string         // 'VView' | 'VText' | 'VButton' | 'VInput' | '__TEXT__'
  props: Record<string, unknown>
  children: NativeNode[]
  parentId: number | null
}
// MUST be wrapped with markRaw() at creation time
```

### Bridge Command (JS → Swift)

```typescript
type BridgeCommand =
  | { op: 'create';  id: number; type: string; props: Record<string, unknown> }
  | { op: 'update';  id: number; props: Record<string, unknown> }
  | { op: 'insert';  id: number; parentId: number; beforeId: number | null }
  | { op: 'remove';  id: number }
  | { op: 'setText'; id: number; text: string }
```

Commands are batched in an array and flushed in a single `__vue_native_flush__(commands)` call.

### Style Object

```typescript
// Subset supported in Phase 1
interface StyleObject {
  flex?: number
  flexDirection?: 'row' | 'column' | 'row-reverse' | 'column-reverse'
  alignItems?: 'flex-start' | 'flex-end' | 'center' | 'stretch'
  justifyContent?: 'flex-start' | 'flex-end' | 'center' | 'space-between' | 'space-around'
  padding?: number; paddingTop?: number; paddingBottom?: number
  paddingLeft?: number; paddingRight?: number
  paddingHorizontal?: number; paddingVertical?: number
  margin?: number; marginTop?: number; marginBottom?: number
  marginLeft?: number; marginRight?: number
  width?: number | string; height?: number | string
  backgroundColor?: string   // '#rrggbb' or 'rgba(r,g,b,a)'
  color?: string
  fontSize?: number; fontWeight?: string
  borderRadius?: number
  opacity?: number
}
```

---

## Coding Conventions

### TypeScript

- Use `interface` for public-facing types, `type` for unions and aliases
- No `any` — use `unknown` and narrow explicitly
- Export types separately from values (`export type { Foo }`)
- Module path aliases: `@runtime/*` → `packages/runtime/src/*`

### Swift

- Follow Swift API design guidelines (no Hungarian notation, clear argument labels)
- All public Swift types exposed to JSC are prefixed `VN` (e.g., `VNBridge`, `VNComponent`)
- Error handling: use `Result<T, Error>` for bridge operations; never silently swallow errors
- Log prefix: `[VueNative]` for all os_log calls

### File naming

- TypeScript: `camelCase.ts` for modules, `PascalCase.ts` for class/interface files
- Swift: `PascalCase.swift`, matching the primary type defined within
- Tests: `*.test.ts` (Bun test runner), `*Tests.swift` (XCTest)

---

## What Is Deferred to Phase 2

Do not implement these in Phase 1 — scope them out if they come up:

- Navigation (vue-router-style stack/tab navigation)
- VList / virtualized lists
- VImage
- Native modules (camera, geolocation, haptics, AsyncStorage)
- Hot module replacement (Phase 1 uses full reload)
- Animations (VAnimated, Transition, TransitionGroup)
- Shadow tree layout (Phase 1 uses direct UIView Yoga)
- MessagePack binary bridge
- CLI tool (`vue-native create`)
- Android/Kotlin

---

## Running the Project

```bash
# Install all JS dependencies
bun install

# Build all JS packages (watch mode for development)
bun run dev

# Type check
bun run typecheck

# Run JS tests
bun run test

# Build production bundles
bun run build
```

For Swift/Xcode:
- Open `examples/counter/ios/VueNativeCounter.xcodeproj` in Xcode 15+
- The native package resolves `VueNativeCore` from `../../native/`
- Build and run on iOS 16+ simulator

---

## Common Pitfalls

| Symptom | Likely cause |
|---------|-------------|
| `resolveComponent` returns null at runtime | Duplicate Vue instances in bundle. Externalize `@vue/runtime-core`. |
| Vue reactivity becomes extremely slow | Missing `markRaw()` on NativeNode. Add it to `createNativeNode()`. |
| Text nodes have zero height | Yoga measure function not set for text nodes. |
| JSC crashes with `EXC_BAD_ACCESS` | `JSValue` accessed off the JS queue. All JS access must be on `jsQueue`. |
| Layout doesn't match CSS expectations | Yoga web defaults not enabled. Set `useWebDefaults: true`. |
| Dynamic imports fail silently in JSC | ESM not supported. Ensure `inlineDynamicImports: true` in Vite IIFE config. |
| Bridge calls cause UI jank | Not batching bridge commands. Accumulate per frame, flush once. |
| Memory leak after JSContext teardown | Retain cycle from missing `[weak self]` in JSContext closures. |

---

## References

- `SPEC.md` — Authoritative technical specification
- `PLAN.md` — Phase 1 implementation plan with file-by-file order
- [Vue `@vue/runtime-test`](https://github.com/vuejs/core/tree/main/packages/runtime-test) — Gold standard reference for custom renderers
- [FlexLayout (Yoga Swift wrapper)](https://github.com/layoutBox/FlexLayout) — Layout engine used
- [JavaScriptCore docs](https://developer.apple.com/documentation/javascriptcore) — Apple's JSC Swift API
