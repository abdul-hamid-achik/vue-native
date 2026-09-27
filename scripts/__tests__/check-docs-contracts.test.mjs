import assert from 'node:assert/strict'
import { test } from 'node:test'
import { fileURLToPath } from 'node:url'
import { resolve } from 'node:path'
import {
  IGNORE_MARKER,
  blankLiterals,
  buildApiModel,
  checkDocsTree,
  checkMarkdown,
  collectVuePublicNames,
  composableReturnKeys,
  destructuredNames,
  extractCodeBlocks,
  extractTagAttributes,
  objectLiteralKeys,
} from '../check-docs-contracts.mjs'

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)))

/**
 * Vue's re-export surface is pinned here instead of resolved from
 * node_modules, so the import tests do not depend on an installed
 * @vue/runtime-core. The real resolution is asserted separately below.
 */
const vueExports = new Set(['ref', 'computed', 'watch', 'onMounted', 'h', 'defineAsyncComponent'])

const model = await buildApiModel(root, { vueExports })

function check(markdown) {
  return checkMarkdown('docs/src/guide/fixture.md', markdown, model)
}

// ---------------------------------------------------------------------------
// The gate must be able to FAIL
// ---------------------------------------------------------------------------

test('a fabricated composable member is reported with the real return shape', () => {
  const { issues } = check([
    '```ts',
    'import { useI18n } from \'@thelacanians/vue-native-runtime\'',
    'const { t, locale } = useI18n()',
    '```',
  ].join('\n'))

  assert.equal(issues.length, 1)
  assert.match(issues[0], /"t" is not returned by useI18n\(\)/)
  assert.match(issues[0], /it returns \{ isRTL, locale \}/)
  assert.match(issues[0], /fixture\.md:3/)
})

test('a fabricated package export is reported', () => {
  const { issues } = check([
    '```ts',
    'import { ref, watchDebounced } from \'@thelacanians/vue-native-runtime\'',
    '```',
  ].join('\n'))

  assert.equal(issues.length, 1)
  assert.match(issues[0], /"watchDebounced" is not exported by @thelacanians\/vue-native-runtime/)
})

test('a Vue re-export through the runtime package is accepted', () => {
  const { issues } = check([
    '```ts',
    'import { ref, computed, onMounted } from \'@thelacanians/vue-native-runtime\'',
    '```',
  ].join('\n'))

  assert.deepEqual(issues, [])
})

test('router.back() and route.path are reported with the real members', () => {
  const { issues } = check([
    '```ts',
    'import { useRouter, useRoute } from \'@thelacanians/vue-native-navigation\'',
    'const router = useRouter()',
    'const route = useRoute()',
    'router.back()',
    'console.log(route.path, route.query, route.params.id)',
    '```',
  ].join('\n'))

  assert.equal(issues.length, 3)
  assert.match(issues[0], /"back" does not exist on RouterInstance/)
  assert.match(issues[0], /goBack/)
  assert.match(issues[1], /"path" does not exist on RouteLocation/)
  assert.match(issues[2], /"query" does not exist on RouteLocation/)
})

test('the real router and route members pass, including the ref unwrap', () => {
  const { issues } = check([
    '```ts',
    'const router = useRouter()',
    'const route = useRoute()',
    'router.push("home")',
    'router.goBack()',
    'router.canGoBack.value',
    'route.value.name',
    'route.params.id',
    '```',
  ].join('\n'))

  assert.deepEqual(issues, [])
})

