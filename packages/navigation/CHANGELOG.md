# @thelacanians/vue-native-navigation

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
