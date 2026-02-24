# Migration & Upgrade Guide

This guide covers how to upgrade between Vue Native releases, including version-specific changes, breaking changes, and recommended post-upgrade steps.

## General Upgrade Procedure

Every Vue Native upgrade follows the same high-level steps:

1. **Update npm packages:**
```bash
bun update @thelacanians/vue-native-runtime \
  @thelacanians/vue-native-navigation \
  @thelacanians/vue-native-vite-plugin \
  @thelacanians/vue-native-cli
```

2. **Rebuild native projects.** Native fixes ship in the Swift Package (iOS) and Gradle module (Android). You must rebuild to pick them up -- `vue-native run ios` and `vue-native run android`.

3. **Run your test suite** and verify all screens manually.

::: tip
Always read the version-specific notes below before upgrading. Some releases require additional native-side steps.
:::

## v0.3.0 to v0.4.0

**Release date:** 2026-02-24 -- Production hardening. No breaking changes.

### What changed

- **Thread safety (iOS):** Timer and `requestAnimationFrame` polyfills now dispatch to the JS serial queue, preventing rare crashes under heavy concurrent animation.
- **Layout retry limits:** The layout engine caps retry attempts to avoid infinite loops when a measure function returns inconsistent results.
- **Gesture recognizer cleanup:** `VCheckbox`, `VRadio`, `VText`, and `VSegmentedControl` factories now remove gesture recognizers when the native view is recycled. Fixes memory leaks in long-lived lists.
- **Navigation state restoration:** A race condition during rapid app backgrounding/foregrounding has been resolved.
- **Test coverage:** Expanded from 319 to 465 tests.

### Recommended actions

1. Rebuild the Swift Package in Xcode (File -> Packages -> Resolve Package Versions) to pick up the thread-safety fix.
2. Rebuild the Android project with `./gradlew clean assembleDebug`.
3. Re-test screens that use `VCheckbox`, `VRadio`, or `VSegmentedControl` inside a `VList`.

## v0.2.0 to v0.3.0

**Release date:** 2026-02-23 -- Bug fixes. No breaking changes.

### What changed

- **Memory leak fixes:** Android `VListFactory`, `VModalFactory`, and `HotReloadManager` now release references correctly. iOS `VButtonFactory` leak resolved.
- **Race conditions:** Android hot reload no longer loses polyfill registrations during rapid reloads. `nodeChildren` cleanup is now atomic.
- **Crash fixes:** `NaN` values passed to `asInt` no longer crash the bridge. Uncaught bridge errors are caught and logged.
- **Render loop resilience:** The render loop recovers from individual frame errors instead of halting.
- **Callback ID overflow:** Callback IDs now wrap safely at `Number.MAX_SAFE_INTEGER`.

### Recommended actions

1. Update all `@thelacanians/vue-native-*` packages to `0.3.x`.
2. Rebuild both native projects.

::: warning
If your app uses `VList` with `VModal` on Android, this update is strongly recommended. The memory leak in v0.2.0 can cause the app to be killed by the OS after extended use.
:::

## v0.1.0 to v0.2.0

**Release date:** 2026-02-21 -- Major release adding Android. **Contains breaking changes.**

### Breaking changes

All npm packages moved to the `@thelacanians/` scope:

| v0.1.0 | v0.2.0 |
| --- | --- |
| `@vue-native/runtime` | `@thelacanians/vue-native-runtime` |
| `@vue-native/navigation` | `@thelacanians/vue-native-navigation` |
| `@vue-native/vite-plugin` | `@thelacanians/vue-native-vite-plugin` |
| `@vue-native/cli` | `@thelacanians/vue-native-cli` |

### Step-by-step upgrade

1. **Remove old packages and install new ones:**
```bash
bun remove @vue-native/runtime @vue-native/navigation @vue-native/vite-plugin
bun add @thelacanians/vue-native-runtime @thelacanians/vue-native-navigation
bun add -d @thelacanians/vue-native-vite-plugin @thelacanians/vue-native-cli
```

2. **Update all imports** across your codebase:
```ts
// Before
import { VView, VText } from '@vue-native/runtime'
import { createRouter } from '@vue-native/navigation'

// After
import { VView, VText } from '@thelacanians/vue-native-runtime'
import { createRouter } from '@thelacanians/vue-native-navigation'
```

3. **Update `vite.config.ts`:**
```ts
import vueNative from '@thelacanians/vue-native-vite-plugin'
```

4. **Add the Android project** if you want Android support. Scaffold a fresh project and copy the `android/` directory:
```bash
npx @thelacanians/vue-native-cli create temp-project
cp -r temp-project/android ./android
rm -rf temp-project
```

5. Rebuild and test on both platforms.

::: danger
The old `@vue-native/*` packages are no longer published. You must migrate to `@thelacanians/*` to receive future updates.
:::

## Updating Native Dependencies

### iOS (Swift Package)

1. Open your `.xcodeproj` or `.xcworkspace` in Xcode.
2. Navigate to **File -> Packages -> Update to Latest Package Versions**.
3. Clean the build folder: **Product -> Clean Build Folder** (Shift+Cmd+K).
4. Build and run.

If you use a local copy of the Swift Package (in `native/ios/`), pull the latest source and rebuild.

### Android (Gradle)

1. If using a remote dependency, bump the version in `android/app/build.gradle`:
```groovy
implementation 'com.thelacanians:vue-native-core:0.4.0'
```
2. Sync Gradle: **File -> Sync Project with Gradle Files** in Android Studio.
3. Clean and rebuild: `cd android && ./gradlew clean assembleDebug`.

## Troubleshooting Upgrades

### Stale JavaScript bundle

After updating npm packages, the old Vite output may be cached. Force a clean build with `rm -rf dist/ && bun run vite build`.

### Cached `node_modules`

If you see unexpected module resolution errors, remove and reinstall:
```bash
rm -rf node_modules bun.lockb
bun install
```

### Xcode Derived Data

If you get "module compiled for a different version" errors after updating the Swift Package, clear the Xcode cache with `rm -rf ~/Library/Developer/Xcode/DerivedData` and rebuild.

### Android build cache

Stale class files can persist across Gradle builds. Clean thoroughly:
```bash
cd android && ./gradlew clean && rm -rf .gradle build app/build && cd ..
```

### Hot reload stops working after upgrade

The dev server and native `HotReloadManager` must use the same WebSocket protocol. After upgrading, restart the dev server and rebuild the app with `vue-native dev --ios` (or `--android`).

::: tip
When in doubt, the nuclear option works: delete `node_modules`, `dist/`, Xcode Derived Data, and the Android `.gradle` cache, then reinstall and rebuild from scratch.
:::
