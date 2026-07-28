# @thelacanians/vue-native-cli

## 0.14.1

### Patch Changes

- 5c318ba: **Runtime:**

  - `VToolbar`, `VSplitView`, and `VOutlineView` (macOS-only components) now log a development warning when used on iOS/Android, where they render nothing — instead of failing silently.

  **CLI:**

  - `vue-native run ios` now auto-detects a simulator when `--simulator` is omitted (prefers an already-booted simulator, then the first available iPhone), instead of assuming a hardcoded "iPhone 16" that may not exist.

  **Native (ships with the tag):**

  - iOS/macOS hot reload now reconnects indefinitely with exponential backoff (1s→30s cap) instead of giving up after ~10 attempts when the dev server is briefly unavailable.
  - iOS/Android `VVideo` now fires `play`/`pause` events on playback state changes (previously accepted but never emitted).
  - Android event/module payloads are always serialized as valid JSON (removed a raw `toString()` concatenation that was a latent JS-injection sink).

## 0.14.0

### Patch Changes

- 1a834f1: **Runtime:**

  - New `useAccessibility()` composable: `announce(message)` makes the screen reader (VoiceOver/TalkBack) speak a status message without moving focus, and `setFocus(target)` moves accessibility focus to a view (WCAG 4.1.3 / 2.4.3). Backed by a native `Accessibility` module on iOS/Android/macOS (ships with the tag).
  - `createTheme`'s `ThemeProvider` accepts a `followSystem` prop that syncs the color scheme with the system appearance (via `useColorScheme`) and updates automatically when the OS switches light/dark mode.
  - `useBackHandler` no longer calls the Android-only `BackHandler.exitApp` on iOS/macOS (avoids a guaranteed failure when the back event is dispatched programmatically there).

  **CLI:**

  - Fixed `vue-native run ios` selecting the wrong app from DerivedData: projects are now sorted by modification time (most recent first) instead of reversed alphabetical order.
  - `vue-native dev --port` now validates the port (integer in 1–65535) and fails with a clear error instead of crashing obscurely.

## 0.13.0

## 0.12.0

## 0.11.0

### Minor Changes

- c021ede: Hot-reload authentication for network-exposed dev servers.

  - The Vite plugin now embeds a persisted hot-reload token into the bundle (`__HOT_RELOAD_TOKEN__`, stored under `node_modules/.vue-native/hot-reload-token`), and the runtime exposes it as a global so the native hot-reload client can present it.
  - `vue-native dev --lan` now requires that token: LAN clients must present a valid `?token=` on the WebSocket connection or they are rejected, so a rogue client on your network cannot inject a bundle. Loopback connections (simulators/emulators) are unaffected and the default localhost-only binding is unchanged.
  - iOS, Android, and macOS read the token from the loaded bundle and include it when connecting/reconnecting (ships with the tag).

## 0.10.0

## 0.9.0

## 0.8.0

### Minor Changes

- f0f3c7b: Security hardening, type-safe runtime APIs, and cross-platform parity improvements.

  **Breaking (types):**

  - `NativeBridge.invokeNativeModule` is now generic (`invokeNativeModule<T = unknown>()`) instead of returning `Promise<any>`. Call sites with a typed left-hand side are verified automatically; `.then()` call sites need an explicit type argument.
  - `HttpResponse<T>.data` is now `T | undefined` (204/205 responses have no body).
  - Removed style properties the native renderer never implemented: `borderStyle`, `textDecorationStyle`, `textDecorationColor`, and `overflow: 'scroll'`. `padding`/`margin` are now `number` only (percentage values were never applied). Use `<VScrollView>` for scrolling.

  **Security:**

  - OTA updates are HTTPS-only and routed through certificate pinning on iOS.
  - OTA publisher authentication: `useOTAUpdate(url, { verifyKey })` verifies an ECDSA (P-256) signature over the bundle before applying it (iOS CryptoKit, Android `SHA256withECDSA`). Falls back to SHA-256-only with a warning when no key is configured.
  - `vue-native dev` now binds to localhost by default; pass `--lan` to expose it to the local network for physical-device development.

  **Added:**

  - `selectPlatform()` helper (React Native-style `Platform.select`) and `StyleSheet.hairlineWidth`.
  - 3D transforms: `perspective`, `skewX`, `skewY` (alongside `rotateX/Y/Z`) on iOS/macOS (`CATransform3D`); `rotateX/Y/Z` + `cameraDistance` on Android.
  - Local image assets: `<VImage :source="{ asset: 'logo' }" />` loads bundled images (iOS Asset Catalog, macOS named image, Android `res/drawable`). Exported `ImageSource` type.
  - `VFlatList` is now generic: `renderItem`/`keyExtractor` infer the item type from `data`.
  - The bridge emits a subscribable `bridge:error` global event (and a throttled console error) when the native runtime is not connected, instead of a single buried warning.
  - `invokeNativeModule(..., timeoutMs)` accepts `0` to disable the timeout for long-running operations; `useOTAUpdate.downloadUpdate` uses this so a slow download is no longer cancelled and cleaned up mid-flight.
  - Style props that were implemented natively but missing from the types: `paddingStart`/`paddingEnd`, `marginStart`/`marginEnd`, `elevation` (Android). `accessibilityState` is now a typed interface.

  **Fixed (native parity):**

  - Consistent color parsing across platforms: 8-digit hex is `#RRGGBBAA` (alpha last) everywhere; added `#RGB`/`#RGBA`, `rgb()`/`rgba()` (with alpha), and a shared named-color set. Invalid colors keep the previous style and log a warning instead of rendering transparent (Apple) or being silently dropped (Android).
  - Android: adaptive dark-mode-aware text color, button press feedback, V8 stack traces in the error overlay, `aspectRatio`, throttled list scroll events, input focus affordance.
  - iOS: DEBUG logging for bridge operations dropped on unknown nodes and for unknown component types; lazy list row measurement; `accessibilityRole` preserves reactive traits; Dynamic Type scaling.
  - macOS: `secureTextEntry` now masks input, `VList` uses targeted row insert/remove, `align-items: stretch` no longer overrides a definite cross-axis size, `importantForAccessibility`, `VVideo` play/pause events.
  - Docs: added local search, surfaced previously orphaned pages (`VDrawer`, navigation-components guide, `useTeleport`), and corrected broken examples (`useAnimation`, `VSuspense`, `useTeleport`, `VInput`).

