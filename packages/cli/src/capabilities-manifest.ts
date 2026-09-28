/**
 * `unknown` means the manifest could not read that platform's ComponentRegistry
 * (no bundled or vendored `native/` tree was found), so support is unverified
 * rather than assumed. It is deliberately distinct from `unsupported`.
 *
 * `runtime-composed` means the component is implemented entirely in TypeScript
 * and renders down to other components, so no native factory exists or is
 * needed. Reporting those as `unsupported` would be a lie in the opposite
 * direction from the hardcoded `full` this manifest used to emit.
 */
export type PlatformSupport =
  | 'full'
  | 'stub'
  | 'unsupported'
  | 'host-integration-required'
  | 'runtime-composed'
  | 'unknown'

export type HostPlatform = 'ios' | 'android' | 'macos'

export interface ComponentCapability {
  name: string
  platforms: Record<HostPlatform, PlatformSupport>
  note?: string
}

export interface ModuleCapability {
  name: string
  composables: string[]
  platforms: Record<HostPlatform, PlatformSupport>
  note?: string
}

export interface CapabilityLimitation {
  id: string
  status: string
  message: string
}

export const BUILT_IN_COMPONENT_NAMES = [
  'VView',
  'VText',
  'VButton',
  'VInput',
  'VSwitch',
  'VActivityIndicator',
  'VScrollView',
  'VImage',
  'VSVG',
  'VKeyboardAvoiding',
  'VSafeArea',
  'VSlider',
  'VList',
  'VModal',
  'VAlertDialog',
  'VStatusBar',
  'VWebView',
  'VProgressBar',
  'VPicker',
  'VSegmentedControl',
  'VActionSheet',
  'VRefreshControl',
  'VPressable',
  'VSectionList',
  'VCheckbox',
  'VRadio',
  'VDropdown',
  'VVideo',
  'VFlatList',
  'VTabBar',
  'VToolbar',
  'VSplitView',
  'VOutlineView',
  'VDrawer',
  'VDrawerItem',
  'VDrawerSection',
  'VTransition',
  'VTransitionGroup',
  'KeepAlive',
  'VSuspense',
] as const

const ALL_PLATFORMS: Record<HostPlatform, PlatformSupport> = {
  ios: 'full',
  android: 'full',
  macos: 'full',
}

/**
 * Components whose native factory ships in an optional add-on product rather
 * than the core framework. The registry source still names them (core
 * registers them when the add-on has bootstrapped), so registry-derived
 * support alone would report `full` to a host that never linked the product —
 * exactly the silent-blank-view failure the split is meant to make loud.
 */
export const OPTIONAL_PRODUCT_COMPONENT_NOTES: Record<string, string> = {
  VSVG: 'iOS/macOS ship VSVG in the optional VueNativeCoreSVG / VueNativeMacOSSVG '
    + 'products; the host must link the product and call its register() at launch. '
    + 'Android ships it in the core library.',
}

