import { Command } from 'commander'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import pc from 'picocolors'
import {
  BUILT_IN_COMPONENT_NAMES,
  FRAMEWORK_LIMITATIONS,
  NATIVE_MODULE_CAPABILITIES,
  OPTIONAL_PRODUCT_COMPONENT_NOTES,
  type CapabilityLimitation,
  type ComponentCapability,
  type HostPlatform,
  type ModuleCapability,
  type PlatformSupport,
} from '../capabilities-manifest.js'
import { p } from '../ui.js'

const HOST_PLATFORMS: HostPlatform[] = ['ios', 'android', 'macos']

/** Each platform's ComponentRegistry, relative to a `native/` tree root. */
const COMPONENT_REGISTRY_PATHS: Record<HostPlatform, string> = {
  ios: 'ios/VueNativeCore/Sources/VueNativeCore/Components/ComponentRegistry.swift',
  android: 'android/VueNativeCore/src/main/kotlin/com/vuenative/core/Components/ComponentRegistry.kt',
  macos: 'macos/VueNativeMacOS/Sources/VueNativeMacOS/Components/ComponentRegistry.swift',
}

/**
 * Components that ARE registered on a platform but whose factory is an explicit
 * no-op or pass-through. Registration alone does not mean the component does
 * anything, so reporting these as `full` would keep lying — just less often.
 *
 * Hand-maintained with a reason per entry, the same discipline
 * `scripts/check-native-contracts.mjs` applies to intentional omissions. Each
 * reason quotes the factory's own doc comment so it can be re-verified.
 */
const STUB_COMPONENTS: Record<string, Partial<Record<HostPlatform, string>>> = {
  VRefreshControl: {
    macos: 'VRefreshControlFactory.swift: "stub on macOS … pull-to-refresh does not exist on macOS".',
  },
  VSafeArea: {
    macos: 'VSafeAreaFactory.swift: "pass-through container on macOS" — applies no insets.',
  },
  VKeyboardAvoiding: {
    macos: 'VKeyboardAvoidingFactory.swift: "pass-through container on macOS" — no on-screen keyboard.',
  },
  VStatusBar: {
    macos: 'VStatusBarFactory.swift: "no-op on macOS" — AppKit has no status bar.',
  },
}

/**
 * Components implemented entirely in TypeScript that render down to other
 * components, so they have no native factory on any platform and must not be
 * reported as `unsupported`.
 *
 * Verified by checking that the source file emits no `h('<OwnName>')`: VFlatList
 * renders `VList`, VDrawer/VDrawerItem/VDrawerSection and VTransition/
 * VTransitionGroup render VView, and VTabBar/KeepAlive/VSuspense are Vue-level
 * constructs. `scripts/check-native-contracts.mjs` derives the same distinction
 * independently from the render calls.
 */
const RUNTIME_COMPOSED_COMPONENTS = new Set([
  'VFlatList',
  'VTabBar',
  'VDrawer',
  'VDrawerItem',
  'VDrawerSection',
  'VTransition',
  'VTransitionGroup',
  'KeepAlive',
  'VSuspense',
])

/**
 * Locate a `native/` tree to read component registries from.
 *
 * The CLI package ships `native/` in its published `files`, so the bundled copy
 * works in a plain npm install; a scaffolded project's own vendored `native/`
 * takes precedence because that is the code the app actually builds against.
 */
function findNativeRoot(): string | null {
  const here = dirname(fileURLToPath(import.meta.url))
  const candidates = [
    join(process.cwd(), 'native'),
    join(here, '..', 'native'),
    join(here, '..', '..', 'native'),
    join(here, '..', '..', '..', 'native'),
  ]
  for (const candidate of candidates) {
    if (existsSync(join(candidate, COMPONENT_REGISTRY_PATHS.ios))) return candidate
  }
  return null
}

/** Tags a platform's ComponentRegistry actually registers, or null if unreadable. */
function readRegisteredTags(nativeRoot: string | null, platform: HostPlatform): Set<string> | null {
  if (nativeRoot === null) return null
  const path = join(nativeRoot, COMPONENT_REGISTRY_PATHS[platform])
  if (!existsSync(path)) return null

  const tags = new Set<string>()
  for (const match of readFileSync(path, 'utf8').matchAll(/register\(\s*"([^"]+)"/g)) {
    // The renderer's synthetic root container is not a user-facing component.
    if (match[1] !== '__ROOT__') tags.add(match[1])
  }
  return tags
}

