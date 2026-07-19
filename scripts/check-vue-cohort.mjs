import {
  existsSync,
  readFileSync,
  readdirSync,
} from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const VUE_COHORT_PACKAGES = [
  'vue',
  '@vue/compiler-core',
  '@vue/compiler-dom',
  '@vue/compiler-sfc',
  '@vue/compiler-ssr',
  '@vue/reactivity',
  '@vue/runtime-core',
  '@vue/runtime-dom',
  '@vue/server-renderer',
  '@vue/shared',
]
export const VAPOR_COHORT_PACKAGES = [
  '@vue/compiler-vapor',
  '@vue/runtime-vapor',
]

const dependencySections = [
  'dependencies',
  'devDependencies',
  'optionalDependencies',
]
const forbiddenBundleMarkers = [
  '@vue/runtime-dom',
  '@vue/runtime-vapor',
  'document.createElementNS',
]

export function cohortPackagesForVersion(version) {
  const match = /^(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?$/.exec(version)
  if (!match) throw new Error(`Invalid Vue cohort version: ${version}`)
  return Number(match[2]) >= 6
    ? [...VUE_COHORT_PACKAGES, ...VAPOR_COHORT_PACKAGES]
    : VUE_COHORT_PACKAGES
}

export function canonicalPeerRange(version) {
  const match = /^(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?$/.exec(version)
  if (!match) throw new Error(`Invalid Vue cohort version: ${version}`)
  return `>=${version} <${match[1]}.${Number(match[2]) + 1}.0`
}

export function peerRangeSupportsCohort(peerRange, version) {
  if (peerRange === version || peerRange === canonicalPeerRange(version)) return true

  const match = /^(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?$/.exec(version)
  const semver = globalThis.Bun?.semver
  if (!match || !semver) return false

  const nextMinor = `${match[1]}.${Number(match[2]) + 1}.0`
  try {
    return semver.satisfies(version, peerRange)
      && !semver.satisfies(nextMinor, peerRange)
  } catch {
    return false
  }
}

export function parseResolvedCohortRecords(lockText, cohortPackages = VUE_COHORT_PACKAGES) {
  const records = Object.fromEntries(
    cohortPackages.map(packageName => [packageName, []]),
  )
  const packageRecordPattern = /^\s*"([^"]+)": \["([^"]+)"/gm

  for (const match of lockText.matchAll(packageRecordPattern)) {
    const lockKey = match[1]
    const resolvedPackage = match[2]
    for (const packageName of cohortPackages) {
      const prefix = `${packageName}@`
      if (!resolvedPackage.startsWith(prefix)) continue
      records[packageName].push({
        lockKey,
        version: resolvedPackage.slice(prefix.length),
      })
      break
    }
  }

  return records
}

export function parseResolvedCohortVersions(lockText, cohortPackages = VUE_COHORT_PACKAGES) {
  const records = parseResolvedCohortRecords(lockText, cohortPackages)
  const versions = Object.fromEntries(
    cohortPackages.map(packageName => [
      packageName,
      new Set(records[packageName].map(record => record.version)),
    ]),
  )
  return versions
}

export function checkBundleSource(bundleSource, bundleLabel = 'bundle') {
  return forbiddenBundleMarkers
    .filter(marker => bundleSource.includes(marker))
    .map(marker => `${bundleLabel} contains unsupported renderer marker "${marker}"`)
}

function readManifest(manifestPath) {
  return JSON.parse(readFileSync(manifestPath, 'utf8'))
}

function workspaceManifestPaths(root) {
  const paths = [join(root, 'package.json')]

  for (const workspaceRoot of ['packages', 'examples', 'tools']) {
    const directory = join(root, workspaceRoot)
    if (!existsSync(directory)) continue
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue
      const manifestPath = join(directory, entry.name, 'package.json')
      if (existsSync(manifestPath)) paths.push(manifestPath)
    }
  }

  const docsManifest = join(root, 'docs', 'package.json')
  if (existsSync(docsManifest)) paths.push(docsManifest)
  return paths
}

function declaredVersion(manifest, packageName) {
  for (const section of dependencySections) {
    if (manifest[section]?.[packageName] !== undefined) {
      return manifest[section][packageName]
    }
  }
  return undefined
}

export function collectVueCohortErrors({
  root,
  expected,
  bundlePaths = [],
}) {
  canonicalPeerRange(expected)
  const cohortPackages = cohortPackagesForVersion(expected)
  const inactiveCohortPackages = cohortPackages.includes('@vue/runtime-vapor')
    ? []
    : VAPOR_COHORT_PACKAGES
  const errors = []
  const rootManifestPath = join(root, 'package.json')
  const rootManifest = readManifest(rootManifestPath)
  const configured = rootManifest.vueNative?.vueCohort?.active

  if (configured !== expected) {
    errors.push(
      `package.json vueNative.vueCohort.active is "${configured ?? 'missing'}"; expected "${expected}"`,
    )
  }

  for (const packageName of cohortPackages) {
    const override = rootManifest.overrides?.[packageName]
    if (override !== expected) {
      errors.push(
        `package.json override for ${packageName} is "${override ?? 'missing'}"; expected "${expected}"`,
      )
    }
  }

  const manifests = workspaceManifestPaths(root)
  for (const manifestPath of manifests) {
    const manifest = readManifest(manifestPath)
    const label = relative(root, manifestPath) || 'package.json'

    for (const packageName of cohortPackages) {
      const version = declaredVersion(manifest, packageName)
      if (version !== undefined && version !== expected) {
        errors.push(
          `${label} declares ${packageName} as "${version}"; expected exact "${expected}"`,
        )
      }

      const peerRange = manifest.peerDependencies?.[packageName]
      if (peerRange !== undefined && !peerRangeSupportsCohort(peerRange, expected)) {
        errors.push(
          `${label} declares peer ${packageName} as "${peerRange}"; it must include ${expected} and exclude the next Vue minor`,
        )
      }

      for (const exactSection of ['overrides', 'resolutions']) {
        const exactVersion = manifest[exactSection]?.[packageName]
        if (exactVersion !== undefined && exactVersion !== expected) {
          errors.push(
            `${label} ${exactSection}.${packageName} is "${exactVersion}"; expected exact "${expected}"`,
          )
        }
      }
    }

    for (const packageName of inactiveCohortPackages) {
      for (const section of dependencySections) {
        if (manifest[section]?.[packageName] !== undefined) {
          errors.push(
            `${label} declares inactive ${packageName} in ${section}; remove it for Vue ${expected}`,
          )
        }
      }
      if (manifest.peerDependencies?.[packageName] !== undefined) {
        errors.push(
          `${label} declares inactive peer ${packageName}; remove it for Vue ${expected}`,
        )
      }
      for (const exactSection of ['overrides', 'resolutions']) {
        if (manifest[exactSection]?.[packageName] !== undefined) {
          errors.push(
            `${label} declares inactive ${exactSection}.${packageName}; remove it for Vue ${expected}`,
          )
        }
      }
    }

    if (manifest.name === '@thelacanians/vue-native-cli') {
      const scaffoldVersion = manifest.vueNative?.vueVersion
      if (scaffoldVersion !== expected) {
        errors.push(
          `${label} vueNative.vueVersion is "${scaffoldVersion ?? 'missing'}"; expected "${expected}"`,
        )
      }
    }

    if (label.startsWith('examples/')) {
      const vueVersion = declaredVersion(manifest, 'vue')
      if (vueVersion === undefined) {
        errors.push(`${label} must declare exact Vue ${expected}`)
      }
    }
  }

  const docsManifest = manifests.find(path => path === join(root, 'docs', 'package.json'))
  if (docsManifest) {
    const docs = readManifest(docsManifest)
    if (declaredVersion(docs, 'vue') === undefined) {
      errors.push(`docs/package.json must declare exact Vue ${expected}`)
    }
  }

  const requiredDeclarations = [
    ['packages/runtime/package.json', '@vue/runtime-core'],
    ['packages/runtime/package.json', '@vue/reactivity'],
    ['packages/runtime/package.json', '@vue/shared'],
    ['packages/navigation/package.json', '@vue/runtime-core'],
    ['packages/sfc-parser/package.json', '@vue/compiler-sfc'],
  ]
  for (const [relativeManifestPath, packageName] of requiredDeclarations) {
    const manifestPath = join(root, relativeManifestPath)
    if (!existsSync(manifestPath)) {
      errors.push(`${relativeManifestPath} is missing`)
      continue
    }
    const version = declaredVersion(readManifest(manifestPath), packageName)
    if (version === undefined) {
      errors.push(`${relativeManifestPath} must declare ${packageName}`)
    }
  }

  const lockPath = join(root, 'bun.lock')
  if (!existsSync(lockPath)) {
    errors.push('bun.lock is missing')
  } else {
    const inspectedPackages = [
      ...cohortPackages,
      ...inactiveCohortPackages,
    ]
    const resolvedRecords = parseResolvedCohortRecords(
      readFileSync(lockPath, 'utf8'),
      inspectedPackages,
    )
    for (const packageName of cohortPackages) {
      const records = resolvedRecords[packageName]
      const versions = [...new Set(records.map(record => record.version))].sort()
      if (versions.length !== 1 || versions[0] !== expected) {
        errors.push(
          `bun.lock resolves ${packageName} to [${versions.join(', ')}]; expected only "${expected}"`,
        )
      }
      if (records.length !== 1) {
        const lockKeys = records.map(record => record.lockKey).sort()
        errors.push(
          `bun.lock contains ${records.length} physical records for ${packageName} at [${lockKeys.join(', ')}]; expected exactly one`,
        )
      }
    }
    for (const packageName of inactiveCohortPackages) {
      const records = resolvedRecords[packageName]
      if (records.length > 0) {
        errors.push(
          `bun.lock contains inactive ${packageName} records at [${records.map(record => record.lockKey).sort().join(', ')}]; remove them for Vue ${expected}`,
        )
      }
    }
  }

  for (const bundlePath of bundlePaths) {
    const absoluteBundlePath = resolve(root, bundlePath)
    if (!existsSync(absoluteBundlePath)) {
      errors.push(`${relative(root, absoluteBundlePath)} is missing`)
      continue
    }
    errors.push(
      ...checkBundleSource(
        readFileSync(absoluteBundlePath, 'utf8'),
        relative(root, absoluteBundlePath),
      ),
    )
  }

  return errors
}

function usage() {
  process.stdout.write(
    'Usage: bun scripts/check-vue-cohort.mjs [--root <path>] [--expected <version>] [--bundle <path>]... [--json]\n',
  )
}

function parseArgs(argv, defaultRoot) {
  let root = defaultRoot
  let expected
  let json = false
  const bundlePaths = []

  for (let index = 0; index < argv.length; index++) {
    const argument = argv[index]
    if (argument === '--help' || argument === '-h') {
      usage()
      process.exit(0)
    }
    if (argument === '--expected') {
      expected = argv[++index]
      if (!expected) throw new Error('--expected requires a version')
      continue
    }
    if (argument === '--root') {
      const rootPath = argv[++index]
      if (!rootPath) throw new Error('--root requires a path')
      root = resolve(process.cwd(), rootPath)
      continue
    }
    if (argument === '--bundle') {
      const bundlePath = argv[++index]
      if (!bundlePath) throw new Error('--bundle requires a path')
      bundlePaths.push(bundlePath)
      continue
    }
    if (argument === '--json') {
      json = true
      continue
    }
    throw new Error(`Unknown argument: ${argument}`)
  }

  expected ??= readManifest(join(root, 'package.json')).vueNative?.vueCohort?.active
  if (!expected) {
    throw new Error('package.json is missing vueNative.vueCohort.active')
  }
  return { bundlePaths, expected, json, root }
}

const scriptPath = fileURLToPath(import.meta.url)
if (process.argv[1] && resolve(process.argv[1]) === scriptPath) {
  const defaultRoot = resolve(dirname(scriptPath), '..')
  try {
    const {
      bundlePaths,
      expected,
      json,
      root,
    } = parseArgs(process.argv.slice(2), defaultRoot)
    const errors = collectVueCohortErrors({ root, expected, bundlePaths })
    const cohortPackages = cohortPackagesForVersion(expected)

    if (json) {
      process.stdout.write(`${JSON.stringify({
        schemaVersion: 1,
        ok: errors.length === 0,
        expectedVersion: expected,
        cohortPackages,
        diagnostics: errors.map(message => ({
          code: 'VN_VUE_COHORT_MISMATCH',
          message,
        })),
      }, null, 2)}\n`)
    } else if (errors.length > 0) {
      process.stderr.write(
        `Vue ${expected} cohort check failed:\n${errors.map(error => `- ${error}`).join('\n')}\n`,
      )
    } else {
      process.stdout.write(
        `Vue ${expected} cohort check passed for manifests, bun.lock, and ${cohortPackages.length} resolved packages.\n`,
      )
    }
    if (errors.length > 0) process.exitCode = 1
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`)
    process.exitCode = 1
  }
}
