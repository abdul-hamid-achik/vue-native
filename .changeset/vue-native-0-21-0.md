---
'@thelacanians/vue-native-runtime': minor
'@thelacanians/vue-native-navigation': minor
'@thelacanians/vue-native-vite-plugin': minor
'@thelacanians/vue-native-cli': minor
---

0.21.0 — security fail-closed, a buildable Android scaffold, and a macOS host.

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
