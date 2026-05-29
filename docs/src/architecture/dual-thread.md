# Threading Architecture

Vue Native uses a split runtime model: Vue and JavaScript execute on a dedicated JS queue or thread, while native view creation, mutation, and layout run on the platform UI thread.

This page describes the current architecture. It is not a proposal for WebView-style workers, and it is not the older single-threaded model where JavaScript ran directly on the main thread.

## Current Model

```text
Vue components
  |
  | queueMicrotask()
  v
NativeBridge operation batch
  |
  | JSON: [{ op, args }]
  v
Platform bridge
  |
  | dispatch to UI thread
  v
UIKit / Android Views / AppKit
  |
  v
Yoga / FlexboxLayout / LayoutNode
```

Native events move in the opposite direction:

```text
Native event on UI thread
  |
  | serialize primitives only
  v
JS queue / JS thread
  |
  v
Vue event handler or global event listener
```

## Platform Threads

| Platform | JavaScript runtime | JS execution owner | Native UI owner |
| --- | --- | --- | --- |
| iOS | JavaScriptCore `JSContext` | Serial `DispatchQueue(label: "com.vuenative.js")` | Main thread / UIKit |
| Android | J2V8 `V8` | `HandlerThread("VueNative-JS")` | Main looper / Android Views |
| macOS | JavaScriptCore `JSContext` from `VueNativeShared` | Serial `DispatchQueue(label: "com.vuenative.js")` | Main thread / AppKit |

The JS owner is exclusive. All `JSContext` or V8 access must stay on that owner, and UI work must stay on the native UI thread.

## Bridge Boundary

The TypeScript renderer batches native operations in `packages/runtime/src/bridge.ts`.

```ts
bridge.enqueue('create', [nodeId, type, props])
bridge.enqueue('appendChild', [parentId, childId])
bridge.enqueue('updateProp', [nodeId, key, value])
```

The batch is flushed through:

```ts
globalThis.__VN_flushOperations(json)
```

Native code then decodes the JSON and applies the operation on the UI thread. The bridge boundary is intentionally JSON-shaped because it prevents platform runtime objects from crossing thread boundaries.

Valid operation payloads must be serializable primitives, arrays, and plain objects. Do not pass `JSValue`, `V8Object`, `V8Array`, closures, native view instances, or platform handles through the batch.

## Event Delivery

Component events use `__VN_handleEvent(nodeId, eventName, payload)`.

Global events use `__VN_handleGlobalEvent(eventName, payloadJSON)`.

Both paths serialize native payloads before dispatching to JavaScript. Android also uses the global-event return value for hardware-back handling: if JavaScript has no listener for `hardware:backPress`, `VueNativeActivity` performs the default Activity finish action.

## Native Modules

Async native modules use callback IDs:

```text
JS invokeNativeModule(module, method, args)
  -> native invoke(...)
  -> native emits __callback__
  -> JS resolves or rejects the Promise
```

The TypeScript bridge keeps a 30 second timeout for async module calls. That timeout is part of the reliability contract and should not be removed.

Sync native modules use `invokeNativeModuleSync`. They block the JS owner and should only be used for small, predictable reads.

## Thread Safety Rules

Follow these rules when touching bridge, runtime, or module code:

1. Never pass `JSValue` across Swift queues. Extract strings, numbers, booleans, arrays, or dictionaries on the JS queue first.
2. Never pass J2V8 `V8Object` or `V8Array` across Android threads. Convert them to Kotlin primitives or JSON on the JS thread, then release them on that same thread.
3. Always apply UIKit, Android View, and AppKit mutations on the main UI thread.
4. Keep JSContext closure captures weak in Swift.
5. Keep bridge operation args JSON-safe.
6. Use the platform style engine as the single entry point for unknown style props.

## What This Does And Does Not Solve

The current architecture keeps JavaScript execution off the UI thread, which protects scroll, gestures, and native drawing from direct JS runtime work.

It does not make every app update free. A large Vue render can still enqueue a large native batch, and applying that batch can still consume main-thread time during view creation, layout, or style updates.

The practical performance work is therefore:

- Keep operation batches compact.
- Avoid redundant prop and style writes.
- Prefer targeted list updates over full reloads.
- Keep expensive native module work off the UI thread.
- Move animation timing and per-frame interpolation to native code when possible.

## Future Work

The useful next steps are incremental, not a rewrite of the current thread model:

1. Add bridge priority lanes for input-critical events versus low-priority style or data updates.
2. Deduplicate repeated prop and style writes inside a single flush.
3. Expand native-driven animation support so animations do not depend on JS frame callbacks.
4. Add direct native tests for thread handoff paths, including Android hardware back, native module callbacks, and global event dispatch.
5. Tighten Swift concurrency warnings before enabling stricter Swift language modes.

Any future architecture change should preserve the core invariant: JavaScript runtime objects stay on the JS owner, and native views stay on the UI thread.
