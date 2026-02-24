# Changelog

All notable changes to Vue Native are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.2] - 2026-02-24

### Fixed

- **Double shebang in CLI**: `dist/cli.js` had two `#!/usr/bin/env node` lines (one from source, one from tsup banner), causing Node/Bun to reject the script as a syntax error. Removed the shebang from source since tsup injects it via banner config.
- **workspace:* in published navigation package**: `@thelacanians/vue-native-navigation` was published with `"@thelacanians/vue-native-runtime": "workspace:*"` which npm/bun cannot resolve. Replaced with `"^0.4.1"` semver range.

## [0.4.1] - 2026-02-24

### Added

- **Security guide** (`docs/src/guide/security.md`): Certificate pinning, secure storage, network security, auth best practices, bundle verification
- **Testing guide** (`docs/src/guide/testing.md`): Unit testing setup, mocking the native bridge, testing components/composables/navigation, snapshot testing, E2E overview
- **Limitations guide** (`docs/src/guide/limitations.md`): No DOM, CSS subset, JS environment constraints, third-party library compatibility, platform differences, performance boundaries
- **Migration guide** (`docs/src/guide/migration.md`): Upgrade procedures for all versions, native dependency updates, troubleshooting upgrades

### Fixed

- **Thread safety (iOS)**: Timer and RAF polyfill state (`timers`, `rafCallbacks`, counters) is now synchronized via a dedicated serial `DispatchQueue`, preventing data races between the JS queue and main thread during hot reload or rapid setTimeout/clearTimeout cycles
- **Layout retry limit (iOS)**: `triggerLayout` retries capped at 3 attempts (100ms apart) instead of unbounded retries, preventing main thread spam when root view bounds remain zero
- **Gesture recognizer leaks (iOS)**: `VCheckboxFactory`, `VRadioFactory`, `VTextFactory`, and `VSegmentedControlFactory` now properly remove gesture recognizers and UIControl targets in `removeEventListener`, preventing accumulation on event re-registration
- **Navigation state restoration race**: Persistence watcher is now gated behind a `restoreComplete` flag, preventing early navigation from overwriting persisted state before async restore completes

### Changed

- ESLint config whitelists `console.log` in `packages/cli/` (CLI legitimately needs console output for user feedback)
- Documentation sidebar updated with 4 new pages in Advanced and Reference sections
- Test count increased from 424 to 465

## [0.3.0] - 2026-02-23

### Added

- **Integration tests**: Full Vue render cycle tests covering component mounting, reactive updates, conditional rendering, list rendering, style diffs, events, nested components, and operation batching (9 tests)
- **v-show directive tests**: 10 tests covering truthy/falsy values, null, undefined, and update skipping (was 0% coverage)
- **Bridge resilience tests**: 14 tests for callback ID wraparound, bridge error handling, event handler isolation, timeout cleanup, and reset behavior
- **Renderer resilience tests**: 13 tests for error handling in patchProp, patchStyle, insert, remove, comment node handling, and tree consistency
- `destroyView()` lifecycle method on `NativeComponentFactory` interface (Android) for factory-level cleanup
- `eventKeysPerNode` reverse index on iOS `NativeBridge` for O(1) event handler cleanup per node

### Fixed

- **Memory leak (Android)**: `VListFactory` maps (`childViews`, `scrollHandlers`, `endReachedHandlers`, `scrollListeners`, `firedEndReached`, `estimatedItemHeights`) were never cleaned up when a RecyclerView was removed from the tree
- **Memory leak (Android)**: `VModalFactory` dialog and container references persisted after modal removal
- **Memory leak (Android)**: `HotReloadManager` `CoroutineScope` was never cancelled on `disconnect()`, leaking the Job and all pending coroutines
- **Memory leak (iOS)**: `VButtonFactory` created retain cycles via redundant `objc_setAssociatedObject` calls alongside `TouchableView.onPress` closures
- **Race condition (Android)**: Hot reload did not call `JSPolyfills.reset()`, allowing old timers and RAF callbacks to fire in the new bundle context
- **Race condition (Android)**: Hot reload did not clear `nodeChildren` reverse index, causing incomplete state reset
- **Crash (iOS)**: `asInt()` in `NativeBridge` did not guard against `NaN`, `Infinity`, or out-of-range `Double` values, producing undefined behavior when cast to `Int`
- **Crash (JS)**: `__VN_flushOperations` errors were uncaught and would crash the bridge; now caught and logged
- **Silent failure (JS)**: Bridge unavailability warning only fired in dev mode; now fires in production too
- **Render loop crash (JS)**: Errors in `patchProp`, `patchStyle`, `insert`, and `remove` would break the Vue render loop; now caught and logged
- **Index bug (Android)**: `VListFactory.insertChild` sent wrong index to `notifyItemInserted` after insertion
- **Overflow (JS)**: Callback IDs incremented without bounds; now wrap around at `2,147,483,647` (32-bit signed int max)
- **CLI**: Generated projects referenced `^0.1.0` package versions; updated to match current `^0.3.0`

### Changed

- iOS event handler cleanup uses indexed lookup (O(k) per node where k = handler count) instead of O(n) full-dictionary scan
- Android `NativeBridge.cleanupNode` now calls `factory.destroyView(view)` to allow factories to release per-view state
- Android `HotReloadManager.isConnected` is now `@Volatile` for thread safety
- Android `HotReloadManager.disconnect()` recreates scope/job for potential reconnection after cancellation

## [0.2.0] - 2026-02-21

### Added

- Complete Android implementation with J2V8, FlexboxLayout, Coil, and OkHttp
- 27 native components and 19+ native modules on both iOS and Android
- All Phase 3 and Phase 4 features: IAP, social auth, Bluetooth, calendar, contacts, background tasks, OTA updates
- 319 tests across runtime and navigation packages
- 9 example apps: counter, calculator, settings, social, tasks, todo, auth-flow, chat, camera-app
- VS Code extension and Neovim plugin with snippets and diagnostics
- 79 VuePress documentation pages

## [0.1.0] - 2026-02-14

### Added

- Initial release
- Vue 3 custom renderer targeting iOS via JavaScriptCore
- Core components: VView, VText, VButton, VInput, VSwitch, VScrollView, VImage
- Bridge protocol with JSON-serialized batched operations
- Vite plugin producing IIFE bundles for native runtimes
- CLI with `vue-native create`, `dev`, and `run` commands
- Stack navigation with guards and deep linking