export const NATIVE_MODULE_CAPABILITIES: ModuleCapability[] = [
  { name: 'Accessibility', composables: ['useAccessibility'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Animation', composables: ['useAnimation', 'useSharedElementTransition'], platforms: { ...ALL_PLATFORMS } },
  { name: 'AppState', composables: ['useAppState'], platforms: { ...ALL_PLATFORMS } },
  { name: 'AsyncStorage', composables: ['useAsyncStorage'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Audio', composables: ['useAudio'], platforms: { ...ALL_PLATFORMS } },
  {
    name: 'BackHandler',
    composables: ['useBackHandler'],
    platforms: { ios: 'unsupported', android: 'full', macos: 'unsupported' },
    note: 'Android system back only. Returning true does not stop the JS router.',
  },
  {
    name: 'BackgroundTask',
    composables: ['useBackgroundTask'],
    platforms: { ios: 'full', android: 'full', macos: 'unsupported' },
  },
  { name: 'Battery', composables: ['useBattery'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Biometry', composables: ['useBiometry'], platforms: { ...ALL_PLATFORMS } },
  {
    name: 'Bluetooth',
    composables: ['useBluetooth'],
    platforms: { ios: 'full', android: 'full', macos: 'unsupported' },
  },
  {
    name: 'Calendar',
    composables: ['useCalendar'],
    platforms: { ios: 'full', android: 'full', macos: 'unsupported' },
  },
  { name: 'Camera', composables: ['useCamera'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Clipboard', composables: ['useClipboard'], platforms: { ...ALL_PLATFORMS } },
  {
    name: 'Contacts',
    composables: ['useContacts'],
    platforms: { ios: 'full', android: 'full', macos: 'unsupported' },
  },
  { name: 'Database', composables: ['useDatabase'], platforms: { ...ALL_PLATFORMS } },
  { name: 'DeviceInfo', composables: ['useDeviceInfo', 'useColorScheme'], platforms: { ...ALL_PLATFORMS } },
  {
    name: 'DragDrop',
    composables: ['useDragDrop'],
    platforms: { ios: 'unsupported', android: 'unsupported', macos: 'full' },
  },
  {
    name: 'FileDialog',
    composables: ['useFileDialog'],
    platforms: { ios: 'unsupported', android: 'unsupported', macos: 'full' },
  },
  { name: 'FileSystem', composables: ['useFileSystem'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Geolocation', composables: ['useGeolocation'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Haptics', composables: ['useHaptics'], platforms: { ...ALL_PLATFORMS } },
  {
    name: 'Http',
    composables: ['useHttp'],
    platforms: { ios: 'unsupported', android: 'full', macos: 'unsupported' },
    note: 'Apple platforms pin through the JavaScript fetch polyfill, not an Http module.',
  },
  {
    name: 'IAP',
    composables: ['useIAP'],
    platforms: { ios: 'full', android: 'full', macos: 'unsupported' },
  },
  { name: 'ImagePicker', composables: ['useImagePicker'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Inspector', composables: ['useInspector'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Keyboard', composables: ['useKeyboard'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Linking', composables: ['useLinking'], platforms: { ...ALL_PLATFORMS } },
  {
    name: 'Menu',
    composables: ['useMenu'],
    platforms: { ios: 'unsupported', android: 'unsupported', macos: 'full' },
  },
  { name: 'Network', composables: ['useNetwork'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Notifications', composables: ['useNotifications'], platforms: { ...ALL_PLATFORMS } },
  {
    name: 'OTA',
    composables: ['useOTAUpdate'],
    platforms: { ios: 'full', android: 'full', macos: 'unsupported' },
  },
  { name: 'Performance', composables: ['usePerformance'], platforms: { ...ALL_PLATFORMS } },
  { name: 'Permissions', composables: ['usePermissions'], platforms: { ...ALL_PLATFORMS } },
  { name: 'SecureStorage', composables: ['useSecureStorage'], platforms: { ...ALL_PLATFORMS } },
  {
    name: 'Sensors',
    composables: ['useAccelerometer', 'useGyroscope'],
    platforms: { ios: 'full', android: 'full', macos: 'unsupported' },
  },
  { name: 'Share', composables: ['useShare'], platforms: { ...ALL_PLATFORMS } },
  {
    name: 'SocialAuth',
    composables: ['useAppleSignIn', 'useGoogleSignIn'],
    platforms: { ios: 'full', android: 'full', macos: 'unsupported' },
  },
  { name: 'WebSocket', composables: ['useWebSocket'], platforms: { ...ALL_PLATFORMS } },
  {
    name: 'Window',
    composables: ['useWindow'],
    platforms: { ios: 'unsupported', android: 'unsupported', macos: 'full' },
  },
]

export const FRAMEWORK_LIMITATIONS: CapabilityLimitation[] = [
  {
    id: 'navigation.jsStack',
    status: 'js-stack',
    message: 'Navigation is a JavaScript stack rendered by RouterView, not UINavigationController or a native Android back stack.',
  },
  {
    id: 'navigation.routeChrome',
    status: 'stored-unused',
    message: 'Route title, headerShown, and animation are stored on the route record and are not rendered by the host.',
  },
  {
    id: 'sharedElement.registryOnly',
    status: 'experimental',
    message: 'useSharedElementTransition is a view-id registry. Nothing animates a shared-element transition yet.',
  },
  {
    id: 'backHandler.doesNotStopRouter',
    status: 'partial',
    message: 'useBackHandler return-true does not cancel the JS router or exitApp. Coordinate those yourself.',
  },
  {
    id: 'hotReload.fullReset',
    status: 'live-reload',
    message: 'Hot reload ships a full IIFE and resets the native/JS world. Component and router state are not preserved.',
  },
  {
    // Was `create.noMacosScaffold` ("A macOS app shell must be added by hand"),
    // which stopped being true when `vue-native create` began scaffolding
    // macos/project.yml + macos/Sources. The real remaining host constraint is
    // the one VueNativeWindowController's own docs call out, so declare that
    // instead of leaving a stale entry behind.
    id: 'macos.singleWindowHost',
    status: 'single-window',
    message: 'The macOS host is single-window. NativeBridge.shared and JSRuntime.shared are process-wide singletons, so a second VueNativeWindowController tears the first window\'s registry down instead of rendering a second Vue app.',
  },
  {
    id: 'plugins.reservedMetadata',
    status: 'reserved',
    message: 'vue-native.config plugins is reserved metadata. The CLI does not install or autolink plugins.',
  },
  {
    id: 'performance.bridgeOps',
    status: 'profiling-only',
    message: 'bridgeOps increments only while native performance profiling is active.',
  },
  {
    id: 'android.hostIntegrations',
    status: 'host-integration-required',
    message: 'Android camera capture and biometric prompts still need Activity-level wiring in the app host.',
  },
]
