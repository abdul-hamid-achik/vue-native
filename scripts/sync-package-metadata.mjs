import {
  existsSync,
  readFileSync,
  readdirSync,
  writeFileSync,
} from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import satisfies from 'semver/functions/satisfies.js'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const dependencySections = [
  'dependencies',
  'devDependencies',
  'optionalDependencies',
  'peerDependencies',
]

function removeJsonComments(source) {
  let result = ''
  let inString = false
  let escaped = false

  for (let index = 0; index < source.length; index += 1) {
    const character = source[index]
    const next = source[index + 1]

    if (inString) {
      result += character
      if (escaped) {
        escaped = false
      } else if (character === '\\') {
        escaped = true
      } else if (character === '"') {
        inString = false
      }
      continue
    }

    if (character === '"') {
      inString = true
      result += character
      continue
    }

    if (character === '/' && next === '/') {
      result += '  '
      index += 1
      while (index + 1 < source.length && source[index + 1] !== '\n') {
        result += ' '
        index += 1
      }
      continue
    }

    if (character === '/' && next === '*') {
      result += '  '
      index += 1
      while (
        index + 2 < source.length
        && !(source[index + 1] === '*' && source[index + 2] === '/')
      ) {
        index += 1
        result += source[index] === '\n' ? '\n' : ' '
      }
      if (index + 2 < source.length) {
        result += '  '
        index += 2
      }
      continue
    }

    result += character
  }

  return result
}

function removeTrailingCommas(source) {
  let result = ''
  let inString = false
  let escaped = false

  for (let index = 0; index < source.length; index += 1) {
    const character = source[index]

    if (inString) {
      result += character
      if (escaped) {
        escaped = false
      } else if (character === '\\') {
        escaped = true
      } else if (character === '"') {
        inString = false
      }
      continue
    }

    if (character === '"') {
      inString = true
      result += character
      continue
    }

    if (character === ',') {
      let lookahead = index + 1
      while (/\s/.test(source[lookahead] ?? '')) lookahead += 1
      if (source[lookahead] === '}' || source[lookahead] === ']') continue
    }

    result += character
  }

  return result
}

export function parseJsonc(source) {
  return JSON.parse(removeTrailingCommas(removeJsonComments(source)))
}

function readJson(path) {
  return JSON.parse(readFileSync(path, 'utf8'))
}

function workspaceManifestPaths(repoRoot) {
  const rootManifestPath = join(repoRoot, 'package.json')
  const rootManifest = readJson(rootManifestPath)
  const paths = [rootManifestPath]

  for (const workspace of rootManifest.workspaces ?? []) {
    if (workspace.endsWith('/*')) {
      const workspaceRoot = join(repoRoot, workspace.slice(0, -2))
      if (!existsSync(workspaceRoot)) continue
      for (const entry of readdirSync(workspaceRoot, { withFileTypes: true })) {
        if (!entry.isDirectory()) continue
        const manifestPath = join(workspaceRoot, entry.name, 'package.json')
        if (existsSync(manifestPath)) paths.push(manifestPath)
      }
      continue
    }

    const manifestPath = join(repoRoot, workspace, 'package.json')
    if (existsSync(manifestPath)) paths.push(manifestPath)
  }

  return paths
}

function workspaceKeyForManifest(repoRoot, manifestPath) {
  const key = relative(repoRoot, dirname(manifestPath))
  return key === '' ? '' : key.replaceAll('\\', '/')
}

function collectLockDrifts({ repoRoot, lock }) {
  const drifts = []

  for (const manifestPath of workspaceManifestPaths(repoRoot)) {
    const manifest = readJson(manifestPath)
    const workspaceKey = workspaceKeyForManifest(repoRoot, manifestPath)
    const importer = lock.workspaces?.[workspaceKey]
    const label = workspaceKey || '.'

    if (!importer) {
      drifts.push({
        actual: undefined,
        expected: 'workspace importer',
        label: `${label} importer`,
        path: [],
        workspaceKey,
      })
      continue
    }

    for (const field of ['name', 'version']) {
      const actual = importer[field]
      const expected = manifest[field]
      if (actual === expected) continue
      drifts.push({
        actual,
        expected,
        label: `${label} ${field}`,
        path: [field],
        workspaceKey,
      })
    }

    for (const section of dependencySections) {
      const actualDependencies = importer[section] ?? {}
      const expectedDependencies = manifest[section] ?? {}
      const packageNames = new Set([
        ...Object.keys(actualDependencies),
        ...Object.keys(expectedDependencies),
      ])

      for (const packageName of [...packageNames].sort()) {
        const actual = actualDependencies[packageName]
        const expected = expectedDependencies[packageName]
        if (actual === expected) continue
        drifts.push({
          actual,
          expected,
          label: `${label} ${section}.${packageName}`,
          path: [section, packageName],
          workspaceKey,
        })
      }
    }
  }

  return drifts
}