export interface CapabilitiesReport {
  schemaVersion: 1
  framework: {
    name: 'vue-native'
    cliVersion: string
    vueVersion: string
  }
  platforms: {
    ios: { minOs: string, host: string, layout: string }
    android: { minOs: string, host: string, layout: string }
    macos: { minOs: string, host: string, layout: string }
  }
  components: ComponentCapability[]
  modules: ModuleCapability[]
  limitations: CapabilityLimitation[]
}

function readCliPackage(): { version: string, vueNative?: { vueVersion?: string } } {
  const here = dirname(fileURLToPath(import.meta.url))
  const candidates = [
    join(here, '..', 'package.json'),
    join(here, '..', '..', 'package.json'),
  ]
  for (const candidate of candidates) {
    if (existsSync(candidate)) {
      return JSON.parse(readFileSync(candidate, 'utf8')) as {
        version: string
        vueNative?: { vueVersion?: string }
      }
    }
  }
  return { version: '0.0.0', vueNative: { vueVersion: '3.5.40' } }
}

const pkg = readCliPackage()

export function collectCapabilitiesReport(): CapabilitiesReport {
  const nativeRoot = findNativeRoot()
  const registered = new Map<HostPlatform, Set<string> | null>(
    HOST_PLATFORMS.map(platform => [platform, readRegisteredTags(nativeRoot, platform)]),
  )

  return {
    schemaVersion: 1,
    framework: {
      name: 'vue-native',
      cliVersion: pkg.version,
      vueVersion: pkg.vueNative?.vueVersion ?? '3.5.40',
    },
    platforms: {
      ios: { minOs: '16.0', host: 'UIKit', layout: 'Yoga' },
      android: { minOs: '21', host: 'Android Views', layout: 'FlexboxLayout' },
      macos: { minOs: '15.0', host: 'AppKit', layout: 'LayoutNode' },
    },
    // Derived from each platform's ComponentRegistry rather than asserted. This
    // used to hardcode `{ ios: 'full', android: 'full', macos: 'full' }` for all
    // 40 names, which made the manifest actively wrong for the macOS-only
    // VToolbar / VSplitView / VOutlineView — and the manifest is the intended
    // source for generated docs tables and editor metadata, so the lie would
    // have been laundered into every generated page.
    components: BUILT_IN_COMPONENT_NAMES.map((name) => {
      const platforms = {} as Record<HostPlatform, PlatformSupport>
      for (const platform of HOST_PLATFORMS) {
        if (RUNTIME_COMPOSED_COMPONENTS.has(name)) {
          platforms[platform] = 'runtime-composed'
          continue
        }
        const tags = registered.get(platform)
        if (tags === null || tags === undefined) {
          platforms[platform] = 'unknown'
        } else if (!tags.has(name)) {
          platforms[platform] = 'unsupported'
        } else {
          platforms[platform] = STUB_COMPONENTS[name]?.[platform] ? 'stub' : 'full'
        }
      }
      const note = OPTIONAL_PRODUCT_COMPONENT_NOTES[name]
      return note === undefined ? { name, platforms } : { name, platforms, note }
    }),
    modules: NATIVE_MODULE_CAPABILITIES,
    limitations: FRAMEWORK_LIMITATIONS,
  }
}

export const capabilitiesCommand = new Command('capabilities')
  .description('Print the framework capability manifest (components, modules, known limits)')
  .option('--json', 'print the capability manifest as JSON')
  .action((options: { json?: boolean }) => {
    const report = collectCapabilitiesReport()
    if (options.json) {
      console.log(JSON.stringify(report, null, 2))
      return
    }

    p.intro(pc.cyan('Vue Native — capabilities'))
    console.log(`  framework ${report.framework.cliVersion} / Vue ${report.framework.vueVersion}`)
    console.log(`  components ${report.components.length}`)
    console.log(`  modules ${report.modules.length}`)
    console.log('  limitations:')
    for (const item of report.limitations) {
      console.log(`    - ${item.id}: ${item.message}`)
    }
    p.outro(pc.dim('Use --json for the full manifest'))
  })
