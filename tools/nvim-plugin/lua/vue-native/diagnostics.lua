-- vue-native/diagnostics.lua — Custom diagnostics for Vue Native
-- Warns on common mistakes using the vim.diagnostic API.
--
-- The matching core (M.collect) is pure: it takes a list of buffer lines and
-- returns vim.diagnostic-shaped tables. It deliberately does not touch `vim` so
-- it can be exercised under a plain Lua interpreter — see tests/diagnostics_spec.lua.

local M = {}

-- vim.diagnostic.severity values are ERROR=1, WARN=2, INFO=3, HINT=4. Fall back
-- to those literals so this module also loads outside Neovim (for tests).
local SEVERITY = (vim and vim.diagnostic and vim.diagnostic.severity)
  or { ERROR = 1, WARN = 2, INFO = 3, HINT = 4 }

local namespace_id = nil

local function get_namespace()
  if not namespace_id then
    namespace_id = vim.api.nvim_create_namespace("vue_native_diagnostics")
  end
  return namespace_id
end

-- ─── Rules ───────────────────────────────────────────────────────────────────
--
-- Patterns are applied to the WHOLE buffer (lines joined with "\n"), not to
-- individual lines, so an attribute value that spans lines still matches.
-- Patterns that must stay on one line use [^\n] explicitly.
--
--   patterns        list of Lua patterns, each tried in order
--   scope_tag       optional component name. When set, only matches that fall
--                   inside a <scope_tag> element are reported.
--   scope_severity  severity for a match inside the element's OPENING TAG
--                   (unambiguously wrong). `severity` is used for a match
--                   elsewhere inside the element body (probably wrong).

local rules = {
  {
    id = "app-mount",
    patterns = { "app%.mount[ \t]*%(" },
    message = "Vue Native uses app.start() instead of app.mount(). There is no DOM to mount to.",
    severity = SEVERITY.ERROR,
  },
  {
    id = "vlist-v-for",
    patterns = {
      -- `v-for="item in items"` / `v-for="(item, i) in items"`
      'v%-for%s*=%s*["\'][^"\']-%s+in%s+[^"\']*',
      -- `v-for="item of items"`
      'v%-for%s*=%s*["\'][^"\']-%s+of%s+[^"\']*',
    },
    scope_tag = "VList",
    message = "VList takes :data and renders rows from its #item slot — a v-for here is ignored. Use v-for inside a plain container such as VScrollView, or switch to VFlatList's :renderItem.",
    scope_severity = SEVERITY.WARN,
    severity = SEVERITY.HINT,
  },
  {
    id = "vue-import",
    patterns = { 'import[ \t]+[^\n]-from[ \t]*["\']vue["\']' },
    message = 'In Vue Native, import from "@thelacanians/vue-native-runtime" instead of "vue". The Vite plugin aliases "vue" automatically, but explicit imports are clearer.',
    severity = SEVERITY.HINT,
  },
}

-- ─── Text helpers ────────────────────────────────────────────────────────────

--- Byte offset of each line (1-based) in `table.concat(lines, "\n")`.
local function build_line_index(lines)
  local starts = {}
  local offset = 1
  for idx = 1, #lines do
    starts[idx] = offset
    offset = offset + #lines[idx] + 1 -- +1 for the joining "\n"
  end
  return starts
end

--- Convert a 1-based byte offset into 0-based (lnum, col).
--- Neovim diagnostics use 0-based positions and an EXCLUSIVE end column, so the
--- caller passes `match_end + 1` to get `end_col`.
local function offset_to_position(starts, offset)
  local lo, hi = 1, #starts
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if starts[mid] <= offset then
      lo = mid
    else
      hi = mid - 1
    end
  end
  return lo - 1, offset - starts[lo]
end

--- Locate every `<tag ...> ... </tag>` element, returning byte ranges.
--- Each range records `s` (start of `<tag`), `open_end` (the `>` that closes the
--- opening tag) and `e` (end of `</tag>`, or end of text when unterminated).
--- Quoted attribute values are skipped so a `>` inside a string cannot end the tag.
local function element_ranges(text, tag)
  local ranges = {}
  local open_pattern = "<" .. tag .. "[\r\n\t >/]"
  local close_pattern = "</" .. tag .. "%s*>"
  local from = 1

  while true do
    local tag_start = text:find(open_pattern, from)
    if not tag_start then
      break
    end

    local cursor = tag_start + 1
    local quote = nil
    local open_end = nil
    while cursor <= #text do
      local char = text:sub(cursor, cursor)
      if quote then
        if char == quote then
          quote = nil
        end
      elseif char == '"' or char == "'" then
        quote = char
      elseif char == ">" then
        open_end = cursor
        break
      end
      cursor = cursor + 1
    end
    if not open_end then
      break -- unterminated tag; stop scanning
    end

    local elem_end
    if text:sub(open_end - 1, open_end - 1) == "/" then
      elem_end = open_end -- self-closing
    else
      local _, close_end = text:find(close_pattern, open_end)
      elem_end = close_end or #text
    end

    ranges[#ranges + 1] = { s = tag_start, open_end = open_end, e = elem_end }
    from = elem_end + 1
  end

  return ranges
end

local function containing_range(ranges, offset)
  for _, range in ipairs(ranges) do
    if offset >= range.s and offset <= range.e then
      return range
    end
  end
  return nil
end

-- ─── Pure diagnostic engine ──────────────────────────────────────────────────

--- Run every rule over a buffer's lines.
---@param lines string[] buffer lines without trailing newlines
---@return table[] diagnostics in the shape vim.diagnostic.set expects
function M.collect(lines)
  local text = table.concat(lines, "\n")
  local starts = build_line_index(lines)
  local diagnostics = {}

  for _, rule in ipairs(rules) do
    local ranges
    if rule.scope_tag then
      ranges = element_ranges(text, rule.scope_tag)
      if #ranges == 0 then
        goto continue -- no <VList> in this buffer, so the rule cannot apply
      end
    end

    for _, pattern in ipairs(rule.patterns) do
      local search = 1
      while true do
        local match_start, match_end = text:find(pattern, search)
        if not match_start then
          break
        end

        local severity = rule.severity
        if ranges then
          local range = containing_range(ranges, match_start)
          if not range then
            severity = nil -- outside every scoped element: not a finding
          elseif match_start <= range.open_end then
            severity = rule.scope_severity or rule.severity -- on the tag itself
          end
        end

        if severity then
          local lnum, col = offset_to_position(starts, match_start)
          -- +1 turns the 1-based inclusive end into a 0-based exclusive column.
          local end_lnum, end_col = offset_to_position(starts, match_end + 1)
          diagnostics[#diagnostics + 1] = {
            lnum = lnum,
            col = col,
            end_lnum = end_lnum,
            end_col = end_col,
            message = rule.message,
            severity = severity,
            source = "Vue Native",
          }
        end

        search = match_end + 1
      end
    end

    ::continue::
  end

  table.sort(diagnostics, function(a, b)
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)

  return diagnostics
end

-- ─── Neovim wiring ───────────────────────────────────────────────────────────

local function update_diagnostics(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ft = vim.bo[bufnr].filetype
  if ft ~= "vue" and ft ~= "typescript" and ft ~= "javascript" then
    vim.diagnostic.set(get_namespace(), bufnr, {})
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  vim.diagnostic.set(get_namespace(), bufnr, M.collect(lines))
end

-- Exposed for tests that run inside Neovim.
M._update_diagnostics = update_diagnostics

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
