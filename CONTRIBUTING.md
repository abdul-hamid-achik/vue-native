# Contributing to Vue Native

Thank you for your interest in contributing! This guide covers everything you need to get started.

## Prerequisites

- [Bun](https://bun.sh) 1.3+
- [Xcode](https://developer.apple.com/xcode/) 15+ (for iOS work)
- [Android Studio](https://developer.android.com/studio) Hedgehog+ (for Android work)
- Node.js 18+ (for CLI and tooling)

## Repository Setup

```bash
git clone https://github.com/YOUR_USERNAME/vue-native.git
cd vue-native
bun install
bun run build
```

## Project Structure

```
packages/
  runtime/       — Core renderer and bridge (@thelacanians/runtime)
  navigation/    — Stack and tab navigation (@thelacanians/navigation)
  vite-plugin/   — Build integration (@thelacanians/vite-plugin)
  cli/           — Project scaffolding (@thelacanians/cli)
native/
  ios/VueNativeCore/    — Swift package (VueNativeCore) for iOS
  android/VueNativeCore/ — Kotlin library (VueNativeCore) for Android
examples/        — Example apps
```

## Development Workflow

### TypeScript packages

```bash
bun run dev          # Watch mode across all packages
bun run build        # Full build
bun run test         # Run unit tests
bun run typecheck    # Type-check all packages
```

### iOS native

Open `native/ios/VueNativeCore/` as a Swift Package in Xcode, or build with:
```bash
swift build --package-path native/ios/VueNativeCore/
```

### Android native

Open `native/android/` in Android Studio.

### Running an example

```bash
# Terminal 1 — start Vite dev server
cd examples/counter && bun run dev

# iOS: open ios/ in Xcode, run on simulator
# Android: open native/android/ in Android Studio, run on emulator
```

## Contribution Guidelines

### Adding a Component

1. Add the TypeScript component definition in `packages/runtime/src/components/`
2. Register it in `packages/runtime/src/index.ts`
3. Add the iOS Swift factory in `native/ios/VueNativeCore/Sources/VueNativeCore/Components/Factories/`
4. Register the factory in `native/ios/VueNativeCore/Sources/VueNativeCore/Components/ComponentRegistry.swift`
5. Add the Android Kotlin factory in `native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Components/Factories/`
6. Register it in `native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Components/ComponentRegistry.kt`
7. Add an example in the appropriate example app
8. Update the README component table

### Adding a Native Module

1. Add the TypeScript composable in `packages/runtime/src/composables/`
2. Export it from `packages/runtime/src/index.ts`
3. Implement the Swift module in `native/ios/VueNativeCore/Sources/VueNativeCore/Modules/`
4. Register it in `native/ios/VueNativeCore/Sources/VueNativeCore/Modules/NativeModuleRegistry.swift`
5. Implement the Kotlin module in `native/android/.../Modules/`
6. Register it in `NativeModuleRegistry.kt`

### Code Style

- **TypeScript:** Follow existing conventions. `bun run typecheck` must pass.
- **Swift:** Standard Swift style. No force-unwraps in production paths.
- **Kotlin:** Standard Kotlin style. Prefer `?.` safe calls over `!!`.

### Tests

- Unit tests for the runtime live in `packages/runtime/src/__tests__/`
- Run with: `bun run test`
- New bridge functionality should include tests

### Pull Requests

1. Fork the repo and create a feature branch: `git checkout -b feat/my-feature`
2. Make your changes and ensure `bun run build && bun run test && bun run typecheck` all pass
3. Keep commits focused — one logical change per commit
4. Open a PR with a clear description of what and why
5. Link any related issues

## Reporting Issues

Use [GitHub Issues](../../issues). Include:
- Platform (iOS / Android / both)
- OS and Xcode/Android Studio version
- Minimal reproduction case
- Expected vs. actual behavior

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