function firstChangelogVersion(source) {
  return /^## ([^\s]+)\s*$/m.exec(source)?.[1]
}

function normalizedWorkspaceRange(range, targetVersion) {
  if (range === 'workspace:*') return targetVersion
  if (range === 'workspace:^') return `^${targetVersion}`
  if (range === 'workspace:~') return `~${targetVersion}`
  return range.startsWith('workspace:') ? range.slice('workspace:'.length) : range
}

export function collectPackageMetadataErrors({ repoRoot = root } = {}) {
  const lockPath = join(repoRoot, 'bun.lock')
  const lock = parseJsonc(readFileSync(lockPath, 'utf8'))
  const manifests = workspaceManifestPaths(repoRoot).map((manifestPath) => {
    const manifest = readJson(manifestPath)
    return {
      manifest,
      manifestPath,
      workspaceKey: workspaceKeyForManifest(repoRoot, manifestPath),
    }
  })
  const errors = collectLockDrifts({ repoRoot, lock })
    .map(({ actual, expected, label }) => (
      `${label} is ${JSON.stringify(actual)} in bun.lock; expected ${JSON.stringify(expected)}`
    ))

  const publicPackages = manifests.filter(({ manifest, workspaceKey }) => (
    workspaceKey.startsWith('packages/') && manifest.private !== true
  ))
  for (const { manifest, manifestPath, workspaceKey } of publicPackages) {
    const changelogPath = join(dirname(manifestPath), 'CHANGELOG.md')
    if (!existsSync(changelogPath)) {
      errors.push(`${workspaceKey} has no CHANGELOG.md`)
      continue
    }
    const changelogVersion = firstChangelogVersion(readFileSync(changelogPath, 'utf8'))
    if (changelogVersion !== manifest.version) {
      errors.push(
        `${workspaceKey}/CHANGELOG.md starts at ${JSON.stringify(changelogVersion)}; `
        + `expected ${JSON.stringify(manifest.version)}`,
      )
    }
  }

  const manifestsByName = new Map(
    manifests.map(entry => [entry.manifest.name, entry]),
  )
  for (const { manifest, workspaceKey } of manifests) {
    for (const section of dependencySections) {
      for (const [packageName, declaredRange] of Object.entries(manifest[section] ?? {})) {
        const target = manifestsByName.get(packageName)
        if (!target || typeof declaredRange !== 'string') continue
        const range = normalizedWorkspaceRange(declaredRange, target.manifest.version)
        let acceptsTarget = false
        if (typeof target.manifest.version === 'string') {
          try {
            acceptsTarget = satisfies(
              target.manifest.version,
              range,
              { includePrerelease: true },
            )
          } catch {
            acceptsTarget = false
          }
        }
        if (!acceptsTarget) {
          errors.push(
            `${workspaceKey || '.'} ${section}.${packageName} range `
            + `${JSON.stringify(declaredRange)} does not accept workspace version `
            + JSON.stringify(target.manifest.version),
          )
        }
      }
    }
  }

  const changesetsConfigPath = join(repoRoot, '.changeset', 'config.json')
  if (existsSync(changesetsConfigPath)) {
    const changesetsConfig = readJson(changesetsConfigPath)
    for (const fixedGroup of changesetsConfig.fixed ?? []) {
      const versions = new Map()
      for (const packageName of fixedGroup) {
        const entry = manifestsByName.get(packageName)
        if (!entry) {
          errors.push(`Changesets fixed package ${packageName} has no workspace manifest`)
          continue
        }
        const { manifest } = entry
        const packages = versions.get(manifest.version) ?? []
        packages.push(packageName)
        versions.set(manifest.version, packages)
      }
      if (versions.size > 1) {
        const summary = [...versions.entries()]
          .map(([version, packageNames]) => `${version}: ${packageNames.join(', ')}`)
          .join('; ')
        errors.push(`Changesets fixed group versions diverge (${summary})`)
      }
    }
  }

  return errors
}

function findMatchingBrace(source, openIndex) {
  let depth = 0
  let inString = false
  let escaped = false

  for (let index = openIndex; index < source.length; index += 1) {
    const character = source[index]
    if (inString) {
      if (escaped) {
        escaped = false
      } else if (character === '\\') {
        escaped = true
      } else if (character === '"') {
        inString = false
      }
      continue
    }
    if (character === '"') {
      inString = true
    } else if (character === '{') {
      depth += 1
    } else if (character === '}') {
      depth -= 1
      if (depth === 0) return index
    }
  }

  throw new Error(`Could not find closing brace at offset ${openIndex}`)
}

