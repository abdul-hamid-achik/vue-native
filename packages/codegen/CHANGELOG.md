# @thelacanians/vue-native-codegen

## 0.6.5

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

## 0.0.2

### Patch Changes

- 4bdb630: Fix `workspace:*` protocol that caused `npm error Unsupported URL Type "workspace:"` when installing packages globally. Replaced with `^0.0.1` semver ranges for internal dependencies (sfc-parser, codegen) that are bundled into dist at build time.
- Updated dependencies [4bdb630]
  - @thelacanians/vue-native-sfc-parser@0.0.2
