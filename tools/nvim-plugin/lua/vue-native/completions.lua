-- vue-native/completions.lua — nvim-cmp completion source for Vue Native
-- Suggests component names, props, and composable names

local M = {}

-- Component prop definitions (mirrors actual component source)
local component_props = {
  VView = {
    { label = ":style", detail = "ViewStyle — flexbox layout and appearance" },
    { label = "testID", detail = "string — test identifier" },
    { label = "accessibilityLabel", detail = "string — accessibility label" },
    { label = "accessibilityRole", detail = "string — accessibility role" },
    { label = "accessibilityHint", detail = "string — accessibility hint" },
  },
  VText = {
    { label = ":style", detail = "TextStyle — text styling (fontSize, color, etc.)" },
    { label = ":numberOfLines", detail = "number — max lines before truncation" },
    { label = ":selectable", detail = "boolean — allow text selection (default: false)" },
    { label = "accessibilityLabel", detail = "string" },
  },
  -- VButton has no `variant` prop. It renders `title` as a VText when no default
  -- slot is given.
  VButton = {
    { label = "title", detail = "string — convenience label rendered as VText when no default slot is provided" },
    { label = ":titleStyle", detail = "TextStyle — styling for the title shorthand" },
    { label = ":style", detail = "ViewStyle — button container style" },
    { label = ":onPress", detail = "() => void — press handler" },
    { label = "@press", detail = "event — pressed (same handler slot as :onPress)" },
    { label = ":onLongPress", detail = "() => void — long press handler" },
    { label = "@longPress", detail = "event — long pressed" },
    { label = ":disabled", detail = "boolean — disable interactions (default: false)" },
    { label = ":activeOpacity", detail = "number — opacity when pressed (default: 0.7)" },
    { label = "accessibilityLabel", detail = "string" },
    { label = "accessibilityRole", detail = "string" },
    { label = "accessibilityHint", detail = "string" },
    { label = ":accessibilityState", detail = "object" },
    { label = "#default", detail = "slot — custom button content (overrides title)" },
  },
  VInput = {
    { label = "v-model", detail = "string — two-way text binding" },
    { label = "placeholder", detail = "string — placeholder text" },
    { label = ":secureTextEntry", detail = "boolean — password input (default: false)" },
    { label = "keyboardType", detail = "'default' | 'number-pad' | 'email-address' | 'phone-pad'" },
    { label = "returnKeyType", detail = "'done' | 'go' | 'next' | 'search' | 'send'" },
    { label = "autoCapitalize", detail = "'none' | 'sentences' | 'words' | 'characters'" },
    { label = ":autoCorrect", detail = "boolean (default: true)" },
    { label = ":maxLength", detail = "number — max character count" },
    { label = ":multiline", detail = "boolean — multiline input (default: false)" },
    { label = ":style", detail = "TextStyle" },
    { label = "@focus", detail = "event — input focused" },
    { label = "@blur", detail = "event — input blurred" },
    { label = "@submit", detail = "event — return key pressed" },
  },
  VImage = {
    { label = ":source", detail = "{ uri: string } — image URL" },
    { label = "resizeMode", detail = "'cover' | 'contain' | 'stretch' | 'center'" },
    { label = ":style", detail = "ImageStyle — width, height, borderRadius, etc." },
    { label = "@load", detail = "event — image loaded" },
    { label = "@error", detail = "event — image failed to load" },
    { label = "accessibilityLabel", detail = "string" },
  },
  VScrollView = {
    { label = ":style", detail = "ViewStyle" },
    { label = ":horizontal", detail = "boolean — scroll horizontally (default: false)" },
    { label = ":showsVerticalScrollIndicator", detail = "boolean (default: true)" },
    { label = ":showsHorizontalScrollIndicator", detail = "boolean (default: false)" },
    { label = ":scrollEnabled", detail = "boolean (default: true)" },
    { label = ":bounces", detail = "boolean (default: true)" },
    { label = ":pagingEnabled", detail = "boolean (default: false)" },
    { label = ":contentContainerStyle", detail = "ViewStyle — inner content style" },
    { label = ":refreshing", detail = "boolean — pull-to-refresh active" },
    { label = "@scroll", detail = "event — scroll position changed" },
    { label = "@refresh", detail = "event — pull-to-refresh triggered" },
  },
  VList = {
    { label = ":data", detail = "any[] — array of items to render (required)" },
    { label = ":keyExtractor", detail = "(item, index) => string — unique key per item" },
    { label = ":estimatedItemHeight", detail = "number — estimated extent per row along the scroll axis (default: 44)" },
    { label = ":windowSize", detail = "number — extra items mounted above/below the visible window (default: 10)" },
    { label = ":showsScrollIndicator", detail = "boolean (default: true)" },
    { label = ":bounces", detail = "boolean (default: true)" },
    { label = ":horizontal", detail = "boolean (default: false)" },
    { label = ":style", detail = "ViewStyle" },
    { label = "@scroll", detail = "event — scroll position" },
    { label = "@endReached", detail = "event — scrolled to end (infinite scroll)" },
    { label = "#item", detail = "slot — { item, index } scoped slot" },
    { label = "#header", detail = "slot — list header" },
    { label = "#footer", detail = "slot — list footer" },
    { label = "#empty", detail = "slot — empty state" },
  },
  -- VFlatList is the component that takes a renderItem function.
  VFlatList = {
    { label = ":data", detail = "unknown[] — array of items to render (required)" },
    { label = ":renderItem", detail = "({ item, index }) => VNode — falls back to the #item slot when omitted" },
    { label = ":keyExtractor", detail = "(item, index) => string | number (defaults to item.id / item.key / index)" },
    { label = ":itemHeight", detail = "number — fixed height for every item (fast path, skips measurement)" },
    { label = ":estimatedItemHeight", detail = "number — estimated height until measured (default: 44); ignored when itemHeight is set" },
    { label = ":windowSize", detail = "number — viewport-heights rendered above/below the visible area (default: 3)" },
    { label = ":showsScrollIndicator", detail = "boolean (default: true)" },
    { label = ":bounces", detail = "boolean (default: true)" },
    { label = ":headerHeight", detail = "number — height of the #header slot, used to offset items (default: 0)" },
    { label = ":endReachedThreshold", detail = "number — viewport fractions from the end before endReached fires (default: 0.5)" },
    { label = ":style", detail = "ViewStyle — outer scroll container" },
    { label = "@scroll", detail = "event — scroll position" },
    { label = "@endReached", detail = "event — scrolled to end (infinite scroll)" },
    { label = "#item", detail = "slot — { item, index } scoped slot (used when renderItem is not provided)" },
    { label = "#header", detail = "slot — list header" },
    { label = "#empty", detail = "slot — empty state" },
  },
  VSafeArea = {
    { label = ":style", detail = "ViewStyle — usually { flex: 1 }" },
  },
  VSwitch = {
    { label = "v-model", detail = "boolean — two-way binding" },
    { label = ":disabled", detail = "boolean (default: false)" },
    { label = "onTintColor", detail = "string — track color when on" },
    { label = "thumbTintColor", detail = "string — thumb color" },
    { label = ":style", detail = "ViewStyle" },
    { label = "@change", detail = "event — value changed" },
  },
  -- VSlider: modelValue, min, max, style, accessibility*. No minimumValue /
  -- maximumValue / minimumTrackTintColor — VSlider exposes no tint props.
  VSlider = {
    { label = "v-model", detail = "number — modelValue, current value (default: 0)" },
    { label = ":min", detail = "number — minimum value (default: 0)" },
    { label = ":max", detail = "number — maximum value (default: 1)" },
    { label = ":style", detail = "ViewStyle" },
    { label = "accessibilityLabel", detail = "string" },
    { label = "accessibilityRole", detail = "string" },
    { label = "accessibilityHint", detail = "string" },
    { label = ":accessibilityState", detail = "object" },
    { label = "@change", detail = "event — value changed" },
    { label = "@update:modelValue", detail = "event — v-model update" },
  },
  VActivityIndicator = {
    { label = "size", detail = "'small' | 'large'" },
    { label = "color", detail = "string — spinner color" },
  },
  VModal = {
    { label = ":visible", detail = "boolean — show/hide modal" },
    { label = ":style", detail = "ViewStyle" },
    { label = "@dismiss", detail = "event — modal dismissed" },
  },
  VAlertDialog = {
    { label = ":visible", detail = "boolean — show/hide alert" },
    { label = "title", detail = "string — alert title" },
    { label = "message", detail = "string — alert message" },
    { label = ":buttons", detail = "AlertButton[] — { label, style? }" },
    { label = "@confirm", detail = "event — confirmed" },
    { label = "@cancel", detail = "event — cancelled" },
    { label = "@action", detail = "event — button pressed" },
  },
  VActionSheet = {
    { label = ":visible", detail = "boolean" },
    { label = "title", detail = "string" },
    { label = ":actions", detail = "Array<{ text, style?, onPress }>" },
  },
  VStatusBar = {
    { label = "barStyle", detail = "'dark-content' | 'light-content'" },
  },
  VWebView = {
    { label = ":source", detail = "{ uri?: string, html?: string }" },
    { label = ":style", detail = "ViewStyle" },
    { label = ":javaScriptEnabled", detail = "boolean (default: true)" },
    { label = "@load", detail = "event — page loaded" },
    { label = "@error", detail = "event — load error" },
    { label = "@message", detail = "event — postMessage received" },
  },
  -- VProgressBar: progress, progressTintColor, trackTintColor, animated, style.
  -- No trackColor / progressColor. It emits nothing.
  VProgressBar = {
    { label = ":progress", detail = "number — 0.0 to 1.0 (default: 0)" },
    { label = "progressTintColor", detail = "string — fill color" },
    { label = "trackTintColor", detail = "string — background track color" },
    { label = ":animated", detail = "boolean — animate progress changes (default: true)" },
    { label = ":style", detail = "ViewStyle" },
  },
  -- VPicker is a DATE/TIME picker. modelValue is epoch milliseconds. There is no
  -- `items` prop — for a list of choices use VDropdown.
  VPicker = {
    { label = "mode", detail = "'date' | 'time' | 'datetime' (default: 'date')" },
    { label = "v-model", detail = "number — modelValue, selected date as epoch milliseconds" },
    { label = ":value", detail = "number — legacy alias of modelValue (epoch milliseconds)" },
    { label = ":minimumDate", detail = "number — earliest selectable date, epoch milliseconds" },
    { label = ":maximumDate", detail = "number — latest selectable date, epoch milliseconds" },
    { label = ":minuteInterval", detail = "number — minute stepper (default: 1)" },
    { label = ":style", detail = "ViewStyle" },
    { label = "@change", detail = "event — value changed" },
    { label = "@update:modelValue", detail = "event — v-model update" },
  },
  -- VSegmentedControl has NO modelValue, so v-model silently does nothing.
  VSegmentedControl = {
    { label = ":values", detail = "string[] — segment labels (required)" },
    { label = ":selectedIndex", detail = "number — active segment (default: 0)" },
    { label = "tintColor", detail = "string — accent color" },
    { label = ":enabled", detail = "boolean (default: true)" },
    { label = ":style", detail = "ViewStyle" },
    { label = "@change", detail = "event — { selectedIndex, value }" },
  },
  -- VKeyboardAvoiding declares only `style` and `testID`. There is no `behavior`
  -- prop and no native side (iOS/Android/macOS) reads one, so it is a no-op.
  VKeyboardAvoiding = {
    { label = ":style", detail = "ViewStyle | ViewStyle[]" },
    { label = "testID", detail = "string — test identifier" },
    { label = "#default", detail = "slot — content to keep clear of the keyboard" },
  },
  VRefreshControl = {
    { label = ":refreshing", detail = "boolean — is refreshing" },
    { label = ":onRefresh", detail = "() => void — refresh handler" },
  },
  VPressable = {
    { label = ":onPress", detail = "() => void — press handler" },
    { label = ":onLongPress", detail = "() => void — long press handler" },
    { label = ":style", detail = "ViewStyle" },
  },
  VCheckbox = {
    { label = "v-model", detail = "boolean" },
    { label = "label", detail = "string — checkbox label" },
  },
  VRadio = {
    { label = "v-model", detail = "string — selected value" },
    { label = ":options", detail = "Array<{ label, value }>" },
  },
  VDropdown = {
    { label = "v-model", detail = "string — selected value" },
    { label = ":options", detail = "Array<{ label, value }>" },
    { label = "placeholder", detail = "string" },
  },
  -- VSectionList renders from slots. No renderItem / renderSectionHeader props.
  VSectionList = {
    { label = ":sections", detail = "Array<{ title: string, data: unknown[] }> (required)" },
    { label = ":keyExtractor", detail = "(item, index) => string — defaults to the index as a string" },
    { label = ":estimatedItemHeight", detail = "number — estimated row height in points (default: 44)" },
    { label = ":stickySectionHeaders", detail = "boolean — pin section headers while scrolling (default: true)" },
    { label = ":showsScrollIndicator", detail = "boolean (default: true)" },
    { label = ":bounces", detail = "boolean (default: true)" },
    { label = ":style", detail = "ViewStyle" },
    { label = "@scroll", detail = "event — scroll position" },
    { label = "@endReached", detail = "event — scrolled to end (infinite scroll)" },
    { label = "#item", detail = "slot — { item, index, section } scoped slot" },
    { label = "#sectionHeader", detail = "slot — { section, index } scoped slot" },
    { label = "#sectionFooter", detail = "slot — per-section footer" },
    { label = "#header", detail = "slot — list header" },
    { label = "#footer", detail = "slot — list footer" },
    { label = "#empty", detail = "slot — empty state" },
  },
  VVideo = {
    { label = ":source", detail = "{ uri: string }" },
    { label = ":style", detail = "ViewStyle" },
    { label = ":controls", detail = "boolean — show playback controls" },
  },
  -- VErrorBoundary: the fallback is a SLOT, not a prop.
  VErrorBoundary = {
    { label = ":onError", detail = "(error: Error, info: string) => void — error hook" },
    { label = ":resetKeys", detail = "unknown[] — when any key changes the error state resets (default: [])" },
    { label = "#fallback", detail = "slot — { error, errorInfo, reset } scoped slot" },
    { label = "#default", detail = "slot — guarded children" },
  },
  -- Re-export of @vue/runtime-core Suspense.
  VSuspense = {
    { label = ":timeout", detail = "string | number — ms before falling back to #fallback" },
    { label = ":suspensible", detail = "boolean — allow capture by a parent Suspense (default: false)" },
    { label = "@resolve", detail = "event — all async children resolved" },
    { label = "@pending", detail = "event — entered pending state" },
    { label = "@fallback", detail = "event — fallback content shown" },
    { label = "#default", detail = "slot — async content" },
    { label = "#fallback", detail = "slot — placeholder content" },
  },
  -- macOS only — renders nothing on iOS/Android.
  VToolbar = {
    { label = ":items", detail = "Array<{ id: string, label: string, icon?: string }> (required)" },
    { label = "displayMode", detail = "'iconOnly' | 'labelOnly' | 'iconAndLabel' (default: 'iconAndLabel')" },
    { label = ":showsBaselineSeparator", detail = "boolean (default: true)" },
    { label = ":style", detail = "ViewStyle" },
    { label = "@itemClick", detail = "event — { id: string } (macOS only)" },
  },
  -- macOS only — renders nothing on iOS/Android.
  VSplitView = {
    { label = "direction", detail = "'horizontal' | 'vertical' (default: 'horizontal')" },
    { label = "dividerStyle", detail = "'thin' | 'thick' | 'paneSplitter' (default: 'thin')" },
    { label = "dividerColor", detail = "string" },
    { label = ":dividerPosition", detail = "number" },
    { label = ":style", detail = "ViewStyle" },
    { label = "@resize", detail = "event — { positions: number[] } (macOS only)" },
    { label = "#default", detail = "slot — split panes" },
  },
  -- macOS only — renders nothing on iOS/Android.
  VOutlineView = {
    { label = ":data", detail = "Array<{ id: string, label: string, children?: OutlineNode[] }> (required)" },
    { label = ":expandAll", detail = "boolean (default: false)" },
    { label = "selectionMode", detail = "'single' | 'multiple' | 'none' (default: 'single')" },
    { label = ":style", detail = "ViewStyle" },
    { label = "@select", detail = "event — { id, label } (macOS only)" },
    { label = "@expand", detail = "event — { id } (macOS only)" },
    { label = "@collapse", detail = "event — { id } (macOS only)" },
  },
  VDrawer = {
    { label = "v-model:open", detail = "boolean — two-way drawer open state" },
    { label = ":open", detail = "boolean (default: false)" },
    { label = "position", detail = "'left' | 'right' (default: 'left')" },
    { label = ":width", detail = "number — drawer width in points (default: 280)" },
    { label = "overlayColor", detail = "string — backdrop color (default: 'rgba(0, 0, 0, 0.5)')" },
    { label = ":closeOnPress", detail = "boolean — close when an item is pressed (default: true)" },
    { label = ":closeOnPressOutside", detail = "boolean — close on backdrop press (default: true)" },
    { label = "@open", detail = "event — drawer opened" },
    { label = "@close", detail = "event — drawer closed" },
    { label = "@update:open", detail = "event — v-model:open update" },
    { label = "#header", detail = "slot — drawer header" },
    { label = "#default", detail = "slot — { close } scoped slot" },
    { label = "#footer", detail = "slot — drawer footer" },
  },
  VDrawerItem = {
    { label = "label", detail = "string — item text (required)" },
    { label = "icon", detail = "string — emoji or icon name" },
    { label = ":active", detail = "boolean — marks the current destination (default: false)" },
    { label = ":badge", detail = "number | string — badge count (default: null)" },
    { label = ":disabled", detail = "boolean (default: false)" },
    { label = "@press", detail = "event — item pressed" },
  },
  VDrawerSection = {
    { label = "title", detail = "string — uppercase section heading" },
    { label = "#default", detail = "slot — section items (VDrawerItem)" },
  },
  VTransition = {
    { label = ":show", detail = "boolean — toggle enter/leave (default: true)" },
    { label = "name", detail = "string — preset name, e.g. 'slide'" },
    { label = ":appear", detail = "boolean — animate on initial render (default: false)" },
    { label = ":persist", detail = "boolean — keep the element instead of removing it (default: false)" },
    { label = "mode", detail = "'in-out' | 'out-in' | 'default'" },
    { label = ":css", detail = "boolean (default: true)" },
    { label = "type", detail = "'transition' | 'animation' (default: 'transition')" },
    { label = ":duration", detail = "number | { enter, leave, appear? } — ms (default: 300)" },
    { label = ":enterFrom", detail = "object — style applied before entering" },
    { label = ":enterTo", detail = "object — style applied after entering" },
    { label = ":leaveFrom", detail = "object — style applied before leaving" },
    { label = ":leaveTo", detail = "object — style applied after leaving" },
    { label = "easing", detail = "EasingType (default: 'ease')" },
    { label = "#default", detail = "slot — single child to animate" },
  },
  VTransitionGroup = {
    { label = "tag", detail = "string — wrapper element (defaults to VView)" },
    { label = "name", detail = "string (default: 'v')" },
    { label = ":appear", detail = "boolean (default: false)" },
    { label = ":persist", detail = "boolean (default: false)" },
    { label = "moveClass", detail = "string" },
    { label = ":duration", detail = "number — ms (default: 300)" },
    { label = "#default", detail = "slot — keyed children" },
  },
  -- Re-export of @vue/runtime-core KeepAlive.
  KeepAlive = {
    { label = ":include", detail = "MatchPattern — component names to cache" },
    { label = ":exclude", detail = "MatchPattern — component names never to cache" },
    { label = ":max", detail = "number | string — max cached instances" },
    { label = "#default", detail = "slot — single child component" },
  },
  VNavigationBar = {
    { label = "title", detail = "string — navigation title" },
    { label = ":showBack", detail = "boolean — show back button" },
    { label = "@back", detail = "event — back button pressed" },
  },
  VTabBar = {
    { label = "v-model", detail = "string — active tab name" },
    { label = ":tabs", detail = "Array<{ name, label, icon }>" },
  },
  RouterView = {},
}

