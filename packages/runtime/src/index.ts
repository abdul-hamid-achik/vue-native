/**
 * @thelacanians/vue-native-runtime — Vue 3 custom renderer for native iOS views.
 *
 * This is the main entry point for the Vue Native runtime. It provides:
 * - A createApp() function that sets up the native renderer
 * - All Vue 3 Composition API exports (ref, reactive, computed, watch, etc.)
 * - Built-in native components (VView, VText, VButton, VInput)
 * - createStyleSheet() for defining native styles
 * - NativeBridge for advanced native interop
 */

import { type App, type Component } from '@vue/runtime-core'
import { baseCreateApp } from './renderer'
import { createNativeNode, releaseNodeId, type NativeNode } from './node'
import { NativeBridge, registerAppTeardown } from './bridge'
import { VDrawerItem, VDrawerSection, builtInComponents } from './components'
import { ErrorBoundary } from './errorBoundary'

interface VueNativeGlobals {
  __VN_handleError?: (errorInfo: string) => void
}

/**
 * Extended App interface with the .start() method for mounting to native.
 */
export interface NativeApp extends App {
  /**
   * Mount the application to a virtual root node and tell the native side
   * to begin rendering. This replaces the web-style app.mount('#app').
   *
   * @returns The virtual root NativeNode
   */
  start(): NativeNode
}

/**
 * Create a Vue Native application.
 *
 * This is the primary entry point for creating a Vue Native app. It wraps
 * Vue 3's createApp with native-specific setup:
 *
 * 1. Creates the app using the custom native renderer
 * 2. Registers all built-in components (VView, VText, VButton, VInput)
 * 3. Adds a `.start()` method that creates a virtual root, tells the bridge
 *    to register it as the root view, and mounts the Vue app to it.
 *
 * @example
 * ```ts
 * import { createApp } from '@thelacanians/vue-native-runtime'
 * import App from './App.vue'
 *
 * const app = createApp(App)
 * app.start()
 * ```
 */
export function createApp(rootComponent: Component, rootProps?: Record<string, unknown>): NativeApp {
  const app = baseCreateApp(rootComponent, rootProps) as NativeApp

  // Register built-in components so they can be used in templates
  // without explicit imports.
  for (const [name, component] of Object.entries(builtInComponents)) {
    app.component(name, component)
  }
  app.component('VDrawer.Item', VDrawerItem)
  app.component('VDrawer.Section', VDrawerSection)
  app.component('ErrorBoundary', ErrorBoundary)
  app.component('VErrorBoundary', ErrorBoundary)

  // Global error handler — catches unhandled errors in components,
  // formats them, and forwards to native for error overlay display.
  app.config.errorHandler = (err: unknown, instance, info) => {
    const error = err instanceof Error ? err : new Error(String(err))
    const componentName = instance?.$options?.name || instance?.$.type?.name || 'Anonymous'
    const errorInfo = JSON.stringify({
      message: error.message,
      stack: error.stack || '',
      componentName,
      info,
    })
    console.error(`[VueNative] Error in ${componentName}: ${error.message}`)
    const handleError = (globalThis as typeof globalThis & VueNativeGlobals).__VN_handleError
    if (typeof handleError === 'function') {
      handleError(errorInfo)
    }
  }

  // Dev-only warning handler
  if (typeof __DEV__ !== 'undefined' && __DEV__) {
    app.config.warnHandler = (msg, instance, _trace) => {
      const componentName = instance?.$options?.name || instance?.$.type?.name || 'Anonymous'
      console.warn(`[VueNative] Warning in ${componentName}: ${msg}`)
    }
  }

  /**
   * Create a virtual root node, register it with the native bridge,
   * and mount the Vue application tree onto it.
   *
   * Uses the renderer-created app.mount() method so Vue records the mounted
   * application instance and can later run component cleanup through
   * app.unmount().
   */
  let mountedRoot: NativeNode | null = null
  let unregisterTeardown: (() => void) | null = null
  let hasUnmounted = false
  const unmount = app.unmount.bind(app)

  app.unmount = () => {
    const root = mountedRoot
    const wasMounted = root !== null || app._instance !== null
    if (!wasMounted) return

    // Vue app instances are single-use: runtime-core intentionally does not
    // reset its internal mounted flag after unmount. Record that state so a
    // later start() fails explicitly instead of returning an empty native root
    // after Vue rejects the second mount with only a warning.
    hasUnmounted = true
    unregisterTeardown?.()
    unregisterTeardown = null
    mountedRoot = null
    unmount()

    // The renderer removes the app's VNode subtree, but the synthetic native
    // root is owned by start() rather than Vue. Remove and release it too so
    // unmounting does not retain an empty native root or its allocated ID.
    if (root) {
      NativeBridge.removeChild(0, root.id)
      releaseNodeId(root.id)
    }
  }

  app.start = (): NativeNode => {
    // Calling start repeatedly should be harmless and must not render a
    // second copy of the application tree into the native root.
    if (mountedRoot) {
      return mountedRoot
    }

    if (hasUnmounted) {
      throw new Error('[VueNative] This app has been unmounted and cannot be restarted. Create a new app instance.')
    }

    // A caller may have used app.mount() directly. It has no native root
    // registration, so mounting again here would leave Vue and native state
    // out of sync. Make the recovery path explicit instead.
    if (app._instance) {
      throw new Error('[VueNative] This app is already mounted. Use either app.mount() or app.start(), not both.')
    }

    const root = createNativeNode('__ROOT__')
    NativeBridge.createNode(root.id, '__ROOT__')
    NativeBridge.setRootView(root.id)

    mountedRoot = root
    try {
      // mount() creates the root VNode with the app context and, critically,
      // updates Vue's internal mounted state so app.unmount() is reliable.
      app.mount(root as never)
    } catch (error) {
      mountedRoot = null
      hasUnmounted = true
      if (app._instance) {
        try {
          unmount()
        } catch {
          // Preserve the original mount error.
        }
      }
      NativeBridge.removeChild(0, root.id)
      releaseNodeId(root.id)
      throw error
    }

    // If a mounted hook synchronously unmounted the app, do not retain a
    // stale hot-reload teardown callback.
    if (mountedRoot === root) {
      unregisterTeardown = registerAppTeardown(() => app.unmount())
    }

    return root
  }

  return app
}

