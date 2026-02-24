# Vue Native for Neovim

Snippets, completions, and diagnostics for [Vue Native](https://github.com/abdul-hamid-achik/vue-native) development in Neovim.

## Features

### Snippets (LuaSnip)

Over 70 LuaSnip snippets covering all Vue Native components, composables, and patterns. All prefixed with `vn-`.

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
| `vn-list-template` | VList with external renderItem |
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

### Completions (nvim-cmp)

Registers a custom `vue_native` source for nvim-cmp:

- **Component names** — type `<V` in a template to see all Vue Native components
- **Component props** — type a space after `<VButton ` to see available props with types
- **Composable names** — type `use` in a script block to see all composables with descriptions

### Diagnostics

Real-time warnings for common Vue Native mistakes via `vim.diagnostic`:

- **`app.mount()` usage** — Vue Native uses `app.start()`, not `app.mount()`
- **`@press` event** — Vue Native buttons use `:onPress` (prop binding), not `@press`
- **`v-for` in VList** — VList uses `:data` and `#item` slot, not `v-for`
- **Import hints** — suggests `@thelacanians/vue-native-runtime` over bare `vue`

## Installation

### lazy.nvim (recommended)

```lua
{
  'thelacanians/vue-native',
  config = function()
    require('vue-native').setup()
  end,
  ft = { 'vue', 'typescript' },
  dependencies = {
    'L3MON4D3/LuaSnip',    -- for snippets
    'hrsh7th/nvim-cmp',     -- for completions
  },
}
```

### packer.nvim

```lua
use {
  'thelacanians/vue-native',
  config = function()
    require('vue-native').setup()
  end,
  ft = { 'vue', 'typescript' },
  requires = {
    'L3MON4D3/LuaSnip',
    'hrsh7th/nvim-cmp',
  },
}
```

### Manual

Clone to your Neovim packages directory:

```bash
git clone https://github.com/thelacanians/vue-native \
  ~/.config/nvim/pack/plugins/start/vue-native
```

Then add to your init.lua:

```lua
require('vue-native').setup()
```

### Adding the nvim-cmp source

After installing, add `vue_native` to your nvim-cmp sources:

```lua
require('cmp').setup({
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'vue_native' },  -- add this line
  },
})
```

## Configuration

All features are enabled by default. Disable specific features:

```lua
require('vue-native').setup({
  snippets = true,       -- LuaSnip snippets (default: true)
  completions = true,    -- nvim-cmp source (default: true)
  diagnostics = true,    -- vim.diagnostic warnings (default: true)
})
```

## Requirements

- Neovim 0.8+
- [LuaSnip](https://github.com/L3MON4D3/LuaSnip) (for snippets)
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (for completions)
- Vue language server (Volar) recommended for full LSP support
