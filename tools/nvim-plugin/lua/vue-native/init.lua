-- vue-native.nvim — Neovim plugin for Vue Native development
-- Provides snippets, completions, and diagnostics for .vue files

local M = {}

M.config = {
  snippets = true,
  completions = true,
  diagnostics = true,
}

--- Setup the Vue Native plugin
---@param opts? table Configuration options
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  if M.config.snippets then
    local ok, snippets = pcall(require, "vue-native.snippets")
    if ok then
      snippets.setup()
    end
  end

  if M.config.completions then
    local ok, completions = pcall(require, "vue-native.completions")
    if ok then
      completions.setup()
    end
  end

  if M.config.diagnostics then
    local ok, diagnostics = pcall(require, "vue-native.diagnostics")
    if ok then
      diagnostics.setup()
    end
  end
end

return M
