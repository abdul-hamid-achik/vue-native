# @thelacanians/vue-native-vite-plugin

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