-- Composable names with descriptions
local composables = {
  { label = "useHaptics", detail = "Haptic feedback — impact, notification, selection" },
  { label = "useAsyncStorage", detail = "Persistent key-value storage" },
  { label = "useClipboard", detail = "Read/write system clipboard" },
  { label = "useDeviceInfo", detail = "Device platform, model, OS version, screen size" },
  { label = "useKeyboard", detail = "Keyboard visibility, height, dismiss" },
  { label = "useAnimation", detail = "Animated values with timing/spring transitions" },
  { label = "useNetwork", detail = "Network connectivity state" },
  { label = "useAppState", detail = "App foreground/background state" },
  { label = "useLinking", detail = "Open URLs and deep links" },
  { label = "useShare", detail = "Native share sheet" },
  { label = "usePermissions", detail = "Check and request system permissions" },
  { label = "useGeolocation", detail = "Device GPS location" },
  { label = "useCamera", detail = "Camera and photo picker" },
  { label = "useNotifications", detail = "Local and push notifications" },
  { label = "useBiometry", detail = "Face ID / Touch ID / fingerprint" },
  { label = "useHttp", detail = "HTTP client (fetch wrapper)" },
  { label = "useColorScheme", detail = "Detect light/dark mode" },
  { label = "useBackHandler", detail = "Intercept Android back button" },
  { label = "useSecureStorage", detail = "Encrypted keychain/keystore storage" },
  { label = "useWebSocket", detail = "WebSocket connection" },
  { label = "usePlatform", detail = "Detect current platform (iOS/Android)" },
  { label = "useDimensions", detail = "Screen dimensions and scale" },
  { label = "useFileSystem", detail = "File system operations" },
  -- `useSensors` is not an export; the module is composables/useSensors.ts but it
  -- exports useAccelerometer and useGyroscope.
  { label = "useAccelerometer", detail = "Accelerometer — x, y, z, isAvailable, start, stop" },
  { label = "useGyroscope", detail = "Gyroscope — x, y, z, isAvailable, start, stop" },
  { label = "useAccessibility", detail = "Screen-reader — announce, setFocus" },
  { label = "useBattery", detail = "Battery state — level, isCharging, isSupported, refresh" },
  { label = "useCalendar", detail = "Calendar — requestAccess, getEvents, createEvent, deleteEvent, getCalendars, hasAccess, error" },
  { label = "useContacts", detail = "Contacts — requestAccess, getContacts, getContact, createContact, deleteContact, hasAccess, error" },
  { label = "useDragDrop", detail = "Drag & drop — enableDropZone, onDrop, onDragEnter, onDragLeave, isDragging" },
  { label = "useFileDialog", detail = "Native file dialogs — openFile, openDirectory, saveFile" },
  { label = "useGesture", detail = "Gestures — pan, pinch, rotate, swipeLeft/Right/Up/Down, press, longPress, doubleTap, forceTouch, hover, gestureState, activeGesture, isGesturing, attach, detach, on" },
  { label = "useComposedGestures", detail = "Simultaneous gestures — pan, pinch, rotate, gestureState, activeGesture, isGesturing, isPinchingAndRotating, isPanningAndPinching" },
  { label = "useImagePicker", detail = "Photo library picker — pickImage" },
  { label = "useInspector", detail = "Native view-tree inspector — dumpTree" },
  { label = "useMenu", detail = "Native menus (macOS) — setAppMenu, showContextMenu, onMenuItemClick" },
  { label = "useTeleport", detail = "Reparent a native view — teleport" },
  { label = "useWindow", detail = "Window control (macOS) — setTitle, setSize, center, minimize, toggleFullScreen, close, getInfo" },
  { label = "useAudio", detail = "Audio playback and recording" },
  { label = "useDatabase", detail = "SQLite database operations" },
  { label = "useI18n", detail = "Internationalization" },
  { label = "useAppleSignIn", detail = "Sign in with Apple" },
  { label = "useGoogleSignIn", detail = "Sign in with Google" },
  { label = "useIAP", detail = "In-App Purchases" },
  { label = "useBluetooth", detail = "Bluetooth Low Energy (BLE)" },
  { label = "useBackgroundTask", detail = "Background task scheduling" },
  { label = "useOTAUpdate", detail = "Over-the-air updates" },
  { label = "usePerformance", detail = "Performance profiling" },
  { label = "useSharedElementTransition", detail = "Shared element transitions" },
  { label = "useRouter", detail = "Access navigation router" },
  { label = "useRoute", detail = "Access current route params" },
}

