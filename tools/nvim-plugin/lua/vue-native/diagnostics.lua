-- vue-native/diagnostics.lua — Custom diagnostics for Vue Native
-- Warns on common mistakes using vim.diagnostic API

local M = {}

local ns = vim.api.nvim_create_namespace("vue_native_diagnostics")

local rules = {
  {
    pattern = "app%.mount%s*%(",
    message = "Vue Native uses app.start() instead of app.mount(). There is no DOM to mount to.",
    severity = vim.diagnostic.severity.ERROR,
  },
  {
    pattern = "@press[%s=]",
    message = 'Vue Native buttons use :onPress (prop binding), not @press (event). Use :onPress="handler".',
    severity = vim.diagnostic.severity.WARN,
  },
  {
    pattern = "v%-for%s+.-%s+in%s+",
    -- Only warn if inside a VList context (heuristic: same file has <VList)
    check_context = "VList",
    message = "VList uses :data and #item slot for rendering. Use v-for only inside VScrollView, not VList.",
    severity = vim.diagnostic.severity.WARN,
  },
  {
    pattern = 'import%s+.-%s+from%s+["\']vue["\']',
    message = 'In Vue Native, import from "@thelacanians/vue-native-runtime" instead of "vue". The Vite plugin aliases "vue" automatically, but explicit imports are clearer.',
    severity = vim.diagnostic.severity.HINT,
  },
}

local function update_diagnostics(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ft = vim.bo[bufnr].filetype
  if ft ~= "vue" and ft ~= "typescript" and ft ~= "javascript" then
    vim.diagnostic.set(ns, bufnr, {})
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local full_text = table.concat(lines, "\n")
  local diagnostics = {}

  for _, rule in ipairs(rules) do
    -- Skip context-dependent rules if context not found
    if rule.check_context and not full_text:find(rule.check_context, 1, true) then
      goto continue
    end

    for lnum, line in ipairs(lines) do
      local col_start, col_end = line:find(rule.pattern)
      if col_start then
        table.insert(diagnostics, {
          lnum = lnum - 1, -- 0-indexed
          col = col_start - 1, -- 0-indexed
          end_lnum = lnum - 1,
          end_col = col_end,
          message = rule.message,
          severity = rule.severity,
          source = "Vue Native",
        })
      end
    end

    ::continue::
  end

  vim.diagnostic.set(ns, bufnr, diagnostics)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("VueNativeDiagnostics", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "InsertLeave" }, {
    group = group,
    pattern = { "*.vue", "*.ts", "*.js" },
    callback = function(args)
      update_diagnostics(args.buf)
    end,
  })

  -- Run on any currently open vue buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("%.vue$") or name:match("%.ts$") then
        update_diagnostics(bufnr)
      end
    end
  end
end

return M
