-- tests/diagnostics_spec.lua — tests for lua/vue-native/diagnostics.lua
--
-- Runs under a PLAIN Lua interpreter with no extra tooling:
--
--     cd tools/nvim-plugin && lua tests/diagnostics_spec.lua
--
-- It also runs under busted (`busted tools/nvim-plugin/tests`) — when busted's
-- globals are present they are used instead of the built-in runner.
--
-- Only the pure matching core (M.collect) is covered; the vim.diagnostic wiring
-- needs a real Neovim and is not exercised here.

-- ─── Locate the plugin root so `require("vue-native.diagnostics")` works ─────
do
  local function add_root(root)
    if root and root ~= "" then
      package.path = root .. "/lua/?.lua;" .. package.path
    end
  end
  add_root(os.getenv("VUE_NATIVE_NVIM_PLUGIN_ROOT"))
  add_root(((arg and arg[0]) or ""):match("^(.*)[/\\]tests[/\\][^/\\]+$"))
  add_root(".")
  add_root("tools/nvim-plugin")
end

local diagnostics = require("vue-native.diagnostics")

-- ─── Minimal runner (replaced by busted when available) ─────────────────────
local ran, failed = 0, 0
local current_suite = ""

local describe_impl, it_impl
if type(_G.describe) == "function" and type(_G.it) == "function" then
  describe_impl, it_impl = _G.describe, _G.it
else
  describe_impl = function(name, fn)
    current_suite = name
    fn()
    current_suite = ""
  end
  it_impl = function(name, fn)
    ran = ran + 1
    local ok, err = pcall(fn)
    if not ok then
      failed = failed + 1
      io.stderr:write("FAIL  " .. current_suite .. " › " .. name .. "\n      " .. tostring(err) .. "\n")
    end
  end
end

local function fail(fmt, ...)
  error(string.format(fmt, ...), 2)
end

