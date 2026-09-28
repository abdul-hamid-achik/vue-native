---
'@thelacanians/vue-native-runtime': patch
---

Make `useGesture` / `useComposedGestures` attach through the documented template-ref pattern.

A template ref on a component (`<VView ref="viewRef">`) does not resolve to the
native node: Vue's `setRef` stores the component's public instance proxy, whose
`$el` is the root element. Target resolution only accepted `{ id }`, so the
documented `useGesture(viewRef)` pattern threw `Target ref has no .value.id` at
mount — and because the deferred-attach watcher rethrew on every retry, a
gesture could never bind through a template ref at all. Resolution now unwraps
`$el`, and the public `GestureTarget` type accepts the component-instance
shape. A new test mounts a real `VView` with a template ref and asserts the
listener lands on the id of the created node.

The `gestures` example renders again as part of this: its five demos were plain
objects with `template:` strings, which the compiler-less runtime mounts as
no-ops; they are now single-file components under `app/demos/`.
