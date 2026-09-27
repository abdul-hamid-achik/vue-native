" vue-native.vim — auto-load entry point for non-lazy setups
" For lazy.nvim users, use require('vue-native').setup() instead.

if exists('g:loaded_vue_native')
  finish
endif
let g:loaded_vue_native = 1

" A native pack/ install sources this file and has no other hook, so configure
" the plugin here. Deferred to VimEnter and skipped once setup() has run, so a
" plugin manager's own `config = function() require('vue-native').setup(opts) end`
" still wins.
augroup VueNativeAutoSetup
  autocmd!
  autocmd VimEnter * lua local ok, vn = pcall(require, 'vue-native'); if ok and not vn.did_setup then vn.setup() end
augroup END
