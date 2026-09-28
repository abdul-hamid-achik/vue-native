# @thelacanians/vue-native-navigation

## 0.22.0

### Patch Changes

- Updated dependencies [5d0e1dc]
- Updated dependencies [3af2cea]
  - @thelacanians/vue-native-runtime@0.22.0

## 0.21.0

### Minor Changes

- 47fd9ed: 0.21.0 — security fail-closed, a buildable Android scaffold, and a macOS host.

  ## Breaking changes

  - **Android: the library no longer injects permissions into your app.** CAMERA,
    ACCESS_FINE/COARSE_LOCATION, READ/WRITE_CONTACTS, READ/WRITE_CALENDAR,
    POST_NOTIFICATIONS, READ_MEDIA_IMAGES and READ_EXTERNAL_STORAGE are no longer
    merged from the library manifest. Apps that use those features must declare
    them themselves (an opt-in snippet is in the library manifest and README);
    without them the feature is denied rather than silently granted to every
    app. RECORD_AUDIO, the Bluetooth permissions and BILLING are now documented
    as host-provided too. `com.android.vending.BILLING` and a `<queries>` block
    for http/https/mailto/tel ARE added.
  - **Android: `NativeModuleRegistry.destroyAll()` now requires an owner.**
    Hosts calling the no-argument form must pass their bridge.
  - **Android: the `onBackPressed()` override is gone**, replaced by
    `OnBackPressedDispatcher`. Hosts that overrode it or called
    `super.onBackPressed()` must migrate; `performDefaultBackAction()` is
    unchanged.
  - **OTA updates fail closed.** Without a natively configured publisher key
    (Info.plist `VueNativeOTAVerifyKey`, AndroidManifest meta-data
    `com.vuenative.ota.verifyKey`, or `configurePublisherKey`) every update is
    rejected; the hash-only path is gone. `OTA.setVerifyKey` from JavaScript is
    refused — it previously let any code running in the bundle replace the key
    used to authenticate updates. Downgrades, including equal versions, are
    rejected. `useOTAUpdate(url, { verifyKey })` is deprecated and ignored with a
    warning.
  - **FileSystem is sandboxed.** Paths outside documents/caches/app-support/tmp
    now error instead of working, including `exists()` which used to return
    false; relative paths resolve against documents; the framework's own
    VueNativeOTA directory is denied. `downloadFile` requires HTTPS (loopback
    exempt) and caps at 25 MiB by default.
  - **VWebView refuses non-HTTP sources** (`file:`, `javascript:`, `data:`) and
    any navigation or `postMessage` from an origin other than the one in
    `source`. Add `allowedOrigins` to extend it.
  - **`vue-native run` builds a development bundle by default.** It writes the
    same `dist/vue-native-bundle.js` that `dev` serves, so the previous
    production default silently replaced a live session's bundle with a
    minified, `__DEV__=false`, sourcemap-less one. Pass `--mode production` for
    the old behaviour.
  - **Newly scaffolded iOS apps declare eight privacy usage descriptions.**
    They were previously commented out, which made the first `useCamera()` call
    a hard process termination. Delete the ones you do not use before App Store
    submission.

  ## Added

  - `vue-native create` scaffolds a **macOS host** (`macos/` XcodeGen project),
    so `vue-native run macos` and `build macos` work on a fresh project.
    `examples/macos-showcase` now ships one too.
  - `vue-native run --port N` reaches the native host via build settings
    (Info.plist `VueNativeDevServerURL`, Android `BuildConfig.DEV_SERVER_URL`);
    the port is no longer hardcoded in scaffolded sources.
  - `vue-native doctor` checks XcodeGen, the iOS Simulator **runtime** (the 8.5
    GB download that is the most common first-run blocker) and `adb`, searching
    the usual SDK locations when it is not on PATH.
  - `useSecureStorage` exposes `getProtectedItem` / `setProtectedItem` /
    `removeProtectedItem` (biometry-gated on iOS/macOS; Android rejects with an
    explanation). `VWebView` exposes `allowedOrigins`. `VInput` exposes
    `autoFocus` (macOS). `VStatusBar` exposes `backgroundColor` (Android).
  - `useGesture` / `useComposedGestures` accept a template ref that is still
    null during setup and attach when it resolves; `useComposedGestures` also
    returns `attach` / `detach`.

  ## Fixed

  - Android scaffolds build: AGP 8.7.3 with a Gradle 8.6 wrapper was
    impossible; the wrapper is now 8.11.1 and a test compares the two versions
    against a minimum-Gradle table instead of asserting a literal string.
  - `@longPress` fires on iOS and on macOS `VButton` (event-name casing).
  - macOS renders auto-sized text: `LayoutNode` gave children without an
    explicit main-axis size a basis of 0. Layout also stops compounding
    percentages per nesting level. **Layouts that relied on text collapsing to
    zero height will grow.**
  - macOS installs a standard main menu, so Cmd+Q quits and Cmd+C/V/X/A work;
    the window is no longer hardcoded black and semantic colours re-resolve on
    appearance change.
  - The bridge no longer discards a whole frame when one prop is
    unserialisable, no longer evicts in-flight `timeoutMs: 0` calls such as IAP
    purchases, and settles pending calls on reset instead of stranding them.
  - Sixteen human-gated or unbounded module calls (IAP, camera capture, file
    download, sign-in, permission prompts, Bluetooth connect) no longer reject
    at the 30 s default timeout.
  - `vue-native dev` fails loudly on a busy port instead of waiting forever;
    Android hot reload is gated on debuggable builds and private hosts.
  - Examples: broken composable calls, array `:style` on `VFlatList`, and every
    example is now typechecked with `vue-tsc`.

  ## Tooling

  - New gates: component/prop/event parity across the three native registries
    (with a shrinking baseline of known gaps), docs-content contracts, AGP↔Gradle
    compatibility, and 16 KB page alignment of bundled native libraries.
  - CI now bounds every job, uploads xcresult/Gradle/receipt artifacts, runs the
    app-shell smoke with `--require`, and adds a nightly latest-toolchain matrix
    plus Renovate with dashboard approval for native bumps.

