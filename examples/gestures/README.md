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

> **Why the demos are SFCs.** The runtime re-exports `@vue/runtime-core` only and
> ships no template compiler, so a plain object with a `template:` string mounts
> a no-op. Each demo lives in `app/demos/` as a single-file component, compiled
> at build time by `@vitejs/plugin-vue`. Gesture attachment needs no lifecycle
> gymnastics: `useGesture(viewRef, …)` / `useComposedGestures(viewRef)` accept a
> template ref that is still `null` during `setup()` and attach themselves once
> the view exists.

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
