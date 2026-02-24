# Neovim Plugin

Vue Native provides an official Neovim plugin with LuaSnip snippets, nvim-cmp completions, and custom diagnostics for `.vue` and `.ts` files.

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
    'L3MON4D3/LuaSnip',
    'hrsh7th/nvim-cmp',
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

```bash
git clone https://github.com/thelacanians/vue-native \
  ~/.config/nvim/pack/plugins/start/vue-native
```

Then add to your `init.lua`:

```lua
require('vue-native').setup()
```

## Configuration

```lua
require('vue-native').setup({
  snippets = true,       -- LuaSnip snippets (default: true)
  completions = true,    -- nvim-cmp source (default: true)
  diagnostics = true,    -- vim.diagnostic warnings (default: true)
})
```

## Features

### Snippets

Over 70 LuaSnip snippets for components, composables, navigation, and scaffolds. All prefixed with `vn-`.

Type a prefix and press your LuaSnip expand key (usually `<Tab>`) to expand. Use `<Tab>` and `<S-Tab>` to jump between tabstops. Choice nodes (marked with `c()`) can be cycled with your configured LuaSnip choice key.

**Scaffold snippets:**

| Prefix | Output |
|--------|--------|
| `vn-app` | Full app scaffold with SafeArea, styles, and script setup |
| `vn-screen` | Screen component with useRoute and createStyleSheet |
| `vn-main` | main.ts entry point with createApp, createRouter, and start() |
| `vn-config` | vue-native.config.ts with iOS and Android configuration |

**Component snippets:**

| Prefix | Component |
|--------|-----------|
| `vn-view` | VView |
| `vn-text` | VText |
| `vn-button` | VButton with onPress |
| `vn-input` | VInput with v-model |
| `vn-image` | VImage with source and resizeMode |
| `vn-scrollview` | VScrollView |
| `vn-list` | VList with data and renderItem |
| `vn-safearea` | VSafeArea |
| `vn-switch` | VSwitch |
| `vn-slider` | VSlider |
| `vn-modal` | VModal |
| `vn-alert` | VAlertDialog |
| `vn-actionsheet` | VActionSheet |
| `vn-webview` | VWebView |
| `vn-checkbox` | VCheckbox |
| `vn-radio` | VRadio |
| `vn-dropdown` | VDropdown |
| `vn-video` | VVideo |

**Composable snippets:**

| Prefix | Composable |
|--------|------------|
| `vn-haptics` | useHaptics |
| `vn-storage` | useAsyncStorage |
| `vn-clipboard` | useClipboard |
| `vn-animation` | useAnimation |
| `vn-http` | useHttp |
| `vn-camera` | useCamera |
| `vn-websocket` | useWebSocket |
| `vn-database` | useDatabase |

See the full list in the [plugin README](https://github.com/thelacanians/vue-native/tree/main/tools/nvim-plugin).

### Completions

The plugin registers a custom `vue_native` source for [nvim-cmp](https://github.com/hrsh7th/nvim-cmp). Add it to your cmp sources:

```lua
require('cmp').setup({
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'vue_native' },
  },
})
```

The completion source provides:

- **Component names** when typing `<V` in a template section
- **Component props** when typing after a component tag (e.g., `<VButton `)
- **Composable names** when typing `use` in a script section

Each completion item includes documentation with type information and usage examples.

### Diagnostics

The plugin uses `vim.diagnostic` to show real-time warnings for common Vue Native mistakes:

| Pattern | Severity | Message |
|---------|----------|---------|
| `app.mount()` | Error | Use `app.start()` instead |
| `@press` | Warning | Use `:onPress` prop binding |
| `v-for` in VList | Warning | Use `:data` and `#item` slot |
| `import from 'vue'` | Hint | Import from `@thelacanians/vue-native-runtime` |

Diagnostics appear inline and in the diagnostics list (`:lua vim.diagnostic.setloclist()`).

## Requirements

- Neovim 0.8+
- [LuaSnip](https://github.com/L3MON4D3/LuaSnip) — for snippet expansion
- [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) — for completion menu
- [Volar](https://github.com/vuejs/language-tools) — recommended for Vue LSP support

## Related

- [VS Code Extension](./vscode.md) — snippets and diagnostics for VS Code