// ---------------------------------------------------------------------------
// Re-export everything from @vue/runtime-core
// This gives users access to all Vue 3 APIs (ref, reactive, computed, etc.)
// through a single import from '@thelacanians/vue-native-runtime'.
// The wildcard re-export is essential because Vue's SFC template compiler
// generates code that imports internal helpers (resolveComponent, createVNode,
// openBlock, createBlock, toDisplayString, etc.) from 'vue', which our
// Vite plugin aliases to '@thelacanians/vue-native-runtime'.
// ---------------------------------------------------------------------------
export * from '@vue/runtime-core'

// ---------------------------------------------------------------------------
// Vue Native specific exports
// ---------------------------------------------------------------------------

// Renderer internals (for advanced use cases)
export { render } from './renderer'

// StyleSheet utility
export { createStyleSheet, validStyleProperties, type StyleProp, type StyleSheet, type AnyStyle } from './stylesheet'

// Style and component prop types
export type {
  ViewStyle, TextStyle, ImageStyle,
  FlexDirection, FlexWrap, JustifyContent, AlignItems, AlignSelf, AlignContent,
  Position, Display, Overflow, Direction, BorderStyle, TextAlign,
  TextDecorationLine, TextDecorationStyle, TextTransform, FontStyle, FontWeight,
  ResizeMode, ImportantForAccessibility, ShadowOffset, TransformValue,
  AccessibilityProps,
  VViewProps, VTextProps, VButtonProps, VInputProps, VSwitchProps, VImageProps,
  VScrollViewProps, VActivityIndicatorProps, VSliderProps, VListProps,
  VModalProps, VAlertDialogProps, VStatusBarProps, VWebViewProps,
  VProgressBarProps, VPickerProps, VSegmentedControlProps, VActionSheetProps,
  VKeyboardAvoidingProps, VSafeAreaProps, VRefreshControlProps, VPressableProps,
  VCheckboxProps, VRadioProps, VDropdownProps, VSectionListProps,
  VVideoProps, VFlatListProps, VTabBarProps, VDrawerProps, VDrawerItemProps,
  VToolbarProps, VSplitViewProps, VOutlineNode, VOutlineViewProps,
  VDrawerSectionProps,
} from './types'

