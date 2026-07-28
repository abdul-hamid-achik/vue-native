# Architecture Overview

Vue Native renders **real native views** — not a WebView. Vue 3's custom
renderer API (`createRenderer`) drives `UIKit` views on iOS, `AppKit` views on
macOS, and Android `View`s on Android through a thin, JSON-shaped bridge.

```text
Vue SFC
  ↓  Vue custom renderer (createRenderer)
NativeBridge (TypeScript)
  ↓  JSON batch: [{ op, args }, ...]
Platform bridge (Swift / Kotlin)
  ↓  dispatch to UI thread
iOS: UIKit + Yoga
macOS: AppKit + LayoutNode
Android: Views + FlexboxLayout
```

## The custom renderer

The renderer lives in
[`packages/runtime/src/renderer.ts`](https://github.com/abdul-hamid-achik/vue-native/blob/main/packages/runtime/src/renderer.ts)
and is built with `createRenderer<NativeNode, NativeNode>(nodeOps)` from
`@vue/runtime-core`. The `nodeOps` object maps Vue's virtual-DOM operations onto
lightweight `NativeNode` objects that record a node id, type, props, and tree
relationships.

Two invariants matter:

- **Every `NativeNode` is wrapped in `markRaw`.** This stops Vue from tracking
  node internals as reactive state, which would otherwise cause infinite
  re-render loops.
- **The scheduler uses only `Promise.resolve().then()`.** No DOM APIs are
  required, so the same renderer runs inside JavaScriptCore (iOS/macOS) and V8
  (Android).

## The bridge

Vue's render pass does not touch native code directly. Instead, each renderer
operation is translated into a bridge operation and enqueued:

```ts
bridge.enqueue('create', [nodeId, type, props])
bridge.enqueue('appendChild', [parentId, childId])
bridge.enqueue('updateProp', [nodeId, key, value])
```

The bridge (in
[`packages/runtime/src/bridge.ts`](https://github.com/abdul-hamid-achik/vue-native/blob/main/packages/runtime/src/bridge.ts))
batches operations and flushes them on a microtask. When the microtask fires,
the whole batch is serialized to JSON and handed to the native side through a
single global function:

```ts
globalThis.__VN_flushOperations(json)
```

Batching via `queueMicrotask` means many synchronous Vue updates collapse into
one native round-trip per tick, rather than one call per operation.

### Valid operations

The bridge speaks a fixed vocabulary of operations:

| Op | Purpose |
|----|---------|
| `create` | Create a view node. |
| `createText` | Create a text node. |
| `setText` / `setElementText` | Update text content. |
| `updateProp` | Set a component prop. |
| `updateStyle` | Set a style property. |
| `appendChild` / `insertBefore` / `removeChild` | Mutate the view tree. |
| `setRootView` | Designate the root view. |
| `addEventListener` / `removeEventListener` | Manage component events. |
| `invokeNativeModule` / `invokeNativeModuleSync` | Call a native module. |

Operation arguments must be JSON-serializable primitives, arrays, and plain
objects. Platform runtime objects (`JSValue`, V8 objects, native view handles)
never cross the bridge — this is what makes the thread split safe. See
[Threading Architecture](/architecture/dual-thread.md).

## Events flow back the other way

Native events are serialized to primitives on the UI thread, then dispatched to
JavaScript:

- Component events: `__VN_handleEvent(nodeId, eventName, payload)`
- Global events: `__VN_handleGlobalEvent(eventName, payloadJSON)`

JavaScript subscribes to global events via `NativeBridge.onGlobalEvent(name,
handler)`. The bridge also emits its own `bridge:error` global event when the
native runtime is not connected (see
[Debugging](/guide/debugging.md#bridge-error-events)).

## Native modules

Capabilities like haptics, storage, and OTA updates are native modules. The JS
side calls `invokeNativeModule(module, method, args)` with a callback id; native
runs the work and replies through a `__callback__` event carrying the result or
error. Async module calls have a 30-second timeout that is part of the
reliability contract.

## Layout

Each platform applies Flexbox with its own engine: Yoga on iOS, FlexboxLayout on
Android, and a custom pure-Swift `LayoutNode` on macOS. See
[Layout Engines](/architecture/layout-engines.md).

## Where to read next

- [Threading Architecture](/architecture/dual-thread.md) — the JS/UI thread split and its safety rules.
- [Layout Engines](/architecture/layout-engines.md) — per-platform Flexbox implementations.
- [Styling](/guide/styling.md) — the style property reference.
