# @thelacanians/vue-native-vite-plugin

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