local function assert_eq(actual, expected, what)
  if actual ~= expected then
    fail("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual))
  end
end

local function assert_count(diags, expected, what)
  if #diags ~= expected then
    local detail = {}
    for _, d in ipairs(diags) do
      detail[#detail + 1] = string.format("[%d:%d-%d:%d sev=%d]", d.lnum, d.col, d.end_lnum, d.end_col, d.severity)
    end
    fail("%s: expected %d diagnostic(s), got %d %s", what or "count", expected, #diags, table.concat(detail, " "))
  end
end

local function find_by_id(diags, needle)
  for _, d in ipairs(diags) do
    if d.message:find(needle, 1, true) then
      return d
    end
  end
  return nil
end

--- Assert that a diagnostic's [lnum, col) → [end_lnum, end_col) range slices the
--- buffer back to exactly `expected`. This is what makes the 0-based / exclusive
--- end-column convention verifiable rather than assumed.
local function assert_range(lines, diag, expected)
  local text
  if diag.lnum == diag.end_lnum then
    text = lines[diag.lnum + 1]:sub(diag.col + 1, diag.end_col)
  else
    local parts = { lines[diag.lnum + 1]:sub(diag.col + 1) }
    for lnum = diag.lnum + 2, diag.end_lnum do
      parts[#parts + 1] = lines[lnum]
    end
    parts[#parts + 1] = lines[diag.end_lnum + 1]:sub(1, diag.end_col)
    text = table.concat(parts, "\n")
  end
  assert_eq(text, expected, "diagnostic range")
end

local SEV = { ERROR = 1, WARN = 2, INFO = 3, HINT = 4 }

-- ─── Tests ──────────────────────────────────────────────────────────────────

describe_impl("app.mount", function()
  it_impl("flags app.mount() as an error with an exact range", function()
    local lines = {
      "const app = createApp(App)",
      "app.use(router)",
      "app.mount('#app')",
    }
    local diags = diagnostics.collect(lines)
    assert_count(diags, 1, "app.mount")
    assert_eq(diags[1].severity, SEV.ERROR, "severity")
    assert_eq(diags[1].lnum, 2, "lnum")
    assert_range(lines, diags[1], "app.mount(")
  end)

  it_impl("ignores app.start()", function()
    local diags = diagnostics.collect({ "const app = createApp(App)", "app.start()" })
    assert_count(diags, 0, "app.start")
  end)
end)

describe_impl("v-for scoping", function()
  it_impl("does NOT flag a v-for in a sibling VScrollView when a VList exists elsewhere", function()
    -- This is the regression the whole-buffer `check_context` heuristic caused.
    local lines = {
      "<template>",
      "  <VScrollView>",
      '    <VView v-for="item in items" :key="item.id" />',
      "  </VScrollView>",
      "  <VList :data=\"items\">",
      '    <template #item="{ item }"><VText>{{ item.title }}</VText></template>',
      "  </VList>",
      "</template>",
    }
    local diags = diagnostics.collect(lines)
    assert_eq(find_by_id(diags, "VList takes :data"), nil, "v-for finding")
  end)

  it_impl("warns when v-for sits on the <VList> opening tag", function()
    local lines = {
      "<template>",
      '  <VList v-for="item in items" :data="items">',
      "  </VList>",
      "</template>",
    }
    local diags = diagnostics.collect(lines)
    assert_count(diags, 1, "v-for on VList tag")
    assert_eq(diags[1].severity, SEV.WARN, "severity")
    assert_eq(diags[1].lnum, 1, "lnum")
    assert_range(lines, diags[1], 'v-for="item in items')
  end)

  it_impl("hints (not warns) for a v-for inside the VList element body", function()
    local lines = {
      '<VList :data="items">',
      '  <VView v-for="x in y" />',
      "</VList>",
    }
    local diags = diagnostics.collect(lines)
    assert_count(diags, 1, "v-for in VList body")
    assert_eq(diags[1].severity, SEV.HINT, "severity")
    assert_eq(diags[1].lnum, 1, "lnum")
  end)

  it_impl("produces nothing when the buffer has no VList", function()
    local lines = {
      "<VScrollView>",
      '  <VView v-for="item in items" :key="item.id" />',
      "</VScrollView>",
    }
    assert_count(diagnostics.collect(lines), 0, "no VList")
  end)

  it_impl("matches the `of` form of v-for", function()
    local lines = { '<VList v-for="item of items" :data="items">', "</VList>" }
    local diags = diagnostics.collect(lines)
    assert_count(diags, 1, "v-for of")
    assert_eq(diags[1].severity, SEV.WARN, "severity")
    assert_range(lines, diags[1], 'v-for="item of items')
  end)

  it_impl("matches a v-for whose value spans multiple lines", function()
    -- The old line-scoped find missed this entirely.
    local lines = {
      "<VList",
      '  v-for="item',
      '    in items"',
      '  :data="items"',
      ">",
      "</VList>",
    }
    local diags = diagnostics.collect(lines)
    assert_count(diags, 1, "multi-line v-for")
    assert_eq(diags[1].severity, SEV.WARN, "severity")
    assert_eq(diags[1].lnum, 1, "start lnum")
    assert_eq(diags[1].end_lnum, 2, "end lnum")
    assert_range(lines, diags[1], 'v-for="item\n    in items')
  end)

  it_impl("does not mistake <VListItem> for <VList>", function()
    local lines = { '<VListItem v-for="x in y" />', "<VList :data=\"items\" />" }
    assert_count(diagnostics.collect(lines), 0, "VListItem")
  end)

  it_impl("ignores a `>` inside a quoted attribute when finding the opening tag", function()
    -- If the quote were not skipped, open_end would land inside `a > b` and this
    -- v-for would be misclassified as a body HINT instead of a tag WARN.
    local lines = {
      '<VList :data="a > b" v-for="x in y">',
      "</VList>",
    }
    local diags = diagnostics.collect(lines)
    assert_count(diags, 1, "quoted >")
    assert_eq(diags[1].severity, SEV.WARN, "severity")
  end)
end)

describe_impl("vue import", function()
  it_impl("hints on `import ... from 'vue'`", function()
    local lines = { "import { ref } from 'vue'", "" }
    local diags = diagnostics.collect(lines)
    assert_count(diags, 1, "vue import")
    assert_eq(diags[1].severity, SEV.HINT, "severity")
    assert_range(lines, diags[1], "import { ref } from 'vue'")
  end)

  it_impl("ignores the runtime package import", function()
    local lines = { "import { VView } from '@thelacanians/vue-native-runtime'" }
    assert_count(diagnostics.collect(lines), 0, "runtime import")
  end)

  it_impl("does not let a non-vue import leak the match onto a later line", function()
    local lines = {
      "import { something } from './local'",
      "const x = 1",
      "import { ref } from 'vue'",
    }
    local diags = diagnostics.collect(lines)
    assert_count(diags, 1, "second import")
    assert_eq(diags[1].lnum, 2, "lnum")
  end)
end)

describe_impl("diagnostic shape", function()
  it_impl("emits 0-based positions with an exclusive end column", function()
    local lines = { "app.mount()" }
    local diag = diagnostics.collect(lines)[1]
    assert_eq(diag.lnum, 0, "lnum")
    assert_eq(diag.col, 0, "col")
    assert_eq(diag.end_lnum, 0, "end_lnum")
    -- "app.mount(" is 10 characters: 0-based inclusive start 0, exclusive end 10.
    assert_eq(diag.end_col, 10, "end_col")
    assert_eq(diag.source, "Vue Native", "source")
  end)

  it_impl("returns diagnostics sorted by position", function()
    local lines = { "app.mount()", "app.mount()", "app.mount()" }
    local diags = diagnostics.collect(lines)
    assert_count(diags, 3, "three mounts")
    for idx = 2, #diags do
      if diags[idx].lnum < diags[idx - 1].lnum then
        fail("diagnostics not sorted at index %d", idx)
      end
    end
  end)

  it_impl("returns an empty table for a clean buffer", function()
    local lines = {
      "<script setup lang=\"ts\">",
      "import { ref } from '@thelacanians/vue-native-runtime'",
      "const items = ref([])",
      "</script>",
      "<template>",
      '  <VList :data="items">',
      '    <template #item="{ item }"><VText>{{ item }}</VText></template>',
      "  </VList>",
      "</template>",
    }
    assert_count(diagnostics.collect(lines), 0, "clean buffer")
  end)
end)

-- ─── Plain-Lua summary (busted prints its own) ──────────────────────────────
if not (type(_G.describe) == "function" and type(_G.it) == "function") then
  if failed == 0 then
    io.write(string.format("ok — %d assertions suites, %d tests passed\n", 5, ran))
    os.exit(0)
  else
    io.write(string.format("%d/%d tests FAILED\n", failed, ran))
    os.exit(1)
  end
end
