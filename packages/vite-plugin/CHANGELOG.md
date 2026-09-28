# @thelacanians/vue-native-vite-plugin

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

## 0.20.0

### Minor Changes

- 03aff46: `vue-native generate` treats parse errors as failures and commits generated files atomically (write, then prune stale output). `vue-native doctor [--json]` reports toolchain and native-project health. Scaffolded apps no longer enable DOM libs, pin Gradle 8.6 to match the bundled wrapper, and include a `macos` config section.

### Patch Changes

- Updated dependencies [03aff46]
  - @thelacanians/vue-native-codegen@0.6.8

## 0.19.0

### Patch Changes

- 5f114a5: Toolchain fixes: `run android`/`build android` now work on Windows (the CLI resolves `gradlew.bat` with a shell instead of spawning the POSIX `./gradlew` script); `vue-native dev` fails fast with an actionable message when Bun is missing instead of hanging on "Waiting for app to connect..."; iOS/macOS commands on non-macOS hosts explain that Xcode on macOS is required instead of suggesting `brew install xcodegen`; the `<native>` block validator accepts `NativeModule` anywhere in a class's conformance list (e.g. `class LocationModule: NSObject, NativeModule` — previously rejected with a misleading error); the Vite plugin no longer re-scans nested `node_modules` trees on every hot-reload edit; scaffolded `.gitignore` excludes the XcodeGen-generated `ios/*.xcodeproj`/`*.xcworkspace`; and `run`/`build` warn when `vue-native.config.ts` deployment targets have drifted from the native project files (which are the source of truth after scaffolding).
- Updated dependencies [5f114a5]
  - @thelacanians/vue-native-codegen@0.6.7

## 0.18.1

## 0.18.0

## 0.17.0

## 0.16.0

## 0.15.0

## 0.14.1

## 0.14.0

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

### Minor Changes

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

### Patch Changes

- Updated dependencies [ba8c07b]
  - @thelacanians/vue-native-codegen@0.6.5

## 0.6.5

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
