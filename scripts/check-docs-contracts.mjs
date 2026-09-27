#!/usr/bin/env node
/**
 * Documentation contract gate.
 *
 * `docs/` is excluded from ESLint (see `eslint.config.mjs`) and from every
 * lefthook hook, so VuePress happily publishes code samples that cannot run.
 * Commit d485ebe removed six pages' worth of fabricated APIs —
 * `router.back()`, `route.path`, `useDeviceInfo().platform`, `useI18n().t`,
 * `useHttp().request`, `useAnimation().start()`, `watchDebounced`, and
 * `<VList :renderItem>` — each of which made a reader write code that throws at
 * runtime or fails to build. Nothing in the repo could have caught any of them.
 * This script is that missing gate: it extracts the API references from the
 * documentation's fenced code blocks and asserts each one against the real
 * TypeScript sources.
 *
 * It checks four things:
 *
 *   1. Named imports from `@thelacanians/vue-native-runtime` and
 *      `@thelacanians/vue-native-navigation` exist in those packages' exports.
 *   2. Members destructured out of a `useX()` call appear in that composable's
 *      real `return { ... }` object. This is the check that catches `t`,
 *      `request`, `start`/`stop` and `brand`.
 *   3. `router.<member>` and `route.<member>` references exist on
 *      `RouterInstance` / `RouteLocation`.
 *   4. Props bound on a `<V*>` / `<RouterView>` tag in a template are declared
 *      (or explicitly forwarded) by that component.
 *
 * Design rule: a doc gate that cries wolf gets disabled, and a disabled gate is
 * worse than none. Every ambiguity in this file resolves towards a FALSE
 * NEGATIVE, never a false positive. The guards are marked
 * "FALSE POSITIVE guard" below.
 *
 * Deliberately NOT checked, because neither can be made precise from the
 * TypeScript sources alone:
 *
 *   - Unknown `<V*>` tags. `guide/native-blocks.md` documents `<VTextInput>`
 *     (generated from a `<native>` SFC block) and `guide/native-components.md`
 *     documents `<VMapGL>` (built with `createNativeComponent`), so "not a
 *     shipped component" does not mean "does not exist".
 *   - `@event` listener names. An undeclared listener becomes an `on<Event>`
 *     attr that the renderer registers with `addEventListener`, so whether it
 *     can ever fire depends on which events each NATIVE factory dispatches.
 *     That is cross-language territory already owned by
 *     check-native-contracts.mjs; a TypeScript-only version here would flag
 *     working listeners. (Known gap it would cover: `guide/forms.md` used to
 *     listen for `@input` on `<VInput>`, which emits `update:modelValue`.)
 *
 * Usage: bun scripts/check-docs-contracts.mjs
 */

