/**
 * Global component type declarations for Vue language tooling.
 *
 * createApp() registers every built-in component in the app's global
 * registry, so templates can use <VView>, <VText>, etc. without importing
 * them. Without this augmentation, the Vue language server (Volar) and
 * vue-tsc cannot resolve those tags: editors give no autocomplete or prop
 * typing in templates, and strictTemplates projects fail outright.
 *
 * Keep this list in sync with builtInComponents (components/index.ts) and
 * the extra registrations in createApp() (index.ts); the assertions in
 * __tests__/globalComponents.test.ts fail the type check when they drift.
 *
 * KeepAlive is intentionally absent: @vue/runtime-core already declares it
 * in GlobalComponents, and our runtime re-exports Vue's own KeepAlive.
 */
import {
  type VView,
  type VText,
  type VButton,
  type VInput,
  type VSwitch,
  type VActivityIndicator,
  type VScrollView,
  type VImage,
  type VSVG,
  type VKeyboardAvoiding,
  type VSafeArea,
  type VSlider,
  type VList,
  type VModal,
  type VAlertDialog,
  type VStatusBar,
  type VWebView,
  type VProgressBar,
  type VPicker,
  type VSegmentedControl,
  type VActionSheet,
  type VRefreshControl,
  type VPressable,
  type VSectionList,
  type VCheckbox,
  type VRadio,
  type VDropdown,
  type VVideo,
  type VFlatList,
  type VTabBar,
  type VToolbar,
  type VSplitView,
  type VOutlineView,
  type VDrawer,
  type VDrawerItem,
  type VDrawerSection,
  type VTransition,
  type VTransitionGroup,
  type VSuspense,
} from './components'
import { type ErrorBoundary } from './errorBoundary'

declare module '@vue/runtime-core' {
  export interface GlobalComponents {
    VView: typeof VView
    VText: typeof VText
    VButton: typeof VButton
    VInput: typeof VInput
    VSwitch: typeof VSwitch
    VActivityIndicator: typeof VActivityIndicator
    VScrollView: typeof VScrollView
    VImage: typeof VImage
    VSVG: typeof VSVG
    VKeyboardAvoiding: typeof VKeyboardAvoiding
    VSafeArea: typeof VSafeArea
    VSlider: typeof VSlider
    VList: typeof VList
    VModal: typeof VModal
    VAlertDialog: typeof VAlertDialog
    VStatusBar: typeof VStatusBar
    VWebView: typeof VWebView
    VProgressBar: typeof VProgressBar
    VPicker: typeof VPicker
    VSegmentedControl: typeof VSegmentedControl
    VActionSheet: typeof VActionSheet
    VRefreshControl: typeof VRefreshControl
    VPressable: typeof VPressable
    VSectionList: typeof VSectionList
    VCheckbox: typeof VCheckbox
    VRadio: typeof VRadio
    VDropdown: typeof VDropdown
    VVideo: typeof VVideo
    VFlatList: typeof VFlatList
    VTabBar: typeof VTabBar
    VToolbar: typeof VToolbar
    VSplitView: typeof VSplitView
    VOutlineView: typeof VOutlineView
    VDrawer: typeof VDrawer
    VDrawerItem: typeof VDrawerItem
    VDrawerSection: typeof VDrawerSection
    VTransition: typeof VTransition
    VTransitionGroup: typeof VTransitionGroup
    VSuspense: typeof VSuspense
    ErrorBoundary: typeof ErrorBoundary
    VErrorBoundary: typeof ErrorBoundary
  }
}
