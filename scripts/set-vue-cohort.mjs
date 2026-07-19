import {
  existsSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import {
  canonicalPeerRange,
  cohortPackagesForVersion,
  VAPOR_COHORT_PACKAGES,
  VUE_COHORT_PACKAGES,
} from './check-vue-cohort.mjs'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const allCohortPackages = new Set([
  ...VUE_COHORT_PACKAGES,
  ...VAPOR_COHORT_PACKAGES,
])
const dependencySections = [
  'dependencies',
  'devDependencies',
  'optionalDependencies',
]

function usage() {
  process.stdout.write(
    'Usage: bun scripts/set-vue-cohort.mjs <version> [--dry-run]\n',
  )
}

function parseArgs(argv) {
  if (argv.includes('--help') || argv.includes('-h')) {
    usage()
    process.exit(0)
  }

  const unknownFlags = argv.filter(
    argument => argument.startsWith('-') && argument !== '--dry-run',
  )
  if (unknownFlags.length > 0) {
    throw new Error(`Unknown argument: ${unknownFlags[0]}`)
  }

  const dryRun = argv.includes('--dry-run')
  const positional = argv.filter(argument => !argument.startsWith('-'))
  if (positional.length !== 1) {
    usage()
    throw new Error('Provide exactly one Vue version.')
  }

  const version = positional[0]
  const match = /^(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?$/.exec(version)
  if (!match) {
    throw new Error(`Invalid Vue version: ${version}`)
  }

  return {
    dryRun,
    version,
  }
}

function workspaceManifestPaths() {
  const paths = [join(root, 'package.json')]

  for (const workspaceRoot of ['packages', 'examples', 'tools']) {
    const directory = join(root, workspaceRoot)
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue
      const manifestPath = join(directory, entry.name, 'package.json')
      if (existsSync(manifestPath)) paths.push(manifestPath)
    }
  }

  paths.push(join(root, 'docs', 'package.json'))
  return paths
}

export function alignManifest(manifest, { isRoot = false, version }) {
  const activeCohortPackages = cohortPackagesForVersion(version)
  const inactiveCohortPackages = activeCohortPackages.includes('@vue/runtime-vapor')
    ? []
    : VAPOR_COHORT_PACKAGES
  const peerRange = canonicalPeerRange(version)

  if (isRoot) {
    manifest.vueNative ??= {}
    manifest.vueNative.vueCohort ??= {}
    manifest.vueNative.vueCohort.active = version

    const unrelatedOverrides = Object.entries(manifest.overrides ?? {})
      .filter(([packageName]) => !allCohortPackages.has(packageName))
    manifest.overrides = {
      ...Object.fromEntries(unrelatedOverrides),
      ...Object.fromEntries(
        activeCohortPackages.map(packageName => [packageName, version]),
      ),
    }
  }

  for (const section of dependencySections) {
    for (const packageName of inactiveCohortPackages) {
      if (manifest[section]?.[packageName] !== undefined) {
        delete manifest[section][packageName]
      }
    }
    for (const packageName of activeCohortPackages) {
      if (manifest[section]?.[packageName] !== undefined) {
        manifest[section][packageName] = version
      }
    }
  }

  for (const packageName of inactiveCohortPackages) {
    if (manifest.peerDependencies?.[packageName] !== undefined) {
      delete manifest.peerDependencies[packageName]
    }
    if (manifest.resolutions?.[packageName] !== undefined) {
      delete manifest.resolutions[packageName]
    }
    if (!isRoot && manifest.overrides?.[packageName] !== undefined) {
      delete manifest.overrides[packageName]
    }
  }

  for (const packageName of activeCohortPackages) {
    if (manifest.peerDependencies?.[packageName] !== undefined) {
      manifest.peerDependencies[packageName] = peerRange
    }
  }

  if (manifest.name === '@thelacanians/vue-native-cli') {
    manifest.vueNative ??= {}
    manifest.vueNative.vueVersion = version
  }

  return manifest
}

function updateManifest(manifestPath, version) {
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
  const before = `${JSON.stringify(manifest, null, 2)}\n`
  alignManifest(manifest, {
    isRoot: manifestPath === join(root, 'package.json'),
    version,
  })
  const after = `${JSON.stringify(manifest, null, 2)}\n`
  return { after, before }
}

const scriptPath = fileURLToPath(import.meta.url)
if (process.argv[1] && resolve(process.argv[1]) === scriptPath) {
  const { dryRun, version } = parseArgs(process.argv.slice(2))
  const changed = []

  for (const manifestPath of workspaceManifestPaths()) {
    const { after, before } = updateManifest(manifestPath, version)
    if (after === before) continue
    changed.push(manifestPath)
    if (!dryRun) writeFileSync(manifestPath, after)
  }

  const verb = dryRun ? 'Would align' : 'Aligned'
  process.stdout.write(
    `${verb} ${changed.length} manifest${changed.length === 1 ? '' : 's'} to Vue ${version}.\n`,
  )
  for (const manifestPath of changed) {
    process.stdout.write(`- ${manifestPath.slice(root.length + 1)}\n`)
  }
}
