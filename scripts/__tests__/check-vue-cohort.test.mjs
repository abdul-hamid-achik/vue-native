import assert from 'node:assert/strict'
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { test } from 'node:test'
import {
  canonicalPeerRange,
  checkBundleSource,
  cohortPackagesForVersion,
  collectVueCohortErrors,
  parseResolvedCohortRecords,
  parseResolvedCohortVersions,
  peerRangeSupportsCohort,
  VUE_COHORT_PACKAGES,
} from '../check-vue-cohort.mjs'

test('canonicalPeerRange contains the active minor and excludes the next one', () => {
  assert.equal(canonicalPeerRange('3.5.40'), '>=3.5.40 <3.6.0')
  assert.equal(canonicalPeerRange('3.6.0-rc.1'), '>=3.6.0-rc.1 <3.7.0')
  assert.throws(() => canonicalPeerRange('next'), /Invalid Vue cohort version/)
  assert.equal(peerRangeSupportsCohort('>=3.5.40 <3.6.0', '3.5.40'), true)
  assert.equal(peerRangeSupportsCohort('>=3.5.40 <4.0.0', '3.5.40'), false)
})

test('Vue 3.6 cohorts include the two first-party Vapor packages', () => {
  assert.equal(cohortPackagesForVersion('3.5.40').includes('@vue/runtime-vapor'), false)
  assert.equal(cohortPackagesForVersion('3.6.0-rc.1').includes('@vue/runtime-vapor'), true)
  assert.equal(cohortPackagesForVersion('3.6.0-rc.1').includes('@vue/compiler-vapor'), true)
})

test('parseResolvedCohortVersions exposes duplicate nested Vue runtimes', () => {
  const lock = `{
    "packages": {
      "@vue/runtime-core": ["@vue/runtime-core@3.5.40", "", {}],
      "legacy/@vue/runtime-core": ["@vue/runtime-core@3.5.28", "", {}],
      "@vue/shared": ["@vue/shared@3.5.40", "", {}],
      "vue": ["vue@3.5.40", "", {}],
    }
  }`
  const versions = parseResolvedCohortVersions(lock)

  assert.deepEqual([...versions['@vue/runtime-core']].sort(), ['3.5.28', '3.5.40'])
  assert.deepEqual([...versions['@vue/shared']], ['3.5.40'])
  assert.deepEqual([...versions.vue], ['3.5.40'])
})

test('parseResolvedCohortRecords preserves same-version physical duplicates', () => {
  const lock = `{
    "packages": {
      "@vue/runtime-core": ["@vue/runtime-core@3.5.40", "", {}],
      "legacy/@vue/runtime-core": ["@vue/runtime-core@3.5.40", "", {}]
    }
  }`
  const records = parseResolvedCohortRecords(lock)

  assert.deepEqual(records['@vue/runtime-core'], [
    { lockKey: '@vue/runtime-core', version: '3.5.40' },
    { lockKey: 'legacy/@vue/runtime-core', version: '3.5.40' },
  ])
})

test('checkBundleSource rejects unsupported renderer markers from native bundles', () => {
  assert.deepEqual(checkBundleSource('const native = true'), [])
  assert.deepEqual(
    checkBundleSource('document.createElementNS("svg")', 'dist/app.js'),
    ['dist/app.js contains unsupported renderer marker "document.createElementNS"'],
  )
  assert.deepEqual(
    checkBundleSource('/* @vue/runtime-dom */', 'dist/app.js'),
    ['dist/app.js contains unsupported renderer marker "@vue/runtime-dom"'],
  )
})