-- All component names
local component_names = {}
for name, _ in pairs(component_props) do
  table.insert(component_names, name)
end
table.sort(component_names)

local source = {}

--- Find the component tag the cursor sits inside when that tag was opened on an
--- earlier line (multi-line tags, e.g. the vn-list / vn-sectionlist snippets).
--- Walks backwards from the cursor row and stops at the first line containing
--- ">", which means the previous tag already closed. Returns nil when no
--- enclosing tag can be established, so callers fall back to no completions.
---@param bufnr number|nil
---@param row0 number 0-based cursor row
---@return string|nil
local function find_enclosing_component(bufnr, row0)
  if not bufnr or bufnr == 0 then
    return nil
  end
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, bufnr, math.max(0, row0 - 20), row0, false)
  if not ok or type(lines) ~= "table" then
    return nil
  end
  for idx = #lines, 1, -1 do
    local text = lines[idx]
    if text:find(">", 1, true) then
      return nil
    end
    local tag = text:match("^%s*<([A-Z]%w*)")
    if tag then
      return tag
    end
  end
  return nil
end

source.new = function()
  return setmetatable({}, { __index = source })
end

source.get_trigger_characters = function()
  return { "<", ":", "@", "V", "u" }
end

source.get_keyword_pattern = function()
  return [[\k\+]]
