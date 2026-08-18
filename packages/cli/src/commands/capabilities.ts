import { Command } from 'commander'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import pc from 'picocolors'
import {
  BUILT_IN_COMPONENT_NAMES,
  FRAMEWORK_LIMITATIONS,
  NATIVE_MODULE_CAPABILITIES,
  type CapabilityLimitation,
  type ComponentCapability,
  type ModuleCapability,
} from '../capabilities-manifest.js'
import { p } from '../ui.js'

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
    components: BUILT_IN_COMPONENT_NAMES.map(name => ({
      name,
      platforms: { ios: 'full', android: 'full', macos: 'full' },
    })),
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