## 0.7.6

### Patch Changes

- 8f8b777: Keep every workspace and generated app on one exact Vue dependency cohort,
  validate physical runtime duplication, and exercise Vue 3.6 compatibility in a
  non-publishing CI lane. Reject unsupported Vapor SFC modes early and keep the
  native renderer isolated from DOM renderer aliases.
- Updated dependencies [8f8b777]
  - @thelacanians/vue-native-sfc-parser@0.6.7

## 0.7.5

### Patch Changes

- edaa4d4: Correct public documentation and examples for platform-targeted development,
  WebSocket and Android host lifecycle APIs, and native-block code generation.
  Package guidance now uses executable commands, current native-module
  signatures, canonical output paths, and collision-free example module names.
- Updated dependencies [edaa4d4]
  - @thelacanians/vue-native-codegen@0.6.6
  - @thelacanians/vue-native-sfc-parser@0.6.6

## 0.7.4

### Patch Changes

- adcb64c: Make the selected iOS, Android, or macOS CLI target authoritative in Vite, including for configs with an existing explicit platform. Validate platform environment values, expose the scaffolded platform constant type, and reject contradictory multi-platform development commands.

## 0.7.3

## 0.7.2

## 0.7.1

## 0.7.0

### Patch Changes

- ba8c07b: Expose macOS runtime component wrappers for toolbar, split view, and outline view usage from Vue.

  Harden renderer and composable lifecycle behavior across remounts, native-node removal, dialogs, device state, geolocation, tab identity, HTTP requests, and event dispatch.

  Improve native parity and cleanup across iOS, Android, and macOS, including host replacement, keyed moves, modal and picker behavior, percentage flex dimensions, back handling, certificate-pinned HTTP/fetch requests, and native-module ownership.

  Make native-block generation deterministic and safe for multi-module SFCs. Generated APIs now use actual bridge dispatch labels and Promise types, Swift registries are platform-specific, and Kotlin modules receive the active host context plus atomic bridge initialization.

  Harden the Vite codegen integration so add/change/unlink events are serialized, last-known-good output survives parse errors, and generation failures stop production builds.

  Make iOS and Android OTA updates usable end to end: require verified version/hash metadata, implement verify and partial-download cleanup methods, keep rollback-safe content-addressed bundles, and load valid applied bundles at production startup with an embedded fallback.

  Make fresh CLI scaffolds self-contained and verifiable: package the native runtimes from cache-safe inputs, regenerate them before every pack, embed the JavaScript bundle in generated iOS apps, copy it into Android assets, validate build modes, and await native subprocess completion without shell-interpolating user input.

  Strengthen release gates with native contract checks, Knip, non-mutating Lefthook hooks, integrated local-tarball scaffold smoke tests, example and editor-tool type checks, least-privilege publish jobs, and post-version validation before publication.

  Require publication to follow a successful CI run for the exact trusted main-branch commit, and reject stale releases if main advances during validation.

  Close additional native parity gaps around image source loading and stale requests, WebView listener isolation and initial JavaScript policy, pre-Android-13 notification permission status, and deterministic Apple view-factory destruction.

  Make video autoplay and programmatic pause state safe across source preparation and replacement on iOS, Android, and macOS, and clean up native media, dialog, modal, toolbar, keyboard, image, and WebView resources during unmount or hot reload. Lay out detached macOS modal content and keep user-close dismissal state exact and reopenable.

  Polish public runtime and navigation behavior across transitions, drawer/tab declarative screens, push errors, accessibility state, modal styling, deep links, and documented examples.

- Updated dependencies [ba8c07b]
  - @thelacanians/vue-native-codegen@0.6.5

## 0.6.5

### Patch Changes

- 17ce628: Release pipeline fixes:

  - CLI `prebuild` no longer copies Swift/Gradle build caches into the package (uses `rsync` with targeted excludes; published tarball ~361 KB instead of multi-GB).
  - `vue-native --version` now reads the real version from package.json (was hard-coded to 0.1.0).
  - Android Maven publication and scaffolded SPM/Gradle dep coordinates now derive from `packages/runtime/package.json`, keeping the native artifact version in sync with the JS runtime release.
  - Added a root `Package.swift` so `https://github.com/abdul-hamid-achik/vue-native` resolves cleanly via SPM.
  - Publish workflow builds _after_ `changeset version` so dist artifacts match the version they ship with.

## 0.6.3

### Patch Changes

- 4bdb630: Fix `workspace:*` protocol that caused `npm error Unsupported URL Type "workspace:"` when installing packages globally. Replaced with `^0.0.1` semver ranges for internal dependencies (sfc-parser, codegen) that are bundled into dist at build time.
- Updated dependencies [4bdb630]
  - @thelacanians/vue-native-sfc-parser@0.0.2
  - @thelacanians/vue-native-codegen@0.0.2

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