### Patch Changes

- Updated dependencies [47fd9ed]
  - @thelacanians/vue-native-runtime@0.21.0

## 0.20.0

### Minor Changes

- 03aff46: Serialize navigation transitions so concurrent pushes cannot drop a route; keep replace/reset/goBack guard redirects on the same stack operation; disable pointer events on inactive RouterView screens. Flatten array styles, fix concurrent useDatabase opens, and clear Teleport targets on hot-reload teardown. Android certificate pins now merge like Apple, and OTA/FileSystem/image loads use the pin-aware HTTP client. Android VScrollView honors `horizontal` and `scrollEnabled`.

### Patch Changes

- Updated dependencies [03aff46]
  - @thelacanians/vue-native-runtime@0.20.0

## 0.19.0

### Patch Changes

- Updated dependencies [7755434]
  - @thelacanians/vue-native-runtime@0.19.0

## 0.18.1

### Patch Changes

- Updated dependencies [a39f837]
- Updated dependencies [cd80840]
  - @thelacanians/vue-native-runtime@0.18.1

## 0.18.0

### Patch Changes

- Updated dependencies [f8b825f]
  - @thelacanians/vue-native-runtime@0.18.0

## 0.17.0

### Patch Changes

- Updated dependencies [d72ae63]
  - @thelacanians/vue-native-runtime@0.17.0

## 0.16.0

### Patch Changes

- Updated dependencies [a6dd93b]
  - @thelacanians/vue-native-runtime@0.16.0

## 0.15.0

### Patch Changes

- Updated dependencies [1c4bf05]
  - @thelacanians/vue-native-runtime@0.15.0

## 0.14.1

### Patch Changes

- Updated dependencies [5c318ba]
  - @thelacanians/vue-native-runtime@0.14.1

## 0.14.0

### Patch Changes

- Updated dependencies [1a834f1]
  - @thelacanians/vue-native-runtime@0.14.0

## 0.13.0

### Patch Changes

- Updated dependencies [0f1863f]
  - @thelacanians/vue-native-runtime@0.13.0

## 0.12.0

### Patch Changes

- Updated dependencies [9b21e89]
  - @thelacanians/vue-native-runtime@0.12.0

## 0.11.0

### Patch Changes

- Updated dependencies [c021ede]
  - @thelacanians/vue-native-runtime@0.11.0

## 0.10.0

### Minor Changes

- 37e6420: **Runtime — generic list slots:**

  - `VList` and `VSectionList` are now generic components: the `#item` slot scope infers the item type `T` from `data` (VList) or `sections` (VSectionList), so `item` is no longer `unknown`. `VSectionList`'s section is typed via the exported `VSectionListSection<T>`.

  **Navigation:**

  - `handleURL` now returns a `Promise<boolean>` that settles after guard resolution, and accepts `HandleURLOptions` with a `strategy: 'push' | 'reset'` deep-link strategy (`reset` resets the stack to the matched route instead of pushing).
  - New opt-in `swipeBack` router option: when enabled, the router listens for the native `gesture:swipeBack` event (iOS edge-pan) and pops the stack.
  - Tab and drawer navigators now run `beforeEach`/`beforeResolve` guards on screen transitions (guard redirects are not supported for tab/drawer transitions and block the transition instead).

  **iOS (ships with the tag):**

  - `VInput multiline` is now real: the registered view is a stable container that swaps an internal `UITextField`/`UITextView`, preserving text, traits, delegate, and events across the swap (with a placeholder overlay for multiline and a secure-single-line fallback).
  - Native left-edge swipe-back gesture dispatches `gesture:swipeBack` for the router's `swipeBack` option.

### Patch Changes

- Updated dependencies [37e6420]
  - @thelacanians/vue-native-runtime@0.10.0

## 0.9.0

### Minor Changes

