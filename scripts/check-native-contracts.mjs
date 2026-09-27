import { readdir, readFile } from 'node:fs/promises'
import { join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(fileURLToPath(new URL('..', import.meta.url)))
const composablesDir = join(root, 'packages/runtime/src/composables')

const platforms = {
  android: {
    extension: '.kt',
    intentionalOmissions: new Map([
      ['DragDrop', 'Desktop-only drag-and-drop integration.'],
      ['FileDialog', 'Desktop-only native file picker integration.'],
      ['Menu', 'Desktop-only application and context menu integration.'],
      ['Window', 'Desktop-only window management integration.'],
    ]),
    registry: join(root, 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Modules/NativeModuleRegistry.kt'),
    moduleDirs: [
      join(root, 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Modules'),
    ],
  },
  ios: {
    extension: '.swift',
    intentionalOmissions: new Map([
      ['BackHandler', 'Android-only system back-button integration.'],
      ['DragDrop', 'Desktop-only drag-and-drop integration.'],
      ['FileDialog', 'Desktop-only native file picker integration.'],
      ['Http', 'Certificate pinning is exposed by the JavaScript fetch polyfill on Apple platforms.'],
      ['Menu', 'Desktop-only application and context menu integration.'],
      ['Window', 'Desktop-only window management integration.'],
    ]),
    registry: join(root, 'native/ios/VueNativeCore/Sources/VueNativeCore/Modules/NativeModuleRegistry.swift'),
    moduleDirs: [
      join(root, 'native/ios/VueNativeCore/Sources/VueNativeCore/Modules'),
    ],
  },
  macos: {
    extension: '.swift',
    intentionalOmissions: new Map([
      ['BackHandler', 'Android-only system back-button integration.'],
      ['BackgroundTask', 'Background task scheduling is currently mobile-only.'],
      ['Bluetooth', 'Bluetooth support is currently mobile-only.'],
      ['Calendar', 'Calendar support is currently mobile-only.'],
      ['Contacts', 'Contacts support is currently mobile-only.'],
      ['Http', 'Certificate pinning is exposed by the JavaScript fetch polyfill on Apple platforms.'],
      ['IAP', 'In-app purchases are currently mobile-only.'],
      ['OTA', 'Over-the-air bundle updates are currently mobile-only.'],
      ['Sensors', 'Motion sensor support is currently mobile-only.'],
      ['SocialAuth', 'Platform social sign-in providers are currently mobile-only.'],
    ]),
    registry: join(root, 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Modules/NativeModuleRegistry.swift'),
    moduleDirs: [
      join(root, 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Modules'),
      join(root, 'native/shared/VueNativeShared/Sources/VueNativeShared/Modules'),
    ],
  },
}

async function runtimeCalls() {
  const calls = new Map()
  const files = (await readdir(composablesDir)).filter(file => file.endsWith('.ts'))

  for (const file of files) {
    const source = await readFile(join(composablesDir, file), 'utf8')
    const invocation = /invokeNativeModule\(\s*(['"])([^'"]+)\1\s*,\s*(['"])([^'"]+)\3/g
    for (const match of source.matchAll(invocation)) {
      const [, , moduleName, , methodName] = match
      const methods = calls.get(moduleName) ?? new Set()
      methods.add(methodName)
      calls.set(moduleName, methods)
    }
  }

  return calls
}

async function findModuleSource(moduleName, platform) {
  const filename = `${moduleName}Module${platform.extension}`
  for (const directory of platform.moduleDirs) {
    try {
      return await readFile(join(directory, filename), 'utf8')
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error
    }
  }
  return null
}

function dispatchLabels(source, extension) {
  const labels = new Set()
  for (const line of source.split('\n')) {
    const trimmed = line.trim()
    const isDispatch = extension === '.kt'
      ? trimmed.includes('->')
      : trimmed.startsWith('case ') && trimmed.includes(':')
    if (!isDispatch) continue

    for (const match of trimmed.matchAll(/"([^"]+)"/g)) {
      labels.add(match[1])
    }
  }
  return labels
}

const calls = await runtimeCalls()
const missing = []

for (const [platformName, platform] of Object.entries(platforms)) {
  const registry = await readFile(platform.registry, 'utf8')
  for (const [moduleName, methods] of calls) {
    const source = await findModuleSource(moduleName, platform)
    const omissionReason = platform.intentionalOmissions.get(moduleName)

    if (source === null) {
      if (omissionReason === undefined) {
        missing.push(`${platformName}: ${moduleName} implementation is missing and is not an intentional omission`)
      }
      continue
    }

    if (omissionReason !== undefined) {
      missing.push(`${platformName}: ${moduleName} has an implementation; remove its stale intentional omission (${omissionReason})`)
    }

    const className = `${moduleName}Module`
    if (!new RegExp(`\\b${className}\\s*\\(`).test(registry)) {
      missing.push(`${platformName}: ${moduleName} implementation is not registered`)
      continue
    }

    const labels = dispatchLabels(source, platform.extension)
    for (const methodName of methods) {
      if (!labels.has(methodName)) {
        missing.push(`${platformName}: ${moduleName}.${methodName}`)
      }
    }
  }

  for (const [moduleName, reason] of platform.intentionalOmissions) {
    if (!calls.has(moduleName)) {
      missing.push(`${platformName}: ${moduleName} intentional omission is stale because the runtime no longer invokes it (${reason})`)
    }
    if (reason.trim().length === 0) {
      missing.push(`${platformName}: ${moduleName} intentional omission must include a reason`)
    }
  }
}

if (missing.length > 0) {
  console.error('Native module contract drift detected:')
  for (const contract of missing) console.error(`  - ${contract}`)
  process.exitCode = 1
} else {
  process.stdout.write('Native module dispatch contracts match the runtime calls.\n')
}

// ---------------------------------------------------------------------------
// Component contract parity
//
// The module pass above only ever read `packages/runtime/src/composables` and
// the three `Modules/NativeModuleRegistry.*` files. Nothing checked components,
// which is how a component could be exported from TypeScript, documented, and
// still render as nothing on one platform: `ComponentRegistry.createView` logs
// and returns nil for an unknown tag. This pass is data-driven — the expected
// tag set is extracted from the components' own render functions, not from a
// hand-maintained list, so it cannot drift the way the native registries' own
// `expectedTypes` test arrays did.
// ---------------------------------------------------------------------------

const componentsDir = join(root, 'packages/runtime/src/components')
const navigationEntry = join(root, 'packages/navigation/src/index.ts')

const componentPlatforms = {
  android: {
    registry: join(root, 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core/Components/ComponentRegistry.kt'),
    sourcesDir: join(root, 'native/android/VueNativeCore/src/main/kotlin/com/vuenative/core'),
    extension: '.kt',
    // Desktop-only components. Their TypeScript sources warn at runtime that
    // they render nothing on mobile, so the omission is deliberate.
    intentionalOmissions: new Map([
      ['VOutlineView', 'macOS-only sidebar/outline control (AppKit NSOutlineView).'],
      ['VSplitView', 'macOS-only split-view control (AppKit).'],
      ['VToolbar', 'macOS-only window toolbar (AppKit NSToolbar).'],
    ]),
  },
  ios: {
    registry: join(root, 'native/ios/VueNativeCore/Sources/VueNativeCore/Components/ComponentRegistry.swift'),
    sourcesDir: join(root, 'native/ios/VueNativeCore/Sources/VueNativeCore'),
    extension: '.swift',
    intentionalOmissions: new Map([
      ['VOutlineView', 'macOS-only sidebar/outline control (AppKit NSOutlineView).'],
      ['VSplitView', 'macOS-only split-view control (AppKit).'],
      ['VToolbar', 'macOS-only window toolbar (AppKit NSToolbar).'],
    ]),
  },
  macos: {
    registry: join(root, 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS/Components/ComponentRegistry.swift'),
    sourcesDir: join(root, 'native/macos/VueNativeMacOS/Sources/VueNativeMacOS'),
    extension: '.swift',
    intentionalOmissions: new Map(),
  },
}

/**
 * Tags the renderer emits itself rather than any component's render function.
 * Registered natively, so they must not be reported as unexplained.
 */
const rendererInternalTags = new Set(['__ROOT__'])

/**
 * Extract the balanced `{ ... }` body that follows `key:` at the top level of a
 * `defineComponent({ ... })` call. Regex alone cannot do this: nested object
 * literals (a prop declared as `{ type: Boolean, default: false }`) break any
 * non-greedy match.
 */
function extractObjectBody(source, key) {
  const start = source.indexOf(`${key}:`)
  if (start === -1) return null
  const open = source.indexOf('{', start)
  if (open === -1) return null

  let depth = 0
  for (let index = open; index < source.length; index++) {
    const char = source[index]
    if (char === '{') depth++
    else if (char === '}') {
      depth--
      if (depth === 0) return source.slice(open + 1, index)
    }
  }
  return null
}

/** Balanced `{ ... }` body starting at `open` (the index of the `{`). */
function balancedBody(source, open) {
  let depth = 0
  for (let index = open; index < source.length; index++) {
    const char = source[index]
    if (char === '{') depth++
    else if (char === '}') {
      depth--
      if (depth === 0) return source.slice(open + 1, index)
    }
  }
  return null
}

/**
 * Strip comments so JSDoc prose inside a `props:` block cannot be mistaken for
 * a prop name (a `Default: false` line in a doc comment otherwise parses as a
 * prop called `Default`). `://` is preserved so a URL default survives.
 */
function stripComments(source) {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/(^|[^:])\/\/[^\n]*/g, '$1 ')
}

/** Top-level keys of an object-literal body (depth-1 identifiers before a `:`). */
function topLevelKeys(body) {
  const keys = new Set()
  let depth = 0
  let pending = ''
  for (const char of body) {
    if (char === '{' || char === '[' || char === '(') depth++
    if (char === '}' || char === ']' || char === ')') depth--
    if (depth === 0 && char === ':') {
      const key = pending.trim().replace(/^['"]|['"]$/g, '').split(/\s/).pop()
      if (/^[A-Za-z_$][A-Za-z0-9_$]*$/.test(key)) keys.add(key)
      pending = ''
      continue
    }
    if (depth === 0 && char === ',') {
      pending = ''
      continue
    }
    pending += char
  }
  return keys
}

/**
 * Prop keys the component actually forwards to its native tag.
 *
 * Returns null when the render spreads (`h('VText', { ...props })`), which
 * forwards every declared prop — the caller then falls back to the declared set.
 * Otherwise returns the literal keys passed, because components legitimately
 * rename before emitting: `VSwitch` declares `modelValue` but sends `value`, and
 * `VAlertDialog` resolves `confirmText`/`cancelText` into `buttons`. Checking
 * declared names against native sources would flag both as dropped.
 *
 * `on*` keys are excluded: the renderer converts them to event names via
 * `toEventName`, so `onPress` reaches native as the `press` event, never as a
 * prop called `onPress`.
 */
function forwardedPropKeys(source, tag) {
  const callRe = new RegExp(`\\bh\\(\\s*(['"])${tag}\\1\\s*,\\s*\\{`, 'g')
  const match = callRe.exec(source)
  if (!match) return null

  const open = match.index + match[0].length - 1
  const body = balancedBody(source, open)
  if (body === null) return null
  if (body.includes('...')) return null

  return new Set(
    [...topLevelKeys(body)].filter(key => !/^on[A-Z]/.test(key)),
  )
}

/**
 * Collect every native tag a source file emits via `h('Tag', ...)`, plus the
 * props and events the component declares. A file that emits no tag is a pure
 * TypeScript composite (VTabBar, VDrawer, VTransition, KeepAlive, VSuspense) and
 * legitimately needs no native factory.
 */
async function componentContracts() {
  const contracts = new Map()
  const files = (await readdir(componentsDir)).filter(file => file.endsWith('.ts') && file !== 'index.ts')
  const sources = [...files.map(file => join(componentsDir, file)), navigationEntry]
  const loaded = new Map()

  for (const path of sources) {
    let source
    try {
      source = await readFile(path, 'utf8')
    } catch (error) {
      if (error?.code === 'ENOENT') continue
      throw error
    }
    loaded.set(path, source)

    for (const match of source.matchAll(/\bh\(\s*(['"])([A-Z][A-Za-z0-9_]*)\1/g)) {
      const tag = match[2]
      if (rendererInternalTags.has(tag)) continue
      if (!contracts.has(tag)) contracts.set(tag, { props: new Set(), emits: new Set() })
    }
  }

  // Props/emits are attributed only when a file emits exactly one tag. A
  // composite rendering VView + VText attributes nothing — a false negative,
  // never a false positive.
  for (const [, source] of loaded) {
    const tags = [...source.matchAll(/\bh\(\s*(['"])([A-Z][A-Za-z0-9_]*)\1/g)]
      .map(match => match[2])
      .filter(tag => !rendererInternalTags.has(tag))
    const uniqueTags = [...new Set(tags)]
    if (uniqueTags.length !== 1) continue

    const tag = uniqueTags[0]
    const contract = contracts.get(tag)
    if (!contract) continue

    const clean = stripComments(source)

    const forwarded = forwardedPropKeys(clean, tag)
    if (forwarded) {
      for (const key of forwarded) contract.props.add(key)
    } else {
      const propsBody = extractObjectBody(clean, 'props')
      if (propsBody) {
        for (const key of topLevelKeys(propsBody)) {
          if (!/^on[A-Z]/.test(key)) contract.props.add(key)
        }
      }
    }

    const emitsMatch = /emits:\s*\[([^\]]*)\]/.exec(clean)
    if (emitsMatch) {
      for (const match of emitsMatch[1].matchAll(/(['"])([^'"]+)\1/g)) {
        // `update:modelValue` is Vue's v-model convention: the component emits
        // it from its own handler in TypeScript, translating a native event.
        if (match[2].startsWith('update:')) continue
        contract.emits.add(match[2])
      }
    }
  }

  return contracts
}

async function collectSourceText(directory, extension) {
  const chunks = []
  async function walk(current) {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      const path = join(current, entry.name)
      if (entry.isDirectory()) {
        await walk(path)
      } else if (entry.name.endsWith(extension)) {
        chunks.push(await readFile(path, 'utf8'))
      }
    }
  }
  await walk(directory)
  return chunks.join('\n')
}

/**
 * Props and events that are resolved in TypeScript and deliberately never reach
 * a native factory. Each entry needs a reason so the exception stays honest.
 */
const tsResolvedProps = new Map([
  ['style', 'Applied through the bridge style ops, not as a component prop.'],
])

const componentContractsMap = await componentContracts()
const componentDrift = []

/**
 * Known prop/event gaps, baselined so this gate can block NEW drift today
 * instead of waiting for 33 native fixes.
 *
 * This list must only ever shrink. Each entry is a prop or event that Vue
 * Native accepts and silently discards on that platform — the framework tells
 * the developer nothing, which is the worst failure mode available. An entry
 * that stops being true fails the check as stale, so fixing the underlying gap
 * forces the baseline to be updated in the same change.
 *
 * Key format: `<platform>|<Tag>|prop:<name>` or `<platform>|<Tag>|event:<name>`.
 */
const baselinedComponentGaps = new Set([
  // testID is declared on five components and implemented on no platform, so
  // there is currently no way to address a native view from a test.
  'android|VView|prop:testID',
  'android|VImage|prop:testID',
  'android|VKeyboardAvoiding|prop:testID',
  'android|VSVG|prop:testID',
  'android|VVideo|prop:testID',
  'ios|VView|prop:testID',
  'ios|VImage|prop:testID',
  'ios|VKeyboardAvoiding|prop:testID',
  'ios|VSVG|prop:testID',
  'ios|VVideo|prop:testID',
  'macos|VView|prop:testID',
  'macos|VImage|prop:testID',
  'macos|VKeyboardAvoiding|prop:testID',
  'macos|VSVG|prop:testID',
  'macos|VVideo|prop:testID',
  // Text selection is unimplemented everywhere despite being documented.
  'android|VText|prop:selectable',
  'ios|VText|prop:selectable',
  'macos|VText|prop:selectable',
  'android|VScrollView|prop:contentContainerStyle',
  'ios|VScrollView|prop:contentContainerStyle',
  'android|VScrollView|prop:pagingEnabled',
  'android|VActivityIndicator|prop:hidesWhenStopped',
  'android|VVideo|prop:controls',
  'android|VVideo|prop:poster',
  'ios|VVideo|prop:poster',
  'macos|VVideo|prop:controls',
  'macos|VVideo|prop:poster',
  'macos|VCheckbox|prop:checkColor',
  'macos|VStatusBar|prop:barStyle',
  // autoFocus is implemented on macOS only (VInputFactory.swift handles it and
  // VInputTextField honours it on viewDidMoveToWindow). iOS and Android ignore
  // it, so the prop is declared but inert there.
  'ios|VInput|prop:autoFocus',
  'android|VInput|prop:autoFocus',
  // Pull-to-refresh is a no-op stub on macOS, so the `refreshing` prop does not
  // exist there. `VScrollView`'s `refresh` EVENT is deliberately not baselined:
  // macOS now refuses it loudly (DEBUG warning plus a `__refreshUnsupported`
  // internal prop), which puts the literal string "refresh" in the sources, so
  // this string-presence heuristic can no longer distinguish "handled" from
  // "warned about and ignored". The remaining debt is tracked in
  // docs/src/components/VScrollView.md instead.
  'macos|VScrollView|prop:refreshing',
  'macos|VRefreshControl|prop:refreshing',
  'macos|VAlertDialog|event:confirm',
])

const baselinedSeen = new Set()

for (const [platformName, platform] of Object.entries(componentPlatforms)) {
  const registrySource = await readFile(platform.registry, 'utf8')
  const registered = new Set(
    [...registrySource.matchAll(/register\(\s*"([^"]+)"/g)].map(match => match[1]),
  )
  const platformSources = await collectSourceText(platform.sourcesDir, platform.extension)

  /**
   * Record a prop/event gap. Baselined entries are counted but not reported;
   * everything else is a hard failure.
   */
  const recordGap = (tag, kind, name, detail) => {
    const key = `${platformName}|${tag}|${kind}:${name}`
    if (baselinedComponentGaps.has(key)) {
      baselinedSeen.add(key)
      return
    }
    componentDrift.push(`${platformName}: <${tag}> ${kind} "${name}" ${detail}`)
  }

  for (const [tag, contract] of componentContractsMap) {
    const omissionReason = platform.intentionalOmissions.get(tag)

    if (!registered.has(tag)) {
      if (omissionReason === undefined) {
        componentDrift.push(
          `${platformName}: <${tag}> is emitted by the runtime but is not registered in ComponentRegistry`,
        )
      }
      continue
    }

    if (omissionReason !== undefined) {
      componentDrift.push(
        `${platformName}: <${tag}> is registered; remove its stale intentional omission (${omissionReason})`,
      )
    }

    // A declared prop that appears nowhere in the platform's sources cannot be
    // handled, so the bridge silently drops it. Searched platform-wide rather
    // than per-factory because a prop may legitimately be consumed by a shared
    // helper (TouchableView, StyleEngine) instead of the factory itself.
    //
    // KNOWN LIMITATION: platform-wide search only catches DISTINCTIVE names. A
    // common name like `backgroundColor`, `style` or `value` appears somewhere in
    // every platform (StyleEngine, unrelated factories), so a component that
    // ignores it passes silently — `VStatusBar.backgroundColor` is Android-only
    // and is not reported here. Per-factory search would catch those but would
    // also false-positive on every prop legitimately handled by a shared helper.
    // Treat this check as a floor, not a ceiling: it reliably catches props whose
    // names are specific to one component (`selectable`, `testID`,
    // `hidesWhenStopped`, `contentContainerStyle`), and nothing more.
    for (const prop of contract.props) {
      if (tsResolvedProps.has(prop)) continue
      if (!platformSources.includes(`"${prop}"`)) {
        recordGap(tag, 'prop', prop, `is declared in TypeScript but the string "${prop}" appears nowhere in the ${platformName} sources — it is silently dropped`)
      }
    }

    for (const eventName of contract.emits) {
      if (!platformSources.includes(`"${eventName}"`)) {
        recordGap(tag, 'event', eventName, `is declared in TypeScript but the string "${eventName}" appears nowhere in the ${platformName} sources — it can never fire`)
      }
    }
  }

  for (const tag of registered) {
    if (rendererInternalTags.has(tag)) continue
    if (!componentContractsMap.has(tag)) {
      componentDrift.push(
        `${platformName}: ComponentRegistry registers <${tag}> but no runtime component emits it`,
      )
    }
  }

  for (const [tag, reason] of platform.intentionalOmissions) {
    if (!componentContractsMap.has(tag)) {
      componentDrift.push(
        `${platformName}: <${tag}> intentional omission is stale because the runtime no longer emits it (${reason})`,
      )
    }
    if (reason.trim().length === 0) {
      componentDrift.push(`${platformName}: <${tag}> intentional omission must include a reason`)
    }
  }
}

// A baselined gap that is no longer true means someone fixed it. Fail so the
// baseline shrinks in the same change instead of quietly rotting.
for (const key of baselinedComponentGaps) {
  if (!baselinedSeen.has(key)) {
    componentDrift.push(`stale baseline entry "${key}" — the gap is fixed; remove it from baselinedComponentGaps`)
  }
}

if (componentDrift.length > 0) {
  console.error(`\nComponent contract drift detected (${componentDrift.length}):`)
  for (const contract of componentDrift) console.error(`  - ${contract}`)
  process.exitCode = 1
} else {
  process.stdout.write(
    `Component registries match the runtime. ${baselinedSeen.size} known prop/event gap(s) `
    + 'are baselined in check-native-contracts.mjs and must only shrink.\n',
  )
}