import { readdir, readFile } from 'node:fs/promises'
import { createRequire } from 'node:module'
import { join, relative, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

/**
 * Escape hatch. A page that deliberately shows a WRONG example (to explain why
 * it is wrong) puts this marker on one of the three lines above the fence
 * (skips the whole block), as a trailing comment on the offending line, or on a
 * comment-only line directly above it (skips that line only).
 */
export const IGNORE_MARKER = 'vue-native-docs-contract-ignore'

/**
 * Fence info strings whose contents are Vue Native TypeScript or SFC source.
 *
 * FALSE POSITIVE guard: everything else is skipped on purpose. `bash`, `json`,
 * `yaml` and `text` hold no API references; `swift`/`kotlin`/`xml`/`groovy`
 * hold native or build code this script knows nothing about; `jsx`/`tsx` hold
 * React Native "before" samples (guide/migrating-from-react-native.md) whose
 * `<View>`/`<Text>` tags and `react-native` imports must not be judged. Blocks
 * with NO info string are skipped too: all 32 in the current tree are ASCII
 * architecture diagrams, directory trees, or captured console output.
 */
const SCRIPT_INFOS = new Set(['ts', 'typescript', 'js', 'javascript', 'vue', 'html', 'sfc'])
const TEMPLATE_INFOS = new Set(['vue', 'html', 'sfc'])

/**
 * Vue's own special attributes. They are handled by Vue or by the renderer, are
 * never component props, and no component declares them. `style` in particular
 * is applied through the bridge's style ops rather than as a component prop
 * (see `tsResolvedProps` in check-native-contracts.mjs).
 */
const VUE_SPECIAL_ATTRS = new Set([
  'key', 'ref', 'ref_for', 'ref_key', 'class', 'style', 'id', 'is', 'slot',
])

/**
 * Props that no component declares individually, because `StyleEngine.apply`
 * handles them for EVERY native view — so an undeclared `accessibilityLabel`
 * falling through as an attr still reaches the platform accessibility API.
 * Verified present in all three style engines:
 *
 *   native/ios/VueNativeCore/Sources/VueNativeCore/Styling/StyleEngine.swift
 *   native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Styling/StyleEngine.kt
 *   native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Styling/StyleEngine.swift
 *
 * Without this set, `guide/navigation-components.md` documenting
 * `<VTabBar :accessibilityLabel>` — which works — would be reported as drift.
 */
const UNIVERSALLY_HANDLED_PROPS = new Set([
  'accessibilityLabel',
  'accessibilityHint',
  'accessibilityRole',
  'accessibilityState',
  'importantForAccessibility',
])

/**
 * Props a component's NATIVE factory accepts under a name the TypeScript
 * component does not declare. Each entry must state where the alias was
 * verified; an entry that stops being true is over-permissive, not wrong, so
 * this list is safe to keep but should be pruned when the alias is removed.
 *
 * Key format: `<Tag>|<prop>`.
 */
const NATIVE_PROP_ALIASES = new Map([
  [
    'VInput|value',
    'VInputFactory handles "value" as an alias for "text" on iOS (case "text", "value"), '
    + 'Android ("text", "value" ->) and macOS (case "text", "value"), so `:value` binds the '
    + 'input text exactly like the declared `modelValue`.',
  ],
])

const RUNTIME_PACKAGE = '@thelacanians/vue-native-runtime'
const NAVIGATION_PACKAGE = '@thelacanians/vue-native-navigation'

// ---------------------------------------------------------------------------
// Source scanning primitives
// ---------------------------------------------------------------------------

/**
 * Blank out comments and string/template-literal CONTENTS while preserving
 * every offset and newline, so structural indices found in the blanked text can
 * slice the original.
 *
 * FALSE POSITIVE guard: without this, `// navigation/router.ts` inside a sample
 * parses as a `router.ts` member access, and a `{` inside a string literal
 * breaks every brace-matching scan below.
 */
export function blankLiterals(source) {
  let out = ''
  let index = 0

  while (index < source.length) {
    const char = source[index]
    const next = source[index + 1]

    if (char === '/' && next === '/') {
      while (index < source.length && source[index] !== '\n') {
        out += ' '
        index++
      }
      continue
    }
    if (char === '/' && next === '*') {
      out += '  '
      index += 2
      while (index < source.length && !(source[index] === '*' && source[index + 1] === '/')) {
        out += source[index] === '\n' ? '\n' : ' '
        index++
      }
      out += '  '
      index += 2
      continue
    }
    if (char === '"' || char === '\'') {
      // The delimiters are kept so a quoted object key (`'update:modelValue':`)
      // is still recognisable as a string in the blanked text.
      out += char
      index++
      while (index < source.length && source[index] !== char) {
        if (source[index] === '\\') {
          out += '  '
          index += 2
          continue
        }
        out += source[index] === '\n' ? '\n' : ' '
        index++
      }
      out += char
      index++
      continue
    }
    if (char === '`') {
      out += '`'
      index++
      let interpolation = 0
      while (index < source.length) {
        if (source[index] === '\\') {
          out += '  '
          index += 2
          continue
        }
        if (interpolation === 0 && source[index] === '`') {
          out += '`'
          index++
          break
        }
        if (interpolation === 0 && source[index] === '$' && source[index + 1] === '{') {
          out += '  '
          index += 2
          interpolation++
          continue
        }
        if (interpolation > 0) {
          if (source[index] === '{') interpolation++
          else if (source[index] === '}') interpolation--
        }
        out += source[index] === '\n' ? '\n' : ' '
        index++
      }
      continue
    }

    out += char
    index++
  }

  return out
}

/**
 * Balanced bracket run. `open` is the absolute index of the opening bracket.
 * Returns absolute offsets so callers can slice the ORIGINAL source with them.
 */
function balanced(blank, open, openChar, closeChar) {
  let depth = 0
  for (let index = open; index < blank.length; index++) {
    if (blank[index] === openChar) depth++
    else if (blank[index] === closeChar) {
      depth--
      if (depth === 0) return { body: blank.slice(open + 1, index), start: open, end: index }
    }
  }
  return null
}

const braces = (blank, open) => balanced(blank, open, '{', '}')
const parens = (blank, open) => balanced(blank, open, '(', ')')
const brackets = (blank, open) => balanced(blank, open, '[', ']')

/** Slice the original source that corresponds to a balanced() result. */
function originalOf(source, range) {
  return source.slice(range.start + 1, range.end)
}

/** Top-level entries of an object-literal body, split on depth-0 commas. */
function splitEntries(blankBody, originalBody) {
  const spans = []
  let depth = 0
  let start = 0
  for (let index = 0; index < blankBody.length; index++) {
    const char = blankBody[index]
    if (char === '{' || char === '[' || char === '(') depth++
    else if (char === '}' || char === ']' || char === ')') depth--
    else if (char === ',' && depth === 0) {
      spans.push([start, index])
      start = index + 1
    }
  }
  spans.push([start, blankBody.length])

  return spans
    .map(([from, to]) => ({
      blank: blankBody.slice(from, to).trim(),
      original: originalBody.slice(from, to).trim(),
    }))
    .filter(entry => entry.blank.length > 0)
}

/**
 * Keys of an object literal.
 *
 * Handles the shapes a composable `return` or a component `props` block
 * actually uses: `key: value`, shorthand `key`, methods `key() {}` /
 * `async key() {}`, accessors `get key() {}`, and quoted keys (whose text only
 * survives in the ORIGINAL slice, since blankLiterals empties string contents).
 *
 * `open` is set when the literal contains something this parser cannot
 * enumerate — a spread (`{ ...base }`), a computed key (`{ [name]: v }`), or an
 * entry it fails to recognise. Callers MUST treat `open: true` as "the key set
 * is incomplete" and skip validation instead of reporting a member as missing.
 * That is the single most important false-positive guard in this file.
 */
export function objectLiteralKeys(blankBody, originalBody) {
  const keys = new Set()
  let open = false

  for (const entry of splitEntries(blankBody, originalBody)) {
    const blankText = entry.blank.trimStart()
    if (blankText.startsWith('...') || blankText.startsWith('[')) {
      open = true
      continue
    }
    // A quoted key has to be read from the ORIGINAL slice, because
    // blankLiterals empties string contents. Every other shape is read from the
    // BLANK slice, because that is where JSDoc comments have been erased: an
    // entry whose original text starts with `/** Array of data items */` would
    // otherwise fail to yield `data` and mark the whole literal unenumerable.
    if (blankText.startsWith('\'') || blankText.startsWith('"')) {
      const quoted = /^(?:'([^']*)'|"([^"]*)")/.exec(entry.original.trimStart())
      if (quoted === null) open = true
      else keys.add(quoted[1] ?? quoted[2])
      continue
    }
    const match = /^(?:async\s+)?(?:(?:get|set)\s+)?([A-Za-z_$][\w$]*)/.exec(blankText)
    if (match === null) {
      open = true
      continue
    }
    keys.add(match[1])
  }

  return { keys, open }
}

/**
 * Names bound by a destructuring pattern (`{ a, b: local, c = 1, ...rest }`).
 * The checked name is always the one BEFORE the colon — `{ post: postRequest }`
 * reads the `post` member. Rest elements are skipped: they bind whatever is left
 * over and assert nothing.
 */
export function destructuredNames(blankBody, originalBody) {
  const names = []
  for (const entry of splitEntries(blankBody, originalBody)) {
    const blankText = entry.blank.trimStart()
    if (blankText.startsWith('...')) continue
    if (blankText.startsWith('\'') || blankText.startsWith('"')) {
      const quoted = /^(?:'([^']*)'|"([^"]*)")/.exec(entry.original.trimStart())
      if (quoted !== null) names.push(quoted[1] ?? quoted[2])
      continue
    }
    const match = /^([A-Za-z_$][\w$]*)/.exec(blankText)
    if (match !== null) names.push(match[1])
  }
  return names
}