// Built-in components (for direct import in render functions)
export {
  VView, VText, VButton, VInput, VSwitch, VActivityIndicator,
  VScrollView, VImage, VKeyboardAvoiding, VSafeArea, VSlider,
  VList, VModal, VAlertDialog, VStatusBar, VWebView,
  VProgressBar, VPicker, VSegmentedControl, VActionSheet,
  VRefreshControl, VPressable, VSectionList,
  VCheckbox, VRadio, VDropdown,
  VVideo, VFlatList,
  VTabBar, VToolbar, VSplitView, VOutlineView,
  VDrawer, VDrawerItem, VDrawerSection,
  VTransition, VTransitionGroup, KeepAlive, VSuspense, defineAsyncComponent,
  builtInComponents,
} from './components'
export type { TabConfig } from './components/VTabBar'
export type {
  AlertButton, StatusBarStyle, WebViewSource, ActionSheetAction,
  RadioOption, DropdownOption, FlatListRenderItemInfo,
  ToolbarItem, OutlineNode, TransitionProps, TransitionMode, AsyncComponentOptions,
} from './components'

// Error Boundary
export { ErrorBoundary, ErrorBoundary as VErrorBoundary } from './errorBoundary'

// Directives
export { vShow } from './directives/vShow'
export { vModel } from './directives/vModel'

// Composables (native module wrappers)
export {
  useHaptics, useAsyncStorage, useClipboard, useDeviceInfo, useKeyboard,
  useAnimation, Easing, useNetwork, useAppState, useLinking, useShare, usePermissions,
  useGeolocation, useCamera, useNotifications, useBiometry, useHttp,
  useColorScheme, useBackHandler, useSecureStorage, useI18n,
  usePlatform, useDimensions, useWebSocket, useFileSystem,
  useAccelerometer, useGyroscope,
  useAudio,
  useDatabase,
  usePerformance,
  useSharedElementTransition, getSharedElementViewId, getRegisteredSharedElements,
  clearSharedElementRegistry, measureViewFrame,
  useIAP,
  useAppleSignIn,
  useGoogleSignIn,
  useBackgroundTask,
  useOTAUpdate,
  useBluetooth,
  useCalendar,
  useContacts,
  useWindow,
  useMenu,
  useFileDialog,
  useDragDrop,
  useTeleport,
  useGesture,
  useComposedGestures,
} from './composables'
export type {
  TimingConfig, SpringConfig, KeyframeStep, SequenceAnimation, EasingType,
  TimingOptions, SpringOptions, NetworkState, ConnectionType, AppStateStatus,
  ShareContent, ShareResult, Permission, PermissionStatus, GeoCoordinates,
  CameraOptions, CameraResult, VideoCaptureOptions, VideoCaptureResult, QRCodeResult,
  LocalNotification, NotificationPayload, PushNotificationPayload, PushRegistrationError,
  BiometryType, BiometryResult, HttpRequestConfig, HttpResponse,
  ColorScheme, Platform, Dimensions, WebSocketStatus, WebSocketOptions,
  FileStat, SensorOptions, SensorData,
  AudioPlayOptions, AudioRecordOptions, AudioRecordResult,
  ExecuteResult, Row, TransactionContext,
  PerformanceMetrics,
  SharedElementFrame, SharedElementRegistration,
  Product, Purchase, TransactionState, TransactionUpdate, ProductType,
  SocialUser, AuthResult,
  BackgroundTaskType, BackgroundTaskOptions,
  UpdateInfo, VersionInfo, UpdateStatus,
  BLEDevice, BLECharacteristic, BLECharacteristicChange, BLEState,
  CalendarEvent, Calendar, CreateEventOptions,
  Contact, ContactField, CreateContactData,
  WindowInfo,
  MenuItem, MenuSection,
  OpenFileOptions, SaveFileOptions,
  PanGestureState, PinchGestureState, RotateGestureState, SwipeGestureState,
  TapGestureState, ForceTouchState, HoverState, GestureState, GestureConfig,
  GestureHandler, GestureCompositionOptions,
  UseGestureReturn, UseGestureOptions, ComposedGesture,
} from './composables'

// Theme system
export { createTheme, createDynamicStyleSheet, type ThemeDefinition, type ThemeContext } from './theme'

// Bridge (for advanced native interop)
export { NativeBridge } from './bridge'

// Node types and factory (for testing and advanced usage)
export {
  type NativeNode,
  createNativeNode,
  createTextNode,
  createCommentNode,
  resetNodeId,
} from './node'
