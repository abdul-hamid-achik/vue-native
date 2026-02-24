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
  VButton = {
    { label = ":style", detail = "ViewStyle — button container style" },
    { label = ":onPress", detail = "() => void — press handler" },
    { label = ":onLongPress", detail = "() => void — long press handler" },
    { label = ":disabled", detail = "boolean — disable interactions (default: false)" },
    { label = ":activeOpacity", detail = "number — opacity when pressed (default: 0.7)" },
    { label = "accessibilityLabel", detail = "string" },
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
    { label = ":estimatedItemHeight", detail = "number — estimated row height (default: 44)" },
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
  VSlider = {
    { label = "v-model", detail = "number — current value" },
    { label = ":minimumValue", detail = "number (default: 0)" },
    { label = ":maximumValue", detail = "number (default: 1)" },
    { label = "minimumTrackTintColor", detail = "string — filled track color" },
    { label = ":style", detail = "ViewStyle" },
    { label = "@change", detail = "event — value changed" },
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
  VProgressBar = {
    { label = ":progress", detail = "number — 0.0 to 1.0" },
    { label = "trackColor", detail = "string — background track color" },
    { label = "progressColor", detail = "string — fill color" },
  },
  VPicker = {
    { label = "v-model", detail = "string — selected value" },
    { label = ":items", detail = "string[] — picker options" },
  },
  VSegmentedControl = {
    { label = "v-model", detail = "number — selected index" },
    { label = ":values", detail = "string[] — segment labels" },
  },
  VKeyboardAvoiding = {
    { label = ":style", detail = "ViewStyle" },
    { label = "behavior", detail = "'padding' | 'height'" },
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
  VSectionList = {
    { label = ":sections", detail = "Array<{ title, data }>" },
    { label = ":renderItem", detail = "(item) => VNode" },
    { label = ":renderSectionHeader", detail = "(section) => VNode" },
    { label = ":keyExtractor", detail = "(item) => string" },
  },
  VVideo = {
    { label = ":source", detail = "{ uri: string }" },
    { label = ":style", detail = "ViewStyle" },
    { label = ":controls", detail = "boolean — show playback controls" },
  },
  VErrorBoundary = {
    { label = ":fallback", detail = "Component — error fallback component" },
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
  { label = "useSensors", detail = "Accelerometer and gyroscope data" },
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

  -- Component name completion: typing <V... in template
  if line:match("<V%w*$") or line:match("^%s*V%w*$") then
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

  -- Prop completion: typing after <VComponentName ...
  local component = line:match("<(V%w+)%s")
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