function findObjectPropertyRange(source, propertyName, searchStart, searchEnd) {
  const needle = `${JSON.stringify(propertyName)}: {`
  const propertyIndex = source.indexOf(needle, searchStart)
  if (propertyIndex < 0 || propertyIndex >= searchEnd) {
    throw new Error(`Could not find object property ${propertyName}`)
  }
  const openIndex = source.indexOf('{', propertyIndex + needle.length - 1)
  const closeIndex = findMatchingBrace(source, openIndex)
  if (closeIndex >= searchEnd) {
    throw new Error(`Object property ${propertyName} exceeds its parent range`)
  }
  return { end: closeIndex + 1, start: openIndex }
}

function replacementForDrift(source, workspacesRange, drift) {
  if (typeof drift.actual !== 'string' || typeof drift.expected !== 'string') {
    throw new Error(
      `${drift.label} changes lockfile structure; run bun install before syncing metadata`,
    )
  }

  const importerRange = findObjectPropertyRange(
    source,
    drift.workspaceKey,
    workspacesRange.start,
    workspacesRange.end,
  )
  const containerRange = drift.path.length === 1
    ? importerRange
    : findObjectPropertyRange(
        source,
        drift.path[0],
        importerRange.start,
        importerRange.end,
      )
  const propertyName = drift.path.at(-1)
  const propertyNeedle = `${JSON.stringify(propertyName)}: ${JSON.stringify(drift.actual)}`
  const propertyIndex = source.indexOf(
    propertyNeedle,
    containerRange.start,
  )
  if (
    propertyIndex < 0
    || propertyIndex + propertyNeedle.length > containerRange.end
  ) {
    throw new Error(`Could not locate ${drift.label} in bun.lock`)
  }
  const valueStart = propertyIndex + propertyNeedle.lastIndexOf(JSON.stringify(drift.actual))
  return {
    end: valueStart + JSON.stringify(drift.actual).length,
    label: drift.label,
    replacement: JSON.stringify(drift.expected),
    start: valueStart,
  }
}

export function syncBunLockMetadata({ repoRoot = root } = {}) {
  const lockPath = join(repoRoot, 'bun.lock')
  const source = readFileSync(lockPath, 'utf8')
  const lock = parseJsonc(source)
  const drifts = collectLockDrifts({ repoRoot, lock })
  if (drifts.length === 0) return []
  const workspacePackageNames = new Set(
    workspaceManifestPaths(repoRoot)
      .map(manifestPath => readJson(manifestPath).name)
      .filter(Boolean),
  )
  const unsupportedDrifts = drifts.filter(({ path }) => (
    !(path.length === 1 && path[0] === 'version')
    && !(
      path.length === 2
      && dependencySections.includes(path[0])
      && workspacePackageNames.has(path[1])
    )
  ))
  if (unsupportedDrifts.length > 0) {
    throw new Error(
      'Only workspace versions and internal dependency ranges can be '
      + `synchronized automatically; run bun install to repair ${unsupportedDrifts[0].label}`,
    )
  }

  const workspacesRange = findObjectPropertyRange(
    source,
    'workspaces',
    0,
    source.length,
  )
  const replacements = drifts
    .map(drift => replacementForDrift(source, workspacesRange, drift))
    .sort((left, right) => right.start - left.start)

  let updated = source
  for (const replacement of replacements) {
    updated = (
      updated.slice(0, replacement.start)
      + replacement.replacement
      + updated.slice(replacement.end)
    )
  }
  writeFileSync(lockPath, updated)
  return replacements.map(({ label }) => label).sort()
}

function usage() {
  process.stdout.write(
    'Usage: bun scripts/sync-package-metadata.mjs [--check | --write]\n',
  )
}

const scriptPath = fileURLToPath(import.meta.url)
if (process.argv[1] && resolve(process.argv[1]) === scriptPath) {
  const args = process.argv.slice(2)
  if (args.includes('--help') || args.includes('-h')) {
    usage()
    process.exit(0)
  }
  const unknown = args.filter(argument => !['--check', '--write'].includes(argument))
  if (unknown.length > 0) throw new Error(`Unknown argument: ${unknown[0]}`)
  if (args.includes('--check') && args.includes('--write')) {
    throw new Error('Choose either --check or --write.')
  }

  const changed = args.includes('--write')
    ? syncBunLockMetadata()
    : []
  const errors = collectPackageMetadataErrors()
  if (errors.length > 0) {
    process.stderr.write('Package metadata drift detected:\n')
    for (const error of errors) process.stderr.write(`- ${error}\n`)
    process.exit(1)
  }

  if (changed.length > 0) {
    process.stdout.write(`Synchronized ${changed.length} bun.lock field(s):\n`)
    for (const label of changed) process.stdout.write(`- ${label}\n`)
  } else {
    process.stdout.write('Package manifests, bun.lock, changelogs, and fixed groups are consistent.\n')
  }
}
