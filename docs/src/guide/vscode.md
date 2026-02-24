# VS Code Extension

Vue Native provides a VS Code extension with snippets, diagnostics, and tooling for a productive development experience.

## Installation

### From Source

```bash
cd tools/vscode-extension
bun install
bun run build
npx @vscode/vsce package
code --install-extension vue-native-snippets-0.1.0.vsix
```

### Marketplace

The extension will be published to the VS Code Marketplace as `vue-native-snippets`. Check the [GitHub releases](https://github.com/abdul-hamid-achik/vue-native/releases) for the latest `.vsix` file.

## Snippets

All snippets use the `vn-` prefix. Type `vn-` in a `.vue` file to see all available snippets.

### Scaffolds

| Prefix | Description |
|--------|-------------|
| `vn-app` | Full app with SafeArea and styles |
| `vn-screen` | Screen component with route |
| `vn-main` | main.ts entry with router |
| `vn-config` | vue-native.config.ts |
| `vn-styles` | createStyleSheet block |

### Components

| Prefix | Component |
|--------|-----------|
| `vn-view` | VView |
| `vn-text` | VText |
| `vn-button` | VButton |
| `vn-input` | VInput |
| `vn-image` | VImage |
| `vn-scrollview` | VScrollView |
| `vn-list` | VList |
| `vn-safearea` | VSafeArea |
| `vn-switch` | VSwitch |
| `vn-slider` | VSlider |
| `vn-activity` | VActivityIndicator |
| `vn-modal` | VModal |
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
| `vn-radio` | VRadio |
| `vn-dropdown` | VDropdown |
| `vn-sectionlist` | VSectionList |
| `vn-video` | VVideo |
| `vn-errorboundary` | VErrorBoundary |

### Navigation

| Prefix | Description |
|--------|-------------|
| `vn-routerview` | RouterView |
| `vn-navbar` | VNavigationBar |
| `vn-tabbar` | VTabBar |
| `vn-router` | createRouter |
| `vn-router-options` | createRouter with linking |
| `vn-tabs` | createTabNavigator |
| `vn-drawer` | createDrawerNavigator |
| `vn-userouter` | useRouter |
| `vn-useroute` | useRoute |
| `vn-onfocus` | onScreenFocus |
| `vn-onblur` | onScreenBlur |

### Composables

| Prefix | Composable |
|--------|------------|
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

### Layout Helpers

| Prefix | Description |
|--------|-------------|
| `vn-row` | Horizontal flex row |
| `vn-column` | Vertical flex column |
| `vn-center` | Centered container |

## Diagnostics

The extension highlights common mistakes in `.vue` files:

- **`app.mount()`** -- Vue Native uses `app.start()`, not `app.mount()`. There is no DOM.
- **`@press`** -- Buttons use `:onPress` (prop binding), not `@press` (event listener).
- **Import hints** -- Suggests using `@thelacanians/vue-native-runtime` for explicit imports.

## Recommended Extensions

For the best Vue Native development experience, install these companion extensions:

- [Vue - Official](https://marketplace.visualstudio.com/items?itemName=Vue.volar) (Volar) -- Vue 3 language support
- [TypeScript Vue Plugin](https://marketplace.visualstudio.com/items?itemName=Vue.vscode-typescript-vue-plugin) -- TypeScript in `.vue` files
