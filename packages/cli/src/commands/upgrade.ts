import { Command } from 'commander'
import { existsSync, readFileSync } from 'node:fs'
import { cp, readFile, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { execFileSync } from 'node:child_process'
import cliPackage from '../../package.json'
import { ConfigError } from '../config.js'
import { p } from '../ui.js'
import { getCliPackageDir } from './create.js'

/** Packages in the changesets `fixed` group plus the separately versioned ones. */
const JS_PACKAGES = [
  '@thelacanians/vue-native-runtime',
  '@thelacanians/vue-native-navigation',
  '@thelacanians/vue-native-vite-plugin',
  '@thelacanians/vue-native-cli',
  '@thelacanians/vue-native-codegen',
  '@thelacanians/vue-native-sfc-parser',
]

const STAMP_RELATIVE_PATH = join('native', '.vue-native-version')

interface VersionStamp {
  schema?: number
  cliVersion?: string
  frameworkVersion?: string
  jsDependencyRange?: string
}

interface FilePatch {
  relativePath: string
  content: string
  summary: string
}

function insertAfter(lines: string[], anchor: (line: string) => boolean, insertion: string[]): string[] | null {
  const at = lines.findIndex(anchor)
  if (at === -1) return null
  return [...lines.slice(0, at + 1), ...insertion, ...lines.slice(at + 1)]
}

function insertBefore(lines: string[], anchor: (line: string) => boolean, insertion: string[]): string[] | null {
  const at = lines.findIndex(anchor)
  if (at === -1) return null
  return [...lines.slice(0, at), ...insertion, ...lines.slice(at)]
}

/**
 * Host-side wiring for the optional `<VSVG>` add-on products.
 *
 * Re-vendoring `native/` brings the sibling `VueNativeCoreSVG` package into an
 * upgraded project, but a host that linked the old single-product core keeps
 * building WITHOUT it — `<VSVG>` silently degrades to a logged error and a
 * blank view. The scaffold writes this wiring for new projects; upgrade must
 * add it to existing ones. Patches are additive and idempotent: every edit is
 * skipped when its marker is already present, and a file whose anchors do not
 * match (hand-edited host) is left alone with a warning instead of a guess.
 */
function svgAddonPatches(projectDir: string): { patches: FilePatch[], warnings: string[] } {
  const patches: FilePatch[] = []
  const warnings: string[] = []

  function patch(relativePath: string, edit: (lines: string[]) => { lines: string[], summary: string } | null): void {
    const absolute = join(projectDir, relativePath)
    if (!existsSync(absolute)) return
    const original = readFileSync(absolute, 'utf8')
    const result = edit(original.split('\n'))
    if (result === null) {
      warnings.push(`${relativePath}: recognised anchors not found; add the <VSVG> product and register() call by hand`)
      return
    }
    patches.push({ relativePath, content: result.lines.join('\n'), summary: result.summary })
  }

  patch(join('ios', 'project.yml'), (lines) => {
    if (lines.some(line => line.includes('VueNativeCoreSVG'))) return { lines, summary: '' }
    const withPackage = insertAfter(lines, line => line.trim() === 'path: ../native/ios/VueNativeCore', [
      '  VueNativeCoreSVG:',
      '    path: ../native/ios/VueNativeCoreSVG',
    ])
    if (withPackage === null) return null
    const withProduct = insertAfter(withPackage, line => line.trim() === 'product: VueNativeCore', [
      '      - package: VueNativeCoreSVG',
      '        product: VueNativeCoreSVG',
    ])
    if (withProduct === null) return null
    return { lines: withProduct, summary: 'link the VueNativeCoreSVG product' }
  })

  patch(join('ios', 'Sources', 'AppDelegate.swift'), (lines) => {
    if (lines.some(line => line.includes('VueNativeCoreSVG.register()'))) return { lines, summary: '' }
    const withImport = insertAfter(lines, line => line.trim() === 'import UIKit', ['import VueNativeCoreSVG'])
    if (withImport === null) return null
    const withCall = insertAfter(withImport, line => line.trim() === ') -> Bool {', ['        VueNativeCoreSVG.register()'])
    if (withCall === null) return null
    return { lines: withCall, summary: 'call VueNativeCoreSVG.register() at launch' }
  })

  patch(join('macos', 'project.yml'), (lines) => {
    if (lines.some(line => line.includes('VueNativeMacOSSVG'))) return { lines, summary: '' }
    const withProduct = insertAfter(lines, line => line.trim() === 'product: VueNativeMacOS', [
      '      - package: VueNativeMacOS',
      '        product: VueNativeMacOSSVG',
    ])
    if (withProduct === null) return null
    return { lines: withProduct, summary: 'link the VueNativeMacOSSVG product' }
  })

  patch(join('macos', 'Sources', 'AppDelegate.swift'), (lines) => {
    if (lines.some(line => line.includes('VueNativeMacOSSVG.register()'))) return { lines, summary: '' }
    const withImport = insertAfter(lines, line => line.trim() === 'import VueNativeMacOS', ['import VueNativeMacOSSVG'])
    if (withImport === null) return null
    // Before super: super creates the window controller and mounts the bundle.
    const withCall = insertBefore(withImport, line => line.includes('super.applicationDidFinishLaunching'), [
      '        VueNativeMacOSSVG.register()',
    ])
    if (withCall === null) return null
    return { lines: withCall, summary: 'call VueNativeMacOSSVG.register() before super' }
  })

  return { patches: patches.filter(entry => entry.summary !== ''), warnings }
}

function readStamp(projectDir: string): VersionStamp | null {
  const stampPath = join(projectDir, STAMP_RELATIVE_PATH)
  if (!existsSync(stampPath)) return null
  try {
    return JSON.parse(readFileSync(stampPath, 'utf8')) as VersionStamp
  } catch {
    return null
  }
}

/**
 * Local edits inside the vendored `native/` tree, when the project is a git
 * repository. Re-vendoring overwrites that tree, so they must be surfaced
 * before anything is written; outside a repository there is nothing to compare
 * against and the stamp's version distance is the only signal.
 */
function nativeLocalChanges(projectDir: string): string[] | null {
  try {
    const out = execFileSync('git', ['status', '--porcelain', '--', 'native'], {
      cwd: projectDir,
      stdio: ['ignore', 'pipe', 'ignore'],
      encoding: 'utf8',
    })
    return out.split('\n').map(line => line.trim()).filter(Boolean)
  } catch {
    // Not a repository, or git unavailable: no comparison is possible.
    return null
  }
}

export const upgradeCommand = new Command('upgrade')
  .description(
    'Re-vendor the native framework tree and point the JS dependencies at this CLI\'s version',
  )
  .option('--dry-run', 'report what would change without writing anything')
  .option(
    '--force',
    'upgrade even when native/ has local modifications or no version stamp',
  )
  .action(async (options: { dryRun?: boolean, force?: boolean }) => {
    const cwd = process.cwd()
    const targetVersion = cliPackage.version

    if (!existsSync(join(cwd, 'native'))) {
      throw new ConfigError(
        'No native/ directory here, so this does not look like a Vue Native '
        + 'project. Run upgrade from the project root (the directory holding '
        + 'vue-native.config.ts).',
      )
    }

    const stamp = readStamp(cwd)
    const fromVersion = stamp?.frameworkVersion ?? null

    p.intro('Vue Native — Upgrade')

    if (fromVersion === null) {
      // Projects scaffolded before 0.21.0 have no stamp, so a stale vendored
      // tree is indistinguishable from a locally edited one. Refuse by default
      // rather than silently destroying work that cannot be told apart.
      if (!options.force) {
        throw new ConfigError(
          'native/.vue-native-version is missing, so this project predates version '
          + 'stamping (added in 0.21.0) and upgrade cannot tell a stale vendored '
          + 'tree from a locally edited one. Re-run with --force to re-vendor '
          + 'anyway, or scaffold a fresh project and copy app/ across — with no '
          + 'stamp there is no safe automatic path.',
        )
      }
      p.log.warn('No version stamp found; proceeding because --force was given.')
    } else if (fromVersion === targetVersion) {
      p.log.info(`Already at ${targetVersion}; nothing to do.`)
      p.outro('Done')
      return
    } else {
      p.log.info(`Upgrading ${fromVersion} → ${targetVersion}`)
    }

    const changes = nativeLocalChanges(cwd)
    if (changes !== null && changes.length > 0 && !options.force) {
      throw new ConfigError(
        `native/ has ${changes.length} local modification(s) and re-vendoring would `
        + 'overwrite them. Commit or stash them first, or re-run with --force to '
        + 'discard them. First few:\n  '
        + changes.slice(0, 5).join('\n  '),
      )
    }
    if (changes !== null && changes.length > 0) {
      p.log.warn(`--force: overwriting ${changes.length} local modification(s) in native/`)
    }

    const packageJsonPath = join(cwd, 'package.json')
    let packageJson: { dependencies?: Record<string, string>, devDependencies?: Record<string, string> } = {}
    if (existsSync(packageJsonPath)) {
      packageJson = JSON.parse(await readFile(packageJsonPath, 'utf8'))
    }
    const dependencyEdits: string[] = []
    for (const section of ['dependencies', 'devDependencies'] as const) {
      const deps = packageJson[section]
      if (!deps) continue
      for (const name of JS_PACKAGES) {
        if (deps[name] !== undefined && deps[name] !== `^${targetVersion}`) {
          dependencyEdits.push(`${section}.${name}: ${deps[name]} → ^${targetVersion}`)
        }
      }
    }

    const svgWiring = svgAddonPatches(cwd)

    const plan = [
      `re-vendor native/ from the CLI package (${targetVersion})`,
      `rewrite ${STAMP_RELATIVE_PATH}`,
      ...dependencyEdits.map(edit => `package.json ${edit}`),
      ...svgWiring.patches.map(entry => `${entry.relativePath}: ${entry.summary}`),
    ]
    for (const line of plan) p.log.step(`would ${line}`)
    for (const warning of svgWiring.warnings) p.log.warn(warning)

    if (options.dryRun) {
      p.outro('Dry run: nothing written.')
      return
    }

    // Overwrite rather than delete-then-copy: deleting native/ would also drop
    // files the user added inside it, which --force did not consent to. The
    // trade-off is that a file the framework RENAMED upstream lingers until
    // removed by hand; the summary says so.
    await cp(join(getCliPackageDir(), 'native'), join(cwd, 'native'), { recursive: true })

    for (const section of ['dependencies', 'devDependencies'] as const) {
      const deps = packageJson[section]
      if (!deps) continue
      for (const name of JS_PACKAGES) {
        if (deps[name] !== undefined) deps[name] = `^${targetVersion}`
      }
    }
    if (existsSync(packageJsonPath) || dependencyEdits.length > 0) {
      await writeFile(packageJsonPath, `${JSON.stringify(packageJson, null, 2)}\n`)
    }

    await writeFile(
      join(cwd, STAMP_RELATIVE_PATH),
      `${JSON.stringify({
        schema: 1,
        cliVersion: targetVersion,
        frameworkVersion: targetVersion,
        jsDependencyRange: `^${targetVersion}`,
        upgradedFrom: fromVersion ?? 'unknown (no stamp)',
        upgradedAt: new Date().toISOString(),
      }, null, 2)}\n`,
    )

    for (const entry of svgWiring.patches) {
      await writeFile(join(cwd, entry.relativePath), entry.content)
    }

    const repository = typeof cliPackage.repository === 'object' && cliPackage.repository !== null
      ? (cliPackage.repository as { url?: string }).url
      : undefined
    p.log.warn(
      'Files the framework renamed or deleted upstream are NOT removed by upgrade; '
      + 'review `git status` afterwards. Run `bun install`, then read the release '
      + `notes for breaking changes: ${repository ?? 'the repository releases page'}`,
    )
    p.outro(`Upgraded to ${targetVersion}.`)
  })
