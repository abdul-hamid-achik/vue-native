import { Command } from 'commander'
import { existsSync } from 'node:fs'
import { join } from 'node:path'
import pc from 'picocolors'
import { ConfigError, loadConfig, type ResolvedConfig } from '../config.js'
import { p } from '../ui.js'

const CONFIG_FILES = [
  'vue-native.config.ts',
  'vue-native.config.js',
  'vue-native.config.mjs',
] as const

export interface InspectPathPresence {
  present: boolean
  path: string
}

export interface InspectReport {
  schemaVersion: 1
  cwd: string
  config: {
    found: boolean
    path: string | null
    error: string | null
    name: string | null
    bundleId: string | null
    version: string | null
    ios: ResolvedConfig['ios'] | null
    android: ResolvedConfig['android'] | null
    macos: ResolvedConfig['macos'] | null
    plugins: string[]
  }
  native: {
    ios: InspectPathPresence
    android: InspectPathPresence
    macos: InspectPathPresence
  }
  bundle: {
    js: InspectPathPresence
  }
  generated: {
    ios: InspectPathPresence
    android: InspectPathPresence
    macos: InspectPathPresence
    typescript: InspectPathPresence
  }
}

function presence(cwd: string, relativePath: string): InspectPathPresence {
  const path = join(cwd, relativePath)
  return { present: existsSync(path), path }
}

function findConfigPath(cwd: string): string | null {
  for (const filename of CONFIG_FILES) {
    const candidate = join(cwd, filename)
    if (existsSync(candidate)) {
      return candidate
    }
  }
  return null
}

export async function collectInspectReport(cwd: string): Promise<InspectReport> {
  const configPath = findConfigPath(cwd)
  let resolved: ResolvedConfig | null = null
  let configError: string | null = null

  try {
    resolved = await loadConfig(cwd)
  } catch (error) {
    configError = error instanceof ConfigError
      ? error.message
      : error instanceof Error ? error.message : String(error)
  }

  return {
    schemaVersion: 1,
    cwd,
    config: {
      found: configPath !== null,
      path: configPath,
      error: configError,
      name: resolved?.name ?? null,
      bundleId: resolved?.bundleId ?? null,
      version: resolved?.version ?? null,
      ios: resolved?.ios ?? null,
      android: resolved?.android ?? null,
      macos: resolved?.macos ?? null,
      plugins: resolved?.plugins ?? [],
    },
    native: {
      ios: presence(cwd, 'ios'),
      android: presence(cwd, 'android'),
      macos: presence(cwd, 'macos'),
    },
    bundle: {
      js: presence(cwd, join('dist', 'vue-native-bundle.js')),
    },
    generated: {
      ios: presence(cwd, join('native', 'ios', 'VueNativeCore', 'Sources', 'VueNativeCore', 'GeneratedModules')),
      android: presence(cwd, join('native', 'android', 'VueNativeCore', 'src', 'main', 'kotlin', 'com', 'vuenative', 'core', 'GeneratedModules')),
      macos: presence(cwd, join('native', 'macos', 'VueNativeMacOS', 'Sources', 'VueNativeMacOS', 'GeneratedModules')),
      typescript: presence(cwd, join('app', 'generated')),
    },
  }
}

function formatPresence(item: InspectPathPresence): string {
  return item.present ? `present (${item.path})` : `missing (${item.path})`
}

export const inspectCommand = new Command('inspect')
  .description('Print a machine-readable snapshot of the current Vue Native project')
  .option('--json', 'print the inspect report as JSON')
  .action(async (options: { json?: boolean }) => {
    const report = await collectInspectReport(process.cwd())
    if (options.json) {
      console.log(JSON.stringify(report, null, 2))
      return
    }

    p.intro(pc.cyan('Vue Native — inspect'))
    if (report.config.error) {
      console.log(`  [err] config: ${report.config.error}`)
    } else if (report.config.found) {
      console.log(`  [ok] config: ${report.config.name} (${report.config.bundleId}) @ ${report.config.version}`)
    } else {
      console.log('  [warn] config: no vue-native.config.{ts,js,mjs} found')
    }
    console.log(`  [${report.native.ios.present ? 'ok' : 'warn'}] ios: ${formatPresence(report.native.ios)}`)
    console.log(`  [${report.native.android.present ? 'ok' : 'warn'}] android: ${formatPresence(report.native.android)}`)
    console.log(`  [${report.native.macos.present ? 'ok' : 'warn'}] macos: ${formatPresence(report.native.macos)}`)
    console.log(`  [${report.bundle.js.present ? 'ok' : 'info'}] bundle: ${formatPresence(report.bundle.js)}`)
    console.log(`  [${report.generated.typescript.present ? 'ok' : 'info'}] generated ts: ${formatPresence(report.generated.typescript)}`)
    p.outro(pc.dim('Use --json for the full report'))
  })
