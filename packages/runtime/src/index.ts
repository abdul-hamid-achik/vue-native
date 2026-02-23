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

import { createVNode, type App, type Component } from '@vue/runtime-core'
import { baseCreateApp, render } from './renderer'
import { createNativeNode, type NativeNode } from './node'
import { NativeBridge } from './bridge'
import {
  VView, VText, VButton, VInput, VSwitch, VActivityIndicator,
  VScrollView, VImage, VKeyboardAvoiding, VSafeArea, VSlider,
  VList, VModal, VAlertDialog, VStatusBar, VWebView,
  VProgressBar, VPicker, VSegmentedControl, VActionSheet,
} from './components'
import { vShow } from './directives/vShow'

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
export function createApp(rootComponent: Component, rootProps?: Record<string, any>): NativeApp {
  const app = baseCreateApp(rootComponent, rootProps) as NativeApp

  // Register built-in components so they can be used in templates
  // without explicit imports
  app.component('VView', VView)
  app.component('VText', VText)
  app.component('VButton', VButton)
  app.component('VInput', VInput)
  app.component('VSwitch', VSwitch)
  app.component('VActivityIndicator', VActivityIndicator)
  app.component('VScrollView', VScrollView)
  app.component('VImage', VImage)
  app.component('VKeyboardAvoiding', VKeyboardAvoiding)
  app.component('VSafeArea', VSafeArea)
  app.component('VSlider', VSlider)
  app.component('VList', VList)
  app.component('VModal', VModal)
  app.component('VAlertDialog', VAlertDialog)
  app.component('VStatusBar', VStatusBar)
  app.component('VWebView', VWebView)
  app.component('VProgressBar', VProgressBar)
  app.component('VPicker', VPicker)
  app.component('VSegmentedControl', VSegmentedControl)
  app.component('VActionSheet', VActionSheet)
  app.directive('show', vShow)

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
    const handleError = (globalThis as any).__VN_handleError
    if (typeof handleError === 'function') {
      handleError(errorInfo)
    }
  }

  // Dev-only warning handler
  if (typeof __DEV__ !== 'undefined' && __DEV__) {
    app.config.warnHandler = (msg, instance, trace) => {
      const componentName = instance?.$options?.name || instance?.$.type?.name || 'Anonymous'
      console.warn(`[VueNative] Warning in ${componentName}: ${msg}`)
    }
  }

  /**
   * Create a virtual root node, register it with the native bridge,
   * and mount the Vue application tree onto it.
   *
   * Uses createVNode from @vue/runtime-core to produce a VNode for the
   * root component, then passes it to the custom renderer's render() function
   * which drives the native node tree.
   */
  app.start = (): NativeNode => {
    const root = createNativeNode('__ROOT__')
    NativeBridge.createNode(root.id, '__ROOT__')
    NativeBridge.setRootView(root.id)

    // Create the root VNode. The app context (which contains registered
    // components, directives, plugins, etc.) is attached to the VNode so
    // the renderer can resolve them during patch.
    const vnode = createVNode(rootComponent, rootProps)
    vnode.appContext = app._context
    render(vnode, root)

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
export { createStyleSheet, validStyleProperties, type StyleProp, type StyleSheet } from './stylesheet'

// Built-in components (for direct import in render functions)
export {
  VView, VText, VButton, VInput, VSwitch, VActivityIndicator,
  VScrollView, VImage, VKeyboardAvoiding, VSafeArea, VSlider,
  VList, VModal, VAlertDialog, VStatusBar, VWebView,
  VProgressBar, VPicker, VSegmentedControl, VActionSheet,
} from './components'
export type { AlertButton, StatusBarStyle, WebViewSource, ActionSheetAction } from './components'

// Directives
export { vShow } from './directives/vShow'

// Composables (native module wrappers)
export {
  useHaptics, useAsyncStorage, useClipboard, useDeviceInfo, useKeyboard,
  useAnimation, useNetwork, useAppState, useLinking, useShare, usePermissions,
  useGeolocation, useCamera, useNotifications, useBiometry, useHttp,
  useColorScheme, useBackHandler,
} from './composables'
export type {
  TimingOptions, SpringOptions, NetworkState, ConnectionType, AppStateStatus,
  ShareContent, ShareResult, Permission, PermissionStatus, GeoCoordinates,
  CameraOptions, CameraResult, LocalNotification, NotificationPayload,
  BiometryType, BiometryResult, HttpRequestConfig, HttpResponse,
  ColorScheme,
} from './composables'

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