/** `kebab-case` -> `camelCase`, so `:show-back` matches the `showBack` prop. */
function camelize(name) {
  return name.replace(/-([a-z0-9])/g, (_, char) => char.toUpperCase())
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

async function readIfExists(path) {
  try {
    return await readFile(path, 'utf8')
  } catch (error) {
    if (error?.code === 'ENOENT') return null
    throw error
  }
}

async function walkFiles(directory, predicate) {
  const found = []
  const entries = await readdir(directory, { withFileTypes: true }).catch(() => [])
  for (const entry of entries) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) {
      if (entry.name === 'node_modules' || entry.name === 'dist') continue
      found.push(...await walkFiles(path, predicate))
    } else if (predicate(entry.name)) {
      found.push(path)
    }
  }
  return found
}

// ---------------------------------------------------------------------------
// Real-source extraction
// ---------------------------------------------------------------------------

/**
 * Every name a package entry point exports: `export function/const/class/
 * interface/type/enum NAME`, plus `export { a, b as c }` (with or without
 * `from '...'`, with or without `type`).
 */
export function collectPackageExports(source) {
  const blank = blankLiterals(source)
  const names = new Set()

  for (const match of blank.matchAll(
    /\bexport\s+(?:declare\s+)?(?:async\s+)?(?:function\s*\*?|const|let|var|class|abstract\s+class|interface|type|enum|namespace)\s+([A-Za-z_$][\w$]*)/g,
  )) {
    names.add(match[1])
  }

  for (const match of blank.matchAll(/\bexport\s+(?:type\s+)?\{([\s\S]*?)\}/g)) {
    for (const name of exportSpecifiers(match[1])) names.add(name)
  }

  return names
}

function exportSpecifiers(list) {
  const names = []
  for (const specifier of list.split(',')) {
    const trimmed = specifier.trim().replace(/^type\s+/, '')
    if (trimmed.length === 0) continue
    const alias = /\bas\s+([A-Za-z_$][\w$]*)$/.exec(trimmed)
    const name = alias ? alias[1] : trimmed.split(/\s+/)[0]
    if (/^[A-Za-z_$][\w$]*$/.test(name)) names.push(name)
  }
  return names
}

/**
 * Vue's public API surface, because the runtime entry point does
 * `export * from '@vue/runtime-core'`. Without this set, every legitimate
 * `import { ref } from '@thelacanians/vue-native-runtime'` would be reported as
 * missing — the largest single class of false positive this script must avoid.
 *
 * Names come from the shipped `runtime-core.d.ts` (values AND types), unioned
 * with the live module's own keys when it can be loaded. Returns null when the
 * dependency is not installed; the caller then skips the runtime named-import
 * check rather than guessing.
 */
export async function collectVuePublicNames(rootDir) {
  const require = createRequire(join(rootDir, 'packages/runtime/index.js'))
  let packageJson
  try {
    packageJson = require.resolve('@vue/runtime-core/package.json')
  } catch {
    return null
  }

  const packageDir = resolve(packageJson, '..')
  const types = await readIfExists(join(packageDir, 'dist/runtime-core.d.ts'))
  if (types === null) return null

  const names = new Set()
  // `declare` is optional in a .d.ts: `export interface VNode`, `export type
  // PropType<T>` and `export type ComponentPublicInstance` all appear without
  // it, and docs do import those type names.
  for (const match of types.matchAll(
    /^export\s+(?:declare\s+)?(?:abstract\s+)?(?:const|let|var|function\s*\*?|class|interface|type|enum|namespace)\s+([A-Za-z_$][\w$]*)/gm,
  )) {
    names.add(match[1])
  }
  for (const match of types.matchAll(/^export\s+(?:type\s+)?\{([\s\S]*?)\}/gm)) {
    for (const name of exportSpecifiers(match[1])) names.add(name)
  }

  // The .d.ts only carries what the bundler chose to declare; the runtime module
  // is authoritative for values. Best-effort — never fatal.
  try {
    const runtime = await import(pathToFileURL(join(packageDir, 'dist/runtime-core.esm-bundler.js')).href)
    for (const name of Object.keys(runtime)) names.add(name)
  } catch {
    // Type-only resolution still covers the docs' imports.
  }

  return names
}

/**
 * Index of the `{` that opens a function body, starting from just after the
 * function's name. Walks the parameter list first so a default value like
 * `options: { interval?: number } = {}` cannot be mistaken for the body.
 */
function findBodyStart(blank, fromIndex) {
  const open = blank.indexOf('(', fromIndex)
  if (open === -1) return -1

  const params = parens(blank, open)
  if (params === null) return -1

  for (let index = params.end + 1; index < blank.length; index++) {
    const char = blank[index]
    if (char === '{') return index
    // A `;` or `}` before any `{` means an overload signature or an
    // expression-bodied arrow: no block body to parse.
    if (char === ';' || char === '}') return -1
  }
  return -1
}

/**
 * Return-object keys of a composable.
 *
 * `keys` is the union of EVERY `return { ... }` in the function body, at any
 * nesting depth. Unioning is deliberate: a composable may early-return a reduced
 * object from a platform guard (`if (!supported) return { ... }`), and taking
 * only the shallowest return would report the guarded keys as fabricated. The
 * cost is a little over-approximation — a nested helper's return widens the set
 * — which is a false negative, never a false positive.
 *
 * `open` is true when a return spreads, or when the composable does not return
 * an object literal at all (`return state`), meaning the key set cannot be
 * trusted and the composable must not be judged.
 */
