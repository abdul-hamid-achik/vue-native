# Vue Native Snippets for VS Code

Snippets and diagnostics for [Vue Native](https://github.com/abdul-hamid-achik/vue-native) — build native iOS and Android apps with Vue 3.

## Features

### Snippets

Over 70 snippets covering all Vue Native components, composables, and patterns. All prefixed with `vn-`.

**Scaffolds:**
| Prefix | Description |
|--------|-------------|
| `vn-app` | Full app scaffold with SafeArea, styles |
| `vn-screen` | Screen component with route access |
| `vn-main` | main.ts entry point with router |
| `vn-config` | vue-native.config.ts configuration |

**Components:**
| Prefix | Description |
|--------|-------------|
| `vn-view` | VView container |
| `vn-text` | VText label |
| `vn-button` | VButton with onPress |
| `vn-input` | VInput with v-model |
| `vn-image` | VImage with source |
| `vn-scrollview` | VScrollView |
| `vn-list` | VList (virtualized) |
| `vn-safearea` | VSafeArea |
| `vn-switch` | VSwitch toggle |
| `vn-slider` | VSlider range |
| `vn-activity` | VActivityIndicator |
| `vn-modal` | VModal overlay |
| `vn-alert` | VAlertDialog |
| `vn-actionsheet` | VActionSheet |
| `vn-statusbar` | VStatusBar |
| `vn-webview` | VWebView |
| `vn-progress` | VProgressBar |
| `vn-picker` | VPicker |
| `vn-segmented` | VSegmentedControl |
| `vn-keyboard` | VKeyboardAvoiding |
| `vn-refresh` | VRefreshControl |
| `vn-pressable` | VPressable |
| `vn-checkbox` | VCheckbox |
| `vn-radio` | VRadio group |
| `vn-dropdown` | VDropdown |
| `vn-sectionlist` | VSectionList |
| `vn-video` | VVideo player |
| `vn-errorboundary` | VErrorBoundary |

**Navigation:**
| Prefix | Description |
|--------|-------------|
| `vn-routerview` | RouterView |
| `vn-navbar` | VNavigationBar |
| `vn-tabbar` | VTabBar |
| `vn-router` | createRouter setup |
| `vn-router-options` | createRouter with deep linking |
| `vn-tabs` | createTabNavigator |
| `vn-drawer` | createDrawerNavigator |
| `vn-userouter` | useRouter composable |
| `vn-useroute` | useRoute composable |
| `vn-onfocus` | onScreenFocus lifecycle |
| `vn-onblur` | onScreenBlur lifecycle |

**Composables:**
| Prefix | Description |
|--------|-------------|
| `vn-haptics` | useHaptics |
| `vn-storage` | useAsyncStorage |
| `vn-clipboard` | useClipboard |
| `vn-deviceinfo` | useDeviceInfo |
| `vn-usekeyboard` | useKeyboard |
| `vn-animation` | useAnimation |
| `vn-network` | useNetwork |
| `vn-appstate` | useAppState |
| `vn-linking` | useLinking |
| `vn-share` | useShare |
| `vn-permissions` | usePermissions |
| `vn-geolocation` | useGeolocation |
| `vn-camera` | useCamera |
| `vn-notifications` | useNotifications |
| `vn-biometry` | useBiometry |
| `vn-http` | useHttp |
| `vn-colorscheme` | useColorScheme |
| `vn-backhandler` | useBackHandler |
| `vn-securestorage` | useSecureStorage |
| `vn-websocket` | useWebSocket |
| `vn-platform` | usePlatform |
| `vn-dimensions` | useDimensions |
| `vn-filesystem` | useFileSystem |
| `vn-accelerometer` | useAccelerometer |
| `vn-gyroscope` | useGyroscope |
| `vn-audio` | useAudio |
| `vn-database` | useDatabase |
| `vn-i18n` | useI18n |

**Layout Helpers:**
| Prefix | Description |
|--------|-------------|
| `vn-row` | Horizontal flex row |
| `vn-column` | Vertical flex column |
| `vn-center` | Centered container |
| `vn-styles` | createStyleSheet |
| `vn-vshow` | v-show directive |

### Diagnostics

The extension provides real-time warnings for common Vue Native mistakes:

- **`app.mount()` usage** -- Vue Native uses `app.start()`, not `app.mount()`.
- **`@press` event** -- Vue Native buttons use `:onPress` (prop binding), not `@press`.
- **Import hints** -- Suggests using `@thelacanians/vue-native-runtime` imports.

## Installation

### From VSIX (local)

```bash
cd tools/vscode-extension
bun install
bun run build
npx @vscode/vsce package
code --install-extension vue-native-snippets-0.1.0.vsix
```

### Development

```bash
cd tools/vscode-extension
bun install
bun run dev
```

Then press F5 in VS Code to launch the Extension Development Host.

## Requirements

- VS Code 1.85+
- Vue Language Features (Volar) extension recommended
