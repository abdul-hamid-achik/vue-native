/**
 * Built-in Vue Native components.
 *
 * These components are automatically registered when using createApp()
 * from @thelacanians/vue-native-runtime, so they can be used directly in templates
 * without explicit imports. They can also be imported individually for
 * use in render functions or JSX.
 */

import type { Component } from '@vue/runtime-core'
import { VView } from './VView'
import { VText } from './VText'
import { VButton } from './VButton'
import { VInput } from './VInput'
import { VSwitch } from './VSwitch'
import { VActivityIndicator } from './VActivityIndicator'
import { VScrollView } from './VScrollView'
import { VImage } from './VImage'
import { VKeyboardAvoiding } from './VKeyboardAvoiding'
import { VSafeArea } from './VSafeArea'
import { VSlider } from './VSlider'
import { VList } from './VList'
import { VModal } from './VModal'
import { VAlertDialog } from './VAlertDialog'
import { VStatusBar } from './VStatusBar'
import { VWebView } from './VWebView'
import { VProgressBar } from './VProgressBar'
import { VPicker } from './VPicker'
import { VSegmentedControl } from './VSegmentedControl'
import { VActionSheet } from './VActionSheet'
import { VRefreshControl } from './VRefreshControl'
import { VPressable } from './VPressable'
import { VSectionList } from './VSectionList'
import { VCheckbox } from './VCheckbox'
import { VRadio } from './VRadio'
import { VDropdown } from './VDropdown'
import { VVideo } from './VVideo'
import { VFlatList } from './VFlatList'
import { VTabBar } from './VTabBar'
import { VDrawer, VDrawerItem, VDrawerSection } from './VDrawer'
import { VTransition, VTransitionGroup } from './VTransition'
import { KeepAlive } from './KeepAlive'
import { VSuspense, defineAsyncComponent } from './VSuspense'

export {
  VView,
  VText,
  VButton,
  VInput,
  VSwitch,
  VActivityIndicator,
  VScrollView,
  VImage,
  VKeyboardAvoiding,
  VSafeArea,
  VSlider,
  VList,
  VModal,
  VAlertDialog,
  VStatusBar,
  VWebView,
  VProgressBar,
  VPicker,
  VSegmentedControl,
  VActionSheet,
  VRefreshControl,
  VPressable,
  VSectionList,
  VCheckbox,
  VRadio,
  VDropdown,
  VVideo,
  VFlatList,
  VTabBar,
  VDrawer,
  VDrawerItem,
  VDrawerSection,
  VTransition,
  VTransitionGroup,
  KeepAlive,
  VSuspense,
  defineAsyncComponent,
}

export type { AlertButton } from './VAlertDialog'
export type { StatusBarStyle } from './VStatusBar'
export type { WebViewSource } from './VWebView'
export type { ActionSheetAction } from './VActionSheet'
export type { RadioOption } from './VRadio'
export type { DropdownOption } from './VDropdown'
export type { FlatListRenderItemInfo } from './VFlatList'
export type { TabConfig } from './VTabBar'
export type { AsyncComponentOptions } from './VSuspense'

export const builtInComponents: Record<string, Component> = {
  VView,
  VText,
  VButton,
  VInput,
  VSwitch,
  VActivityIndicator,
  VScrollView,
  VImage,
  VKeyboardAvoiding,
  VSafeArea,
  VSlider,
  VList,
  VModal,
  VAlertDialog,
  VStatusBar,
  VWebView,
  VProgressBar,
  VPicker,
  VSegmentedControl,
  VActionSheet,
  VRefreshControl,
  VPressable,
  VSectionList,
  VCheckbox,
  VRadio,
  VDropdown,
  VVideo,
  VFlatList,
  VTabBar,
  VDrawer,
  VDrawerItem,
  VDrawerSection,
  VTransition,
  VTransitionGroup,
  KeepAlive,
  VSuspense,
}
