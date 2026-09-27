# Gestures Example

This example demonstrates gesture handling in Vue Native apps using `useGesture`.

> **Requires a native host.** This directory ships Vue source and build config
> only — there is no `ios/`, `android/`, or `macos/` app shell here. `bun run
> dev:ios`, `dev:android` and `dev:macos` build the JS bundle but have nothing
> to run it in. To see this app on a device or simulator:
>
> ```bash
> bunx vue-native create my-app   # scaffolds iOS + Android hosts
> ```
>
> Then copy `app/`, `vite.config.ts` and `env.d.ts` from this example over the
> scaffold's equivalents, run `bun run build` here, and open the generated
> project in Xcode or Android Studio. `vue-native create` does not scaffold a
> macOS shell yet.

## Features Demonstrated

- **Pan gesture**: drag a view around the screen
- **Pinch gesture**: zoom with two fingers
- **Rotate gesture**: rotate with two fingers
- **Swipe gestures**: detect left / right / up / down swipes
- **Press and double tap**: tap interactions
- **Composed gestures**: multiple simultaneous gestures via `useComposedGestures`

Force touch is supported by `useGesture` but is not demoed here.

> ⚠️ **Known broken — this app currently renders nothing.** Two separate defects,
> both verified against the runtime source:
>
> 1. The five demos are plain objects with a `template:` string. The runtime
>    re-exports `@vue/runtime-core` only and never calls
>    `registerRuntimeCompiler`, so no compiler exists to turn those strings into
>    render functions — Vue warns and mounts a no-op. They need to be `.vue` SFCs
>    or `h()` render functions.
> 2. `useGesture(viewRef, …)` is called during `setup()`, but a template ref is
>    only assigned at mount. `resolveViewId` then throws
>    `[useGesture] Target ref has no .value.id`. `target` is optional, so the fix
>    is `useGesture(undefined, …)` plus `onMounted(() => attach(viewRef))`.
>    `useComposedGestures` attaches eagerly and returns no `attach`, so
>    `ComposedDemo` cannot be fixed from example code alone — it needs a runtime
>    change.
>
> The same eager-attach pattern is shown in `docs/src/composables/useGesture.md`.

## Running

### iOS

```bash
cd examples/gestures
bun install
bun run dev:ios
```

### Android

```bash
cd examples/gestures
bun install
bun run dev:android
```

### macOS

```bash
cd examples/gestures
bun install
bun run dev:macos
```

This directory intentionally contains the cross-platform Vue source only. It
does not contain the `ios/`, `android/`, or `macos/` hosts referenced by older
versions of this README. Copy the source into a generated project with the
matching native host to run it.