end

function source:is_available()
  local ft = vim.bo.filetype
  return ft == "vue" or ft == "typescript" or ft == "javascript"
end

function source:get_debug_name()
  return "vue_native"
end

function source:complete(params, callback)
  local items = {}
  local line = params.context.cursor_before_line or ""

  -- Component name completion: typing <V... (or <KeepAlive / <RouterView) in a
  -- template. [A-Z] keeps lowercase HTML-ish tags (<template>, <script>) out.
  if line:match("<[A-Z]%w*$") or line:match("^%s*[A-Z]%w*$") then
    for _, name in ipairs(component_names) do
      table.insert(items, {
        label = name,
        kind = 10, -- Struct
        detail = "Vue Native component",
        documentation = {
          kind = "markdown",
          value = "**" .. name .. "** — Vue Native component\n\nUsage: `<" .. name .. " />`",
        },
      })
    end
  end

  -- Prop completion: inside a component's opening tag. The tag may be on the
  -- cursor line, or opened on an earlier line when the tag spans lines.
  local component = line:match("<([A-Z]%w*)")
    or find_enclosing_component(params.context.bufnr, (params.context.row or 1) - 1)
  if component and component_props[component] then
    for _, prop in ipairs(component_props[component]) do
      table.insert(items, {
        label = prop.label,
        kind = 5, -- Field
        detail = prop.detail,
        documentation = {
          kind = "markdown",
          value = "**" .. prop.label .. "**\n\n" .. prop.detail,
        },
      })
    end
  end

  -- Composable completion: typing use... in script
  if line:match("use%w*$") then
    for _, comp in ipairs(composables) do
      table.insert(items, {
        label = comp.label,
        kind = 3, -- Function
        detail = comp.detail,
        documentation = {
          kind = "markdown",
          value = "**" .. comp.label .. "()**\n\n" .. comp.detail .. "\n\n```typescript\nconst { ... } = " .. comp.label .. "()\n```",
        },
      })
    end
  end

  callback({ items = items, isIncomplete = false })
end

function M.setup()
  local ok, cmp = pcall(require, "cmp")
  if not ok then
    return
  end

  cmp.register_source("vue_native", source.new())
end

return M
