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
| `vn-list` | VList (virtualized) — rows from the `#item` slot |
| `vn-flatlist` | VFlatList — the list that takes a `renderItem` function |
| `vn-safearea` | VSafeArea |
| `vn-switch` | VSwitch toggle |
| `vn-slider` | VSlider range |
| `vn-activity` | VActivityIndicator |
| `vn-modal` | VModal overlay |
| `vn-alert` | VAlertDialog |
| `vn-actionsheet` | VActionSheet |
| `vn-statusbar` | VStatusBar |
| `vn-webview` | VWebView |
| `vn-progress` | VProgressBar (`trackTintColor` / `progressTintColor`) |
| `vn-picker` | VPicker — native **date/time** picker (`modelValue` is epoch ms) |
| `vn-segmented` | VSegmentedControl (`:selectedIndex` + `@change`; it has no `modelValue`) |
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

- **Component names** — type `<` followed by an uppercase letter in a template to
  see all Vue Native components, including the non-`V` ones (`KeepAlive`,
  `RouterView`)
- **Component props** — inside a component's opening tag (even a multi-line one)
  to see its props, events and slots with types
- **Composable names** — type `use` in a script block to see all composables with
  descriptions

Prop, event and slot lists are kept in sync with
`packages/runtime/src/components/*.ts`. Notable specifics: `VList` and
`VSectionList` render from **slots**, not a `renderItem` prop — `renderItem`
belongs to `VFlatList`. `VSegmentedControl` has no `modelValue`, so `v-model`
silently does nothing; drive it with `:selectedIndex` + `@change`. `VPicker` is a
date/time picker whose `modelValue` is epoch milliseconds; for a list of choices
use `VDropdown`.

### Diagnostics

Real-time warnings for common Vue Native mistakes via `vim.diagnostic`:

- **`app.mount()` usage** (error) — Vue Native uses `app.start()`, not `app.mount()`
- **`v-for` on a `VList`** — VList uses `:data` and the `#item` slot, not `v-for`.
  Scoped to the `<VList>` element itself, so a legitimate `v-for` in a sibling
  `<VScrollView>` is no longer flagged. A `v-for` on the `<VList>` opening tag is
  a warning; one further inside the element is a hint.
- **Import hints** — suggests `@thelacanians/vue-native-runtime` over bare `vue`

Matching runs over the whole buffer, so a `v-for` whose value spans lines is
still caught.

#### Tests

The diagnostic matching core is pure Lua and has no Neovim dependency, so it can
be tested with a stock interpreter — no extra tooling required:

```bash
cd tools/nvim-plugin && lua tests/diagnostics_spec.lua
```

The same file runs under `busted` when it is installed
(`busted tools/nvim-plugin/tests`).

Both `@press="handler"` event listeners and `:onPress="handler"` function bindings
are supported. Snippets continue to use `:onPress`.

## Installation

The plugin lives at `tools/nvim-plugin/` inside the monorepo, not at the repo
root, so a plugin manager cannot resolve it from the repo slug alone. Clone the
repo once, then point your manager at that subdirectory.

```bash
git clone https://github.com/abdul-hamid-achik/vue-native \
  ~/.local/share/vue-native-src
```

### lazy.nvim (recommended)

```lua
{
  dir = vim.fn.expand('~/.local/share/vue-native-src/tools/nvim-plugin'),
  name = 'vue-native',
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
  '~/.local/share/vue-native-src/tools/nvim-plugin',
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

Symlink into Neovim's native package path:

```bash
mkdir -p ~/.config/nvim/pack/plugins/start
ln -s ~/.local/share/vue-native-src/tools/nvim-plugin \
      ~/.config/nvim/pack/plugins/start/vue-native
```

That is the whole install — `plugin/vue-native.vim` calls
`require('vue-native').setup()` on `VimEnter`. Add an `init.lua` line only if you
want to pass options:

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