test('collectVueCohortErrors catches manifest, lock, and bundle drift', () => {
  const root = mkdtempSync(join(tmpdir(), 'vue-cohort-check-'))
  const version = '3.5.40'
  const writeJson = (relativePath, value) => {
    const path = join(root, relativePath)
    mkdirSync(dirname(path), { recursive: true })
    writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`)
  }
  const writeLock = (duplicateRuntimeVersion = undefined) => {
    const records = VUE_COHORT_PACKAGES.map(
      packageName => `    ${JSON.stringify(packageName)}: [${JSON.stringify(`${packageName}@${version}`)}, "", {}],`,
    )
    if (duplicateRuntimeVersion) {
      records.push(
        `    "legacy/@vue/runtime-core": ["@vue/runtime-core@${duplicateRuntimeVersion}", "", {}],`,
      )
    }
    writeFileSync(
      join(root, 'bun.lock'),
      `{\n  "packages": {\n${records.join('\n')}\n  }\n}\n`,
    )
  }

  try {
    writeJson('package.json', {
      vueNative: { vueCohort: { active: version } },
      overrides: Object.fromEntries(
        VUE_COHORT_PACKAGES.map(packageName => [packageName, version]),
      ),
    })
    writeJson('packages/runtime/package.json', {
      name: '@thelacanians/vue-native-runtime',
      dependencies: {
        '@vue/runtime-core': version,
        '@vue/reactivity': version,
        '@vue/shared': version,
      },
      peerDependencies: { vue: canonicalPeerRange(version) },
    })
    writeJson('packages/navigation/package.json', {
      name: '@thelacanians/vue-native-navigation',
      dependencies: { '@vue/runtime-core': version },
    })
    writeJson('packages/sfc-parser/package.json', {
      name: '@thelacanians/vue-native-sfc-parser',
      dependencies: { '@vue/compiler-sfc': version },
    })
    writeJson('packages/cli/package.json', {
      name: '@thelacanians/vue-native-cli',
      vueNative: { vueVersion: version },
    })
    writeJson('examples/counter/package.json', {
      name: 'counter',
      devDependencies: { vue: version },
    })
    writeJson('docs/package.json', {
      name: 'docs',
      devDependencies: { vue: version },
    })
    writeLock()

    assert.deepEqual(
      collectVueCohortErrors({ root, expected: version }),
      [],
    )

    writeJson('packages/runtime/package.json', {
      name: '@thelacanians/vue-native-runtime',
      dependencies: {
        '@vue/runtime-core': '3.5.28',
        '@vue/reactivity': version,
        '@vue/shared': version,
      },
    })
    writeLock('3.5.28')
    writeFileSync(join(root, 'bundle.js'), 'document.createElementNS("svg")')
    const errors = collectVueCohortErrors({
      root,
      expected: version,
      bundlePaths: ['bundle.js'],
    })

    assert.equal(
      errors.some(error => error.includes('declares @vue/runtime-core as "3.5.28"')),
      true,
    )
    assert.equal(
      errors.some(error => error.includes('3.5.28, 3.5.40')),
      true,
    )
    assert.equal(
      errors.some(error => error.includes('document.createElementNS')),
      true,
    )

    writeLock(version)
    const sameVersionDuplicateErrors = collectVueCohortErrors({
      root,
      expected: version,
    })
    assert.equal(
      sameVersionDuplicateErrors.some(
        error => error.includes('2 physical records for @vue/runtime-core'),
      ),
      true,
    )

    writeJson('packages/sfc-parser/package.json', {
      name: '@thelacanians/vue-native-sfc-parser',
      dependencies: {
        '@vue/compiler-sfc': version,
        '@vue/compiler-vapor': '3.6.0-rc.1',
      },
    })
    writeFileSync(
      join(root, 'bun.lock'),
      readFileSync(join(root, 'bun.lock'), 'utf8').replace(
        '\n  }\n}',
        '\n    "@vue/compiler-vapor": ["@vue/compiler-vapor@3.6.0-rc.1", "", {}]\n  }\n}',
      ),
    )
    const inactiveVaporErrors = collectVueCohortErrors({
      root,
      expected: version,
    })
    assert.equal(
      inactiveVaporErrors.some(
        error => error.includes('declares inactive @vue/compiler-vapor'),
      ),
      true,
    )
    assert.equal(
      inactiveVaporErrors.some(
        error => error.includes('bun.lock contains inactive @vue/compiler-vapor'),
      ),
      true,
    )
  } finally {
    rmSync(root, { recursive: true, force: true })
  }
})
