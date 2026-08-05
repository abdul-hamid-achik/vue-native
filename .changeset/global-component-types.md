---
"@thelacanians/vue-native-runtime": patch
---

Fix editor/LSP support for Vue Native components in `.vue` templates:

- The runtime now augments `@vue/runtime-core`'s `GlobalComponents` interface with every built-in component (`VView`, `VText`, `VButton`, ...). Language servers (Volar, vue-tsc, ts-ls integrations in VS Code and Neovim) now resolve the globally registered components: template autocomplete, prop typing, and unknown-component errors work out of the box in scaffolded projects.
- `createStyleSheet()` now uses a `const` type parameter, so style literals keep their literal types (`justifyContent: 'center'` instead of `string`) and are checked against the style unions.