- 879b1e8: Add an opt-in `handleBackButton` router option. When enabled (`createRouter({ routes, handleBackButton: true })`), the router handles the Android hardware back button/gesture: it pops the stack when possible and exits the app at the root. Defaults to `false`, so existing behavior is unchanged. When enabled, do not also register `useBackHandler` for the same screen.

  Also clarifies in the `RouteOptions` documentation that `title`/`headerShown`/`animation`/`tabBarLabel`/`tabBarIcon` are accepted for forward compatibility but are not yet rendered by the router.

### Patch Changes

- @thelacanians/vue-native-runtime@0.9.0

## 0.8.0

### Patch Changes

- Updated dependencies [f0f3c7b]
  - @thelacanians/vue-native-runtime@0.8.0

## 0.7.6

### Patch Changes

- 8f8b777: Keep every workspace and generated app on one exact Vue dependency cohort,
  validate physical runtime duplication, and exercise Vue 3.6 compatibility in a
  non-publishing CI lane. Reject unsupported Vapor SFC modes early and keep the
  native renderer isolated from DOM renderer aliases.
- Updated dependencies [8f8b777]
  - @thelacanians/vue-native-runtime@0.7.6

## 0.7.5

### Patch Changes

- @thelacanians/vue-native-runtime@0.7.5

## 0.7.4

### Patch Changes

- Updated dependencies [adcb64c]
- Updated dependencies [adcb64c]
  - @thelacanians/vue-native-runtime@0.7.4

## 0.7.3

### Patch Changes

- Updated dependencies [5d6dfdf]
  - @thelacanians/vue-native-runtime@0.7.3

## 0.7.2

### Patch Changes

- Updated dependencies [385dd68]
  - @thelacanians/vue-native-runtime@0.7.2

## 0.7.1

### Patch Changes

- Updated dependencies [7f39222]
  - @thelacanians/vue-native-runtime@0.7.1

## 0.7.0

### Patch Changes

- Updated dependencies [ba8c07b]
  - @thelacanians/vue-native-runtime@0.7.0

## 0.6.5

### Patch Changes

- @thelacanians/vue-native-runtime@0.6.5

## 0.6.3

### Patch Changes

- @thelacanians/vue-native-runtime@0.6.3

## 0.5.0

### Minor Changes

- # v0.6.0 - Navigation Components & Teleport

  ## 🎉 New Features

  ### Navigation Components

  - **VTabBar** - Tab bar navigation component with badge support
  - **VDrawer** - Drawer/side menu navigation with sections and items
  - Both components auto-registered and ready to use

  ### Teleport Support

  - **Teleport** component for rendering outside parent hierarchy
  - Perfect for modals, dialogs, tooltips, and overlays
  - Programmatic API via `useTeleport()` composable
  - Full iOS and Android native implementation

  ### v-model Directive

  - Two-way data binding for form inputs
  - Support for modifiers: `.lazy`, `.number`, `.trim`
  - Works with VInput, VSwitch, VSlider, VCheckbox, and more
  - Auto-registered in createApp

  ## 🧪 Testing

  ### E2E Testing

  - Maestro framework integration
  - 4 pre-built test flows (onboarding, login, navigation, settings)
  - CI-ready commands: `bun run test:e2e:ios`, `bun run test:e2e:android`

  ## 📚 Documentation

  ### New Guides

  - **Teleport Guide** - Complete usage guide with patterns and troubleshooting
  - **Forms Guide** - Comprehensive v-model documentation
  - **Navigation Components** - VTabBar and VDrawer usage guide

  ### Examples

  - All 16 example apps now have comprehensive READMEs
  - Includes screenshots, key concepts, and running instructions

  ## 🔧 Infrastructure

  ### Changesets

  - Automated versioning and changelog generation
  - Scripts: `bun run version`, `bun run release`, `bun run version:check`

  ### GitHub Community

  - Issue templates (bug reports, feature requests)
  - Pull request template with checklist
  - Code of Conduct (Contributor Covenant 2.0)
  - Security policy
  - Funding configuration

  ## 📦 Dependencies

  ### Vue Alignment

  - All packages aligned to Vue 3.5.12
  - Peer dependencies properly declared
  - No more version mismatches

  ## 🚀 Breaking Changes

  None - This is a minor release with new features only.

  ## 📝 Migration

  No migration needed - all changes are additive.

  ### Try the new features:

  ```vue
  <!-- Tab Bar -->
  <VTabBar :tabs="tabs" :activeTab="activeTab" />

  <!-- Drawer -->
  <VDrawer v-model:open="drawerOpen">
    <VDrawer.Item icon="🏠" label="Home" />
  </VDrawer>

  <!-- Teleport -->
  <Teleport to="modal">
    <VModal>Content</VModal>
  </Teleport>

  <!-- v-model -->
  <VInput v-model="text" />
  ```

### Patch Changes

- # Changesets Integration

  ## Added

  - Automated versioning with Changesets
  - New scripts: `version`, `release`, `version:check`
  - Fixed versioning for core packages

  ## Changed

  - Updated Changesets config to sync versions across 4 core packages

  ## Fixed

  - Manual versioning errors
  - Version sync issues between packages

- Updated dependencies
- Updated dependencies
  - @thelacanians/vue-native-runtime@0.5.0