export function composableReturnKeys(source, name) {
  const blank = blankLiterals(source)
  const signature = new RegExp(`\\bexport\\s+(?:async\\s+)?function\\s*\\*?\\s*${escapeRegExp(name)}\\b`).exec(blank)
    ?? new RegExp(`\\bexport\\s+const\\s+${escapeRegExp(name)}\\s*=`).exec(blank)
  if (signature === null) return null

  const bodyStart = findBodyStart(blank, signature.index + signature[0].length)
  if (bodyStart === -1) return { keys: new Set(), open: true }

  const body = braces(blank, bodyStart)
  if (body === null) return { keys: new Set(), open: true }

  const keys = new Set()
  let open = false
  let found = false

  for (const match of body.body.matchAll(/\breturn\s*\{/g)) {
    const objectStart = body.start + 1 + match.index + match[0].length - 1
    const object = braces(blank, objectStart)
    if (object === null) {
      open = true
      continue
    }
    found = true
    const parsed = objectLiteralKeys(object.body, originalOf(source, object))
    for (const key of parsed.keys) keys.add(key)
    if (parsed.open) open = true
  }

  if (!found) return { keys: new Set(), open: true }
  return { keys, open }
}

/**
 * Member names of an `interface` body: identifiers at depth 0 followed by `:`
 * or `(`, with the optional `?` stripped.
 */
export function interfaceMembers(blankBody) {
  const members = new Set()
  let depth = 0
  let pending = ''
  let index = 0

  while (index < blankBody.length) {
    const char = blankBody[index]

    if (depth === 0) {
      if (char === ':' || char === '(' || char === ';' || char === '\n') {
        if (char === ':' || char === '(') {
          const name = pending.trim().replace(/\?$/, '')
          if (/^[A-Za-z_$][\w$]*$/.test(name)) members.add(name)
        }
        pending = ''
      } else {
        pending += char
      }
    }

    if (char === '{' || char === '[' || char === '(') depth++
    else if (char === '}' || char === ']' || char === ')') depth--
    index++
  }

  return members
}

function interfaceBody(source, interfaceName) {
  const blank = blankLiterals(source)
  const match = new RegExp(`\\b(?:export\\s+)?interface\\s+${escapeRegExp(interfaceName)}\\b[^{]*\\{`).exec(blank)
  if (match === null) return null
  const body = braces(blank, match.index + match[0].length - 1)
  return body === null ? null : body.body
}

/**
 * The value range of a `key:` entry sitting at depth 1 of a
 * `defineComponent({ ... })` options object.
 *
 * FALSE POSITIVE guard: a plain `indexOf('props:')` also matches a nested
 * `setup(props: Props)` parameter annotation or a type literal inside setup,
 * which would yield an empty prop set and then flag every real prop the docs
 * use. Requiring the key to sit at depth 1 immediately after `{` or `,` rules
 * both out.
 */
function topLevelKeyValue(blank, optionsStart, optionsEnd, key) {
  for (const match of blank.matchAll(new RegExp(`\\b${escapeRegExp(key)}\\s*:\\s*`, 'g'))) {
    const at = match.index
    if (at <= optionsStart || at >= optionsEnd) continue
    if (depthAt(blank, optionsStart, at) !== 1) continue
    const before = blank.slice(0, at).trimEnd()
    if (!before.endsWith('{') && !before.endsWith(',')) continue

    const open = at + match[0].length
    if (blank[open] === '{') return braces(blank, open)
    if (blank[open] === '[') return brackets(blank, open)
    return null
  }
  return null
}

/** Bracket nesting depth of `to`, counted from `from`. */
function depthAt(blank, from, to) {
  let depth = 0
  for (let index = from; index < to; index++) {
    const char = blank[index]
    if (char === '{' || char === '[' || char === '(') depth++
    else if (char === '}' || char === ']' || char === ')') depth--
  }
  return depth
}

/**
 * Component contracts keyed by tag name.
 *
 * For each `defineComponent({ ... })` in the runtime's component sources, the
 * error boundary, and the navigation entry point, this records:
 *
 *   - `props`   declared prop names, plus the literal keys the component
 *               forwards to its native tag in `h('Tag', { ... })`.
 *   - `emits`   declared event names.
 *   - `slots`   slot names read from `slots.<name>` in the component body.
 *   - `open`    true when the contract cannot be enumerated completely, with
 *               the reason(s) recorded in `reasons` so a skipped component is
 *               never a mystery.
 *
 * Forwarded keys are part of the accepted set because components legitimately
 * RENAME before emitting: `VSwitch` declares `modelValue` but sends `value`,
 * and `VAlertDialog` resolves `confirmText`/`cancelText` into `buttons`. Docs
 * use both spellings and both work — an undeclared attribute falls through to
 * the native node. This is the same distinction check-native-contracts.mjs
 * draws for the native side.
 *
 * `on*` keys are NOT collected: the renderer converts any `onX` prop holding a
 * function into `addEventListener('x')` (see `toEventName` in
 * packages/runtime/src/renderer.ts), so every `on*` binding is valid by
 * construction and is allowed unconditionally at the call site instead.
 */
export async function collectComponentContracts(rootDir) {
  const sources = [
    ...(await walkFiles(join(rootDir, 'packages/runtime/src/components'), name => name.endsWith('.ts') && name !== 'index.ts')),
    join(rootDir, 'packages/runtime/src/errorBoundary.ts'),
    join(rootDir, 'packages/navigation/src/index.ts'),
  ]

  const contracts = new Map()
  const record = (tag) => {
    if (!contracts.has(tag)) {
      contracts.set(tag, { props: new Set(), emits: new Set(), slots: new Set(), open: false, reasons: new Set() })
    }
    return contracts.get(tag)
  }

  for (const path of sources) {
    const source = await readIfExists(path)
    if (source === null) continue
    const blank = blankLiterals(source)

    for (const call of blank.matchAll(/\bdefineComponent\s*\(/g)) {
      const optionsStart = call.index + call[0].length - 1
      const options = parens(blank, optionsStart)
      if (options === null) continue
      const optionsEnd = options.end
      const optionsSource = source.slice(optionsStart, optionsEnd)

      const nameMatch = /(?:^|[{,])\s*name\s*:\s*['"]([^'"]+)['"]/.exec(optionsSource)
      if (nameMatch === null) continue
      const contract = record(nameMatch[1])
      const markOpen = (reason) => {
        contract.open = true
        contract.reasons.add(reason)
      }

      // Depth is measured from the options object's own `{`, so `props:` sits at
      // depth 1 and a nested `setup(props: Props)` annotation does not.
      const optionsBrace = blank.indexOf('{', optionsStart)
      if (optionsBrace === -1 || optionsBrace > optionsEnd) {
        markOpen('no options object')
        continue
      }

      const propsRange = topLevelKeyValue(blank, optionsBrace, optionsEnd, 'props')
      if (propsRange === null) {
        // No `props:` key at all (RouterView) or a props value this parser
        // cannot enumerate. Forwarded keys below may still rescue it; if none
        // turn up the contract stays open and is not judged.
        markOpen('no enumerable `props` object')
      } else {
        const parsed = objectLiteralKeys(propsRange.body, originalOf(source, propsRange))
        for (const key of parsed.keys) {
          if (!/^on[A-Z]/.test(key)) contract.props.add(key)
        }
        if (parsed.open) markOpen('`props` contains a spread or computed key')
      }

      const emitsRange = topLevelKeyValue(blank, optionsBrace, optionsEnd, 'emits')
      if (emitsRange !== null && blank[emitsRange.start] === '[') {
        for (const match of originalOf(source, emitsRange).matchAll(/['"]([^'"]+)['"]/g)) {
          contract.emits.add(match[1])
        }
      } else if (emitsRange !== null) {
        markOpen('`emits` is not an array literal')
      }

      const optionsBlank = blank.slice(optionsBrace, optionsEnd)
      for (const match of optionsBlank.matchAll(/\bslots\s*\.\s*([A-Za-z_$][\w$]*)/g)) {
        contract.slots.add(match[1])
      }
      // A component that reads `slots[name]` accepts slot names this pass cannot
      // see, so nothing about it may be judged.
      if (/\bslots\s*\[/.test(optionsBlank)) markOpen('reads `slots[...]` dynamically')

      // Forwarded keys: every `h('Tag', { ... })` with a literal string tag.
      // Matched against the ORIGINAL source, not the blanked one: the tag lives
      // inside a string literal, which blankLiterals empties. Offsets are
      // identical in both, so the brace scan still uses `blank`.
      for (const h of source.matchAll(/\bh\(\s*(['"])([A-Z][\w]*)\1\s*,\s*\{/g)) {
        const open = h.index + h[0].length - 1
        if (open < optionsBrace || open > optionsEnd) continue
        const object = braces(blank, open)
        if (object === null) continue
        // A spread (`h('VList', { ...attrs, data })`) means undeclared attrs
        // reach the native node, so the literal keys here cannot be enumerated.
        // That is NOT a reason to stop judging the component: the declared
        // `props` list is still its public TypeScript API, and a prop that is
        // neither declared nor forwarded is exactly the "documented but inert"
        // mistake this gate exists for (`<VList :renderItem>`). Only the
        // forwarded contribution is dropped.
        if (object.body.includes('...')) continue
        const parsed = objectLiteralKeys(object.body, originalOf(source, object))
        for (const key of parsed.keys) {
          if (!/^on[A-Z]/.test(key)) contract.props.add(key)
        }
        if (parsed.open) markOpen('forwards a spread or computed key to its native tag')
      }

      if (contract.props.size === 0 && contract.emits.size === 0) {
        markOpen('declares no props and no emits')
      }
    }
  }

  // `export { ErrorBoundary as VErrorBoundary }` and the
  // `app.component('VDrawer.Item', VDrawerItem)` registrations are alternate
  // names for a contract this pass already extracted. Alias them rather than
  // treating the documented tag as unknown.
  const runtimeIndex = await readIfExists(join(rootDir, 'packages/runtime/src/index.ts'))
  if (runtimeIndex !== null) {
    for (const match of blankLiterals(runtimeIndex).matchAll(/\bexport\s+(?:type\s+)?\{([\s\S]*?)\}/g)) {
      for (const specifier of match[1].split(',')) {
        const alias = /^\s*([A-Za-z_$][\w$]*)\s+as\s+([A-Za-z_$][\w$]*)\s*$/.exec(specifier)
        if (alias === null) continue
        const target = contracts.get(alias[1])
        if (target !== undefined && !contracts.has(alias[2])) contracts.set(alias[2], target)
      }
    }
    for (const match of runtimeIndex.matchAll(/component\(\s*'([^']+)'\s*,\s*([A-Za-z_$][\w$]*)\s*\)/g)) {
      const target = contracts.get(match[2])
      if (target !== undefined && !contracts.has(match[1])) contracts.set(match[1], target)
    }
    for (const tag of [...contracts.keys()]) {
      if (!tag.includes('.')) continue
      const normalized = tag.replace(/\./g, '')
      if (contracts.has(normalized)) contracts.set(tag, contracts.get(normalized))
    }
  }

  return contracts
}

/**
 * Which components declare each prop, so an unknown-prop error can name the
 * component the prop really belongs to (`renderItem` -> VFlatList).
 */
function buildPropOwners(contracts) {
  const owners = new Map()
  for (const [tag, contract] of contracts) {
    for (const prop of contract.props) {
      if (!owners.has(prop)) owners.set(prop, new Set())
      owners.get(prop).add(tag)
    }
  }
  return owners
}

/** Return contracts for every `useX` the packages actually export. */
export async function collectComposables(rootDir, knownNames) {
  const files = [
    ...(await walkFiles(join(rootDir, 'packages/runtime/src'), name => name.endsWith('.ts'))),
    ...(await walkFiles(join(rootDir, 'packages/navigation/src'), name => name.endsWith('.ts'))),
  ]
  const contents = new Map()
  for (const path of files) {
    const source = await readIfExists(path)
    if (source !== null) contents.set(path, source)
  }

  const composables = new Map()
  for (const name of knownNames) {
    if (!/^use[A-Z]/.test(name)) continue
    const definition = new RegExp(
      `\\bexport\\s+(?:async\\s+)?function\\s*\\*?\\s*${escapeRegExp(name)}\\b|\\bexport\\s+const\\s+${escapeRegExp(name)}\\s*=`,
    )
    for (const [path, source] of contents) {
      if (!definition.test(source)) continue
      const parsed = composableReturnKeys(source, name)
      if (parsed === null) continue
      composables.set(name, { ...parsed, path })
      break
    }
  }
  return composables
}

// ---------------------------------------------------------------------------
// Markdown parsing
// ---------------------------------------------------------------------------

/**
 * Fenced code blocks of a Markdown document, with 1-based line numbers.
 *
 * `ignored` is true when the escape-hatch marker sits on one of the three lines
 * above the opening fence (three, so a `::: tip` wrapper or a blank line
 * between the marker and the fence still counts).
 */
export function extractCodeBlocks(markdown) {
  const lines = markdown.split('\n')
  const blocks = []
  let open = null

  for (let index = 0; index < lines.length; index++) {
    const line = lines[index]

    if (open === null) {
      const match = /^(\s*)(`{3,}|~{3,})([^\n]*)$/.exec(line)
      if (match === null) continue
      const info = match[3].trim().split(/\s+/)[0].toLowerCase()
      open = {
        info,
        marker: match[2][0],
        length: match[2].length,
        startLine: index + 2,
        lines: [],
        ignored: lines.slice(Math.max(0, index - 3), index).join('\n').includes(IGNORE_MARKER),
        parseAsScript: SCRIPT_INFOS.has(info),
        parseAsTemplate: TEMPLATE_INFOS.has(info),
      }
      continue
    }

    const closePattern = new RegExp(`^\\s*${escapeRegExp(open.marker)}{${open.length},}\\s*$`)
    if (closePattern.test(line)) {
      blocks.push({ ...open, code: open.lines.join('\n') })
      open = null
      continue
    }
    open.lines.push(line)
  }

  return blocks
}

/**
 * Attributes of every PascalCase tag in a template, with the tag's 1-based line
 * inside the block.
 *
 * The scan is hand-rolled rather than regex-based because attribute values
 * routinely contain `>` (`:visible="count > 0"`), quotes, and newlines.
 *
 * FALSE POSITIVE guard: only tags this repo ships are judged (see
 * checkComponentProps), so TypeScript generics inside a `<script setup>`
 * section (`ref<Product[]>([])`) cannot produce a finding even though they look
 * like tags to this scanner.
 */
export function extractTagAttributes(template) {
  const results = []

  for (const tagMatch of template.matchAll(/<([A-Z][\w]*(?:\.[A-Z][\w]*)*)/g)) {
    const attributes = []
    let index = tagMatch.index + tagMatch[0].length

    while (index < template.length) {
      const char = template[index]
      if (char === '>' || char === '<') break
      if (/\s/.test(char)) {
        index++
        continue
      }
      if (char === '"' || char === '\'') {
        index = skipQuoted(template, index)
        continue
      }

      const nameMatch = /^[^\s=<>]+/.exec(template.slice(index))
      if (nameMatch === null) {
        index++
        continue
      }
      // The `/` of a self-closing tag is not an attribute.
      if (nameMatch[0] === '/') {
        index++
        continue
      }
      attributes.push(nameMatch[0])
      index += nameMatch[0].length

      if (template[index] === '=') {
        index++
        while (index < template.length && /\s/.test(template[index])) index++
        index = template[index] === '"' || template[index] === '\''
          ? skipQuoted(template, index)
          : skipBare(template, index)
      }
    }

    results.push({
      tag: tagMatch[1],
      attributes,
      line: template.slice(0, tagMatch.index).split('\n').length,
    })
  }

  return results
}

function skipQuoted(text, index) {
  const quote = text[index]
  index++
  while (index < text.length && text[index] !== quote) index++
  return index + 1
}

function skipBare(text, index) {
  while (index < text.length && !/[\s>]/.test(text[index])) index++
  return index
}

// ---------------------------------------------------------------------------
// Checks — each returns { message, hint?, line } with line 1-based in the block
// ---------------------------------------------------------------------------

function lineAt(code, index) {
  return code.slice(0, index).split('\n').length
}

/**
 * Named imports of the two published packages.
 *
 * Only `import { a, b } from '<package>'` is inspected. `import App from
 * './App.vue'`, `import x from 'vue'` and relative imports are out of scope —
 * the gate covers the framework's public API, not the reader's own files.
 */
export function checkImports(code, model) {
  const issues = []
  const pattern = /\bimport\s+(?:type\s+)?\{([^}]*)\}\s+from\s+['"](@thelacanians\/vue-native-(?:runtime|navigation))['"]/g

  for (const match of code.matchAll(pattern)) {
    const pkg = model.packages.get(match[2])
    // `names === null` means @vue/runtime-core was not installed, so the
    // runtime's `export * from '@vue/runtime-core'` could not be expanded.
    // Skipping beats reporting every Vue name as fabricated.
    if (pkg === undefined || pkg.names === null) continue

    const listStart = match.index + match[0].indexOf(match[1])
    let offset = 0
    for (const raw of match[1].split(',')) {
      const name = raw.trim().replace(/^type\s+/, '').split(/\s+as\s+/)[0].trim()
      const nameIndex = listStart + offset + raw.indexOf(name)
      offset += raw.length + 1
      if (!/^[A-Za-z_$][\w$]*$/.test(name)) continue
      if (pkg.names.has(name)) continue
      issues.push({
        line: lineAt(code, nameIndex),
        message: `"${name}" is not exported by ${match[2]}`,
      })
    }
  }

  return issues
}

/** Members destructured out of a known composable call. */
export function checkComposableMembers(code, model) {
  const issues = []
  const blank = blankLiterals(code)

  for (const match of blank.matchAll(/\b(?:const|let|var)\s*\{/g)) {
    const pattern = braces(blank, match.index + match[0].length - 1)
    if (pattern === null) continue

    // Optional `<T>` type arguments before the call parens: `useHttp<Product>()`.
    const call = /^\s*=\s*(?:await\s+)?([A-Za-z_$][\w$]*)\s*(?:<[^(){};]*>\s*)?\(/.exec(blank.slice(pattern.end + 1))
    if (call === null) continue

    const composable = model.composables.get(call[1])
    // FALSE POSITIVE guards: an unknown `useX()` is the reader's own composable
    // (guide/native-blocks.md defines `useAIChat`/`useCodeEditor` in generated
    // code), and an `open` contract is one whose return could not be fully
    // enumerated. Neither may be judged.
    if (composable === undefined || composable.open) continue

    for (const name of destructuredNames(pattern.body, originalOf(code, pattern))) {
      if (composable.keys.has(name)) continue
      issues.push({
        line: lineAt(code, match.index),
        message: `"${name}" is not returned by ${call[1]}() — it returns { ${[...composable.keys].sort().join(', ')} }`,
      })
    }
  }

  return issues
}

/** `router.<member>` and `route.<member>` references. */
export function checkRouterMembers(code, model) {
  const issues = []
  const blank = blankLiterals(code)

  for (const [name, allowed, typeName] of [
    ['router', model.routerMembers, 'RouterInstance'],
    ['route', model.routeMembers, 'RouteLocation'],
  ]) {
    if (allowed === null) continue

    // FALSE POSITIVE guard: a block that binds `router`/`route` to something
    // else is not talking about the navigation router. Every declaration of
    // these two names in the current docs tree comes from useRouter() /
    // createRouter() / useRoute(); 20 further blocks reference `router.` with no
    // local declaration at all because they continue a previous snippet, so
    // those are checked too.
    const declared = new RegExp(`\\b(?:const|let|var)\\s+${name}\\s*=`).exec(blank)
    if (declared !== null) {
      const initializer = blank.slice(declared.index + declared[0].length, declared.index + declared[0].length + 80)
      if (!/^\s*(?:useRouter|useParentRouter|createRouter|useRoute|createTabNavigator|createDrawerNavigator)\s*\(/.test(initializer)) continue
    }

    const memberPattern = new RegExp(`\\b${name}\\s*(?:\\?\\.)?\\.\\s*([A-Za-z_$][\\w$]*)`, 'g')
    for (const match of blank.matchAll(memberPattern)) {
      if (allowed.has(match[1])) continue
      issues.push({
        line: lineAt(code, match.index),
        message: `"${match[1]}" does not exist on ${typeName} — available: ${[...allowed].sort().join(', ')}`,
      })
    }
  }

  return issues
}

/** Props bound on a known component tag inside a template. */
export function checkComponentProps(template, model) {
  const issues = []

  for (const { tag, attributes, line } of extractTagAttributes(template)) {
    // FALSE POSITIVE guard: `VDrawer.Item` is registered under that dotted name,
    // so normalise before lookup.
    const contract = model.components.get(tag) ?? model.components.get(tag.replace(/\./g, ''))
    // Unknown PascalCase tags are the reader's own components (<UserProfile>,
    // <AIMessageView>), React Native "before" samples, or components built with
    // createNativeComponent()/native blocks (<VMapGL>, <VTextInput>). Only tags
    // this repo ships are judged. An `open` contract could not be enumerated.
    if (contract === undefined || contract.open) continue

    for (const attribute of attributes) {
      if (attribute.startsWith('...')) continue

      const directive = attribute.startsWith('@') || attribute.startsWith('#') || attribute.startsWith('v-')
      if (directive) {
        // `@event` and `#slot` assert nothing about props: an undeclared
        // listener simply becomes an `on<Event>` attr that the renderer turns
        // into addEventListener, so it can never be "wrong". `v-model` DOES
        // assert a prop (`modelValue`, or the `v-model:arg` argument).
        const modelMatch = /^v-model(?::([^\s.]+))?/.exec(attribute)
        if (modelMatch === null) continue
        const prop = modelMatch[1] === undefined ? 'modelValue' : camelize(modelMatch[1])
        if (isAcceptedProp(tag, prop, contract)) continue
        issues.push({
          line,
          message: `"${attribute}" binds the "${prop}" prop, which <${tag}> does not declare`,
          hint: describeAlternative(tag, prop, contract, model),
        })
        continue
      }

      const rawName = attribute.startsWith(':') ? attribute.slice(1) : attribute
      if (!/^[A-Za-z][\w-]*$/.test(rawName)) continue
      const prop = camelize(rawName)

      // Any `on*` prop holding a function becomes an event listener in the
      // renderer, so it is valid on every component by construction.
      if (/^on[A-Z]/.test(prop)) continue
      if (isAcceptedProp(tag, prop, contract)) continue

      issues.push({
        line,
        message: `<${tag}> does not declare a "${prop}" prop`,
        hint: describeAlternative(tag, prop, contract, model),
      })
    }
  }

  return issues
}

/**
 * Is `prop` part of `<tag>`'s accepted surface? Declared props, keys the
 * component forwards to its native tag, its `emits` (reachable as `:onEvent`),
 * Vue's own special attributes, the style-engine-wide accessibility props, and
 * the verified native aliases.
 */
function isAcceptedProp(tag, prop, contract) {
  if (VUE_SPECIAL_ATTRS.has(prop)) return true
  if (UNIVERSALLY_HANDLED_PROPS.has(prop)) return true
  if (contract.props.has(prop)) return true
  if (contract.emits.has(prop)) return true
  return NATIVE_PROP_ALIASES.has(`${tag}|${prop}`)
}

/**
 * Best-effort "did you mean" for an unknown prop: name the component that does
 * declare it, and the target component's own slots. This is what turns
 * `<VList :renderItem>` into "renderItem is declared by <VFlatList>; <VList>
 * takes an #item slot instead".
 */
function describeAlternative(tag, prop, contract, model) {
  const parts = []
  const owners = model.propOwners.get(prop)
  if (owners !== undefined) {
    const others = [...owners].filter(owner => owner !== tag).sort()
    if (others.length > 0) parts.push(`"${prop}" is declared by ${others.map(owner => `<${owner}>`).join(', ')}`)
  }
  if (contract.slots.size > 0) {
    parts.push(`<${tag}> takes ${[...contract.slots].sort().map(slot => `#${slot}`).join(', ')} slot(s) instead`)
  }
  return parts.length > 0 ? parts.join('; ') : undefined
}

/** Run every check over one Markdown document. */
export function checkMarkdown(relativePath, markdown, model) {
  const issues = []
  const blocks = extractCodeBlocks(markdown)
  let checkedSymbols = 0
  let checkedBlocks = 0

  for (const block of blocks) {
    if (block.ignored || (!block.parseAsScript && !block.parseAsTemplate)) continue
    checkedBlocks++

    const lines = block.code.split('\n')
    const found = []
    if (block.parseAsScript) {
      found.push(...checkImports(block.code, model))
      found.push(...checkComposableMembers(block.code, model))
      found.push(...checkRouterMembers(block.code, model))
    }
    if (block.parseAsTemplate) {
      found.push(...checkComponentProps(block.code, model))
    }

    for (const issue of found) {
      // FALSE POSITIVE guard: the escape hatch also works per line, so a block
      // can show one wrong line next to correct ones. A marker on the PREVIOUS
      // line only suppresses when that line is nothing but a comment — otherwise
      // `const { t } = useI18n() // ignore` would also silence the next line.
      const offending = lines[issue.line - 1] ?? ''
      const previous = lines[issue.line - 2] ?? ''
      if (offending.includes(IGNORE_MARKER)) continue
      if (previous.includes(IGNORE_MARKER) && /^\s*(?:\/\/|\/\*|\*|<!--)/.test(previous)) continue
      issues.push(`${relativePath}:${block.startLine + issue.line - 1}: ${issue.message}${issue.hint === undefined ? '' : ` — ${issue.hint}`}`)
    }

    // Every reference the checks looked at, passing or failing.
    checkedSymbols += countCheckedSymbols(block, model)
  }

  return { issues, checkedBlocks, checkedSymbols }
}

/** How many API references in a block were examined by the checks. */
function countCheckedSymbols(block, model) {
  let total = 0

  if (block.parseAsScript) {
    for (const match of block.code.matchAll(/\bimport\s+(?:type\s+)?\{[^}]*\}\s+from\s+['"](@thelacanians\/vue-native-(?:runtime|navigation))['"]/g)) {
      const pkg = model.packages.get(match[1])
      if (pkg === undefined || pkg.names === null) continue
      total += match[0].match(/\{([^}]*)\}/)[1].split(',').filter(name => name.trim().length > 0).length
    }
    total += countComposableMembers(block.code, model)
    total += countRouterMembers(block.code)
  }
  if (block.parseAsTemplate) {
    total += countComponentProps(block.code, model)
  }
  return total
}

function countComposableMembers(code, model) {
  const blank = blankLiterals(code)
  let total = 0
  for (const match of blank.matchAll(/\b(?:const|let|var)\s*\{/g)) {
    const pattern = braces(blank, match.index + match[0].length - 1)
    if (pattern === null) continue
    const call = /^\s*=\s*(?:await\s+)?([A-Za-z_$][\w$]*)\s*(?:<[^(){};]*>\s*)?\(/.exec(blank.slice(pattern.end + 1))
    if (call === null) continue
    const composable = model.composables.get(call[1])
    if (composable === undefined || composable.open) continue
    total += destructuredNames(pattern.body, originalOf(code, pattern)).length
  }
  return total
}

function countRouterMembers(code) {
  const blank = blankLiterals(code)
  let total = 0
  for (const name of ['router', 'route']) {
    const memberPattern = new RegExp(`\\b${name}\\s*(?:\\?\\.)?\\.\\s*[A-Za-z_$][\\w$]*`, 'g')
    for (const _ of blank.matchAll(memberPattern)) total++
  }
  return total
}

function countComponentProps(template, model) {
  let total = 0
  for (const { tag, attributes } of extractTagAttributes(template)) {
    const contract = model.components.get(tag) ?? model.components.get(tag.replace(/\./g, ''))
    if (contract === undefined || contract.open) continue
    for (const attribute of attributes) {
      if (attribute.startsWith('@') || attribute.startsWith('#')) continue
      if (attribute.startsWith('v-') && !attribute.startsWith('v-model')) continue
      const rawName = attribute.startsWith(':') ? attribute.slice(1) : attribute
      if (!/^[A-Za-z][\w-]*$/.test(rawName)) continue
      total++
    }
  }
  return total
}

// ---------------------------------------------------------------------------
// Model assembly
// ---------------------------------------------------------------------------

export async function buildApiModel(rootDir, options = {}) {
  const runtimeSource = await readFile(join(rootDir, 'packages/runtime/src/index.ts'), 'utf8')
  const navigationSource = await readFile(join(rootDir, 'packages/navigation/src/index.ts'), 'utf8')

  const vueExports = options.vueExports !== undefined
    ? options.vueExports
    : await collectVuePublicNames(rootDir)

  const runtimeNames = collectPackageExports(runtimeSource)
  const navigationNames = collectPackageExports(navigationSource)
  // The runtime's `export * from '@vue/runtime-core'` re-exports all of Vue.
  if (vueExports !== null) {
    for (const name of vueExports) runtimeNames.add(name)
  }

  const components = await collectComponentContracts(rootDir)
  const composables = await collectComposables(rootDir, new Set([...runtimeNames, ...navigationNames]))

  const routerBody = interfaceBody(navigationSource, 'RouterInstance')
  const routeBody = interfaceBody(navigationSource, 'RouteLocation')
  const entryBody = interfaceBody(navigationSource, 'RouteEntry')

  return {
    packages: new Map([
      [RUNTIME_PACKAGE, { names: vueExports === null ? null : runtimeNames }],
      [NAVIGATION_PACKAGE, { names: navigationNames }],
    ]),
    components,
    propOwners: buildPropOwners(components),
    composables,
    routerMembers: routerBody === null ? null : interfaceMembers(routerBody),
    // `useRoute()` returns `ComputedRef<RouteLocation>` and templates
    // auto-unwrap a top-level ref, so both `route.value.name` and
    // `route.params.id` are legitimate. A `route` variable can also hold a
    // RouteEntry from `router.stack`, so those members are accepted too.
    routeMembers: routeBody === null
      ? null
      : new Set([
        ...interfaceMembers(routeBody),
        ...(entryBody === null ? [] : interfaceMembers(entryBody)),
        'value',
      ]),
    vueResolved: vueExports !== null,
  }
}

export async function collectMarkdownFiles(docsDir) {
  const files = []
  async function walk(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      // `.temp`/`.cache` are VuePress build output — generated copies of the
      // same pages, so scanning them would double-report every issue.
      if (entry.isDirectory()) {
        if (['.temp', '.cache', 'node_modules', 'public'].includes(entry.name)) continue
        await walk(join(directory, entry.name))
      } else if (entry.name.endsWith('.md')) {
        files.push(join(directory, entry.name))
      }
    }
  }
  await walk(docsDir)
  return files.sort()
}

export async function checkDocsTree(rootDir, options = {}) {
  const docsDir = options.docsDir ?? join(rootDir, 'docs/src')
  const model = options.model ?? await buildApiModel(rootDir, options)
  const files = await collectMarkdownFiles(docsDir)

  const issues = []
  let checkedBlocks = 0
  let checkedSymbols = 0
  let skippedBlocks = 0
  let ignoredBlocks = 0

  for (const file of files) {
    const markdown = await readFile(file, 'utf8')
    const result = checkMarkdown(relative(rootDir, file), markdown, model)
    issues.push(...result.issues)
    checkedBlocks += result.checkedBlocks
    checkedSymbols += result.checkedSymbols
    for (const block of extractCodeBlocks(markdown)) {
      if (block.ignored) ignoredBlocks++
      else if (!block.parseAsScript && !block.parseAsTemplate) skippedBlocks++
    }
  }

  return {
    issues,
    stats: {
      files: files.length,
      checkedBlocks,
      skippedBlocks,
      ignoredBlocks,
      checkedSymbols,
      composables: model.composables.size,
      components: model.components.size,
      vueResolved: model.vueResolved,
    },
  }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

async function main() {
  const rootDir = resolve(fileURLToPath(new URL('..', import.meta.url)))
  const { issues, stats } = await checkDocsTree(rootDir)

  if (!stats.vueResolved) {
    console.error('warning: @vue/runtime-core could not be resolved, so named-import checks against the runtime package were skipped. Run `bun install`.')
  }

  if (issues.length > 0) {
    console.error(`Documentation contract drift detected (${issues.length}):`)
    for (const issue of issues) console.error(`  - ${issue}`)
    console.error(
      '\nEither fix the sample, or — if it is a deliberate counter-example — put '
      + `<!-- ${IGNORE_MARKER} --> on the line above the code fence.`,
    )
    process.exitCode = 1
    return
  }

  process.stdout.write(
    `Documentation matches the public API. Checked ${stats.files} markdown file(s), `
    + `${stats.checkedBlocks} code block(s) and ${stats.checkedSymbols} API reference(s) against `
    + `${stats.composables} composable(s) and ${stats.components} component(s); `
    + `${stats.skippedBlocks} non-code block(s) skipped.\n`,
  )
}

const invokedDirectly = process.argv[1] !== undefined
  && resolve(process.argv[1]) === fileURLToPath(import.meta.url)

if (invokedDirectly) {
  await main()
}