test('<VList :renderItem> is reported and points at VFlatList and the #item slot', () => {
  const { issues } = check([
    '```vue',
    '<VList :data="items" :renderItem="renderRow" />',
    '```',
  ].join('\n'))

  assert.equal(issues.length, 1)
  assert.match(issues[0], /<VList> does not declare a "renderItem" prop/)
  assert.match(issues[0], /"renderItem" is declared by <VFlatList>/)
  assert.match(issues[0], /<VList> takes .*#item.* slot\(s\) instead/)
})

test('an undeclared prop on a component with no alias is reported', () => {
  const { issues } = check('```vue\n<VSwitch :tintColor="\'red\'" />\n```')

  assert.equal(issues.length, 1)
  assert.match(issues[0], /<VSwitch> does not declare a "tintColor" prop/)
})

test('a reader-defined component and a user composable are never judged', () => {
  const { issues } = check([
    '```vue',
    '<script setup>',
    'import { useAIChat } from \'./generated/useAIChat\'',
    'const { messages, streamResponse } = useAIChat()',
    '</script>',
    '',
    '<template>',
    '  <AIMessageView :message="m" :streaming="true" />',
    '  <VMapGL region="us" />',
    '</template>',
    '```',
  ].join('\n'))

  assert.deepEqual(issues, [])
})

// ---------------------------------------------------------------------------
// The gate must not cry wolf
// ---------------------------------------------------------------------------

test('a renamed prop the component forwards to its native tag passes', () => {
  // VSwitch declares `modelValue` but emits `value` to the native factory, and
  // both spellings reach the switch. Reporting either would be a false positive.
  const { issues } = check([
    '```vue',
    '<VSwitch v-model="enabled" />',
    '<VSwitch :modelValue="enabled" />',
    '<VSwitch :value="enabled" onTintColor="#34C759" />',
    '```',
  ].join('\n'))

  assert.deepEqual(issues, [])
})

test('Vue special attributes, on* handlers and accessibility props pass everywhere', () => {
  const { issues } = check([
    '```vue',
    '<VView :key="id" ref="el" class="row" :style="{ flex: 1 }" accessibilityLabel="Row" />',
    '<VText v-if="show" v-for="n in items" :numberOfLines="1" @press="go">hi</VText>',
    '<VList :data="items" :onEndReached="load" :renderItem="r" />',
    '```',
  ].join('\n'))

  // Only :renderItem is drift; everything else on those three tags is accepted.
  assert.equal(issues.length, 1)
  assert.match(issues[0], /renderItem/)
})

test('kebab-case bindings resolve to the camelCase prop', () => {
  const { issues } = check('```vue\n<VNavigationBar title="Settings" :show-back="canGoBack" />\n```')

  assert.deepEqual(issues, [])
})

test('the ignore marker above a fence skips the whole block', () => {
  const { issues } = check([
    `<!-- ${IGNORE_MARKER} -->`,
    '```ts',
    'import { watchDebounced } from \'@thelacanians/vue-native-runtime\'',
    'const { t } = useI18n()',
    '```',
  ].join('\n'))

  assert.deepEqual(issues, [])
})

test('the ignore marker on the offending line skips only that line', () => {
  const { issues } = check([
    '```ts',
    `const { t } = useI18n() // ${IGNORE_MARKER}`,
    'const { request } = useHttp()',
    '```',
  ].join('\n'))

  assert.equal(issues.length, 1)
  assert.match(issues[0], /"request" is not returned by useHttp\(\)/)
})

test('non-code fences are skipped entirely', () => {
  const { issues, checkedBlocks } = check([
    '```text',
    'const { t } = useI18n()',
    '```',
    '',
    '```json',
    '{ "renderItem": true }',
    '```',
    '',
    '```',
    'router.back()  // a diagram, not code',
    '```',
  ].join('\n'))

  assert.deepEqual(issues, [])
  assert.equal(checkedBlocks, 0)
})

test('a comment mentioning router.ts is not a member access', () => {
  const { issues } = check([
    '```ts',
    '// navigation/router.ts',
    'const url = "https://example.com/router.ts"',
    '```',
  ].join('\n'))

  assert.deepEqual(issues, [])
})

// ---------------------------------------------------------------------------
// Parser primitives
// ---------------------------------------------------------------------------

test('blankLiterals keeps offsets and newlines while emptying comments and strings', () => {
  const source = 'const a = \'x{y}\' // note {\n/* block } */\nconst b = `t${1}u`'
  const blank = blankLiterals(source)

  assert.equal(blank.length, source.length)
  assert.equal(blank.split('\n').length, source.split('\n').length)
  assert.ok(!blank.includes('note'))
  assert.ok(!blank.includes('block'))
  assert.ok(blank.includes('const a = '))
  assert.ok(blank.includes('const b = '))
})

test('objectLiteralKeys reads shorthand, quoted, method and accessor keys', () => {
  const source = ' loading, error, get, "quoted:key": 1, async fetch() {}, get total() { return 1 } '
  const { keys, open } = objectLiteralKeys(blankLiterals(source), source)

  assert.equal(open, false)
  assert.deepEqual(
    [...keys].sort(),
    ['error', 'fetch', 'get', 'loading', 'quoted:key', 'total'],
  )
})

test('objectLiteralKeys ignores JSDoc comments between entries', () => {
  const source = '\n  /** The data. */\n  data: [],\n  // trailing note\n  keyExtractor: null,\n'
  const { keys, open } = objectLiteralKeys(blankLiterals(source), source)

  assert.equal(open, false)
  assert.deepEqual([...keys].sort(), ['data', 'keyExtractor'])
})

test('objectLiteralKeys reports a spread or computed key as unenumerable', () => {
  assert.equal(objectLiteralKeys(' ...base, a ', '...base, a').open, true)
  assert.equal(objectLiteralKeys(' [name]: 1 ', '[name]: 1').open, true)
})

test('destructuredNames takes the source name of a rename and skips rest', () => {
  const source = ' loading, error, post: postRequest, retries = 3, ...rest '
  assert.deepEqual(destructuredNames(source, source), ['loading', 'error', 'post', 'retries'])
})

test('composableReturnKeys unions every return object across many lines', () => {
  const source = [
    'export function useThing(options = { a: 1 }) {',
    '  const state = ref(0)',
    '  if (!supported) {',
    '    return {',
    '      isSupported: false,',
    '    }',
    '  }',
    '  watch(state, () => {',
    '    // A nested closure return widens the accepted set. That is deliberate:',
    '    // over-approximation is a false negative, never a false positive.',
    '    return { inner: \'ignored\' }',
    '  })',
    '  return {',
    '    isSupported: true,',
    '    refresh,',
    '  }',
    '}',
  ].join('\n')

  const parsed = composableReturnKeys(source, 'useThing')
  assert.equal(parsed.open, false)
  assert.deepEqual([...parsed.keys].sort(), ['inner', 'isSupported', 'refresh'])
})

test('composableReturnKeys marks a non-literal return as unenumerable', () => {
  const parsed = composableReturnKeys('export function useThing() {\n  return state\n}', 'useThing')
  assert.equal(parsed.open, true)
})

test('extractCodeBlocks records the info string, line number and ignore marker', () => {
  const markdown = [
    '# Title',
    '',
    '```vue',
    '<VView />',
    '```',
    '',
    `<!-- ${IGNORE_MARKER} -->`,
    '```ts',
    'nope',
    '```',
  ].join('\n')

  const blocks = extractCodeBlocks(markdown)
  assert.equal(blocks.length, 2)
  assert.equal(blocks[0].info, 'vue')
  assert.equal(blocks[0].startLine, 4)
  assert.equal(blocks[0].parseAsTemplate, true)
  assert.equal(blocks[0].ignored, false)
  assert.equal(blocks[1].ignored, true)
})

test('extractTagAttributes survives a ">" inside an attribute value', () => {
  const [tag] = extractTagAttributes('<VModal :visible="count > 0" title="a > b" />')

  assert.equal(tag.tag, 'VModal')
  assert.deepEqual(tag.attributes, [':visible', 'title'])
})

// ---------------------------------------------------------------------------
// Model resolution against the real tree
// ---------------------------------------------------------------------------

test('the model resolves the real composables, components and router members', () => {
  assert.ok(model.composables.size > 40)
  assert.ok(model.components.size > 30)
  assert.equal(model.composables.get('useI18n').open, false)
  assert.deepEqual([...model.composables.get('useI18n').keys].sort(), ['isRTL', 'locale'])
  assert.ok(model.components.get('VSwitch').props.has('modelValue'))
  assert.ok(model.components.get('VSwitch').props.has('value'))
  assert.ok(model.routerMembers.has('goBack'))
  assert.ok(model.routerMembers.has('pop'))
  assert.equal(model.routerMembers.has('back'), false)
  assert.ok(model.routeMembers.has('name'))
  assert.equal(model.routeMembers.has('path'), false)
  // Aliases resolve to the same contract.
  assert.equal(model.components.get('VErrorBoundary'), model.components.get('ErrorBoundary'))
  assert.equal(model.components.get('VDrawer.Item'), model.components.get('VDrawerItem'))
})

test('@vue/runtime-core resolves from the workspace so Vue re-exports are known', async (t) => {
  const names = await collectVuePublicNames(root)
  if (names === null) {
    t.skip('@vue/runtime-core is not installed')
    return
  }
  for (const expected of ['ref', 'computed', 'watch', 'onMounted', 'nextTick', 'h']) {
    assert.equal(names.has(expected), true, `${expected} should be part of Vue's public API`)
  }
  // Type-only exports must be covered too — docs import `Ref` and friends.
  assert.equal(names.has('Ref'), true)
  assert.equal(names.has('ComponentPublicInstance'), true)
})

test('the documentation tree currently has no contract drift', async () => {
  const { issues, stats } = await checkDocsTree(root)

  assert.deepEqual(issues, [])
  assert.ok(stats.files > 100, `expected the docs tree to be scanned, got ${stats.files} file(s)`)
  assert.ok(stats.checkedBlocks > 400, `expected code blocks to be parsed, got ${stats.checkedBlocks}`)
  assert.ok(stats.checkedSymbols > 1000, `expected API references to be checked, got ${stats.checkedSymbols}`)
  assert.equal(stats.vueResolved, true)
})
