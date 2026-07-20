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
  collectPackageMetadataErrors,
  parseJsonc,
  syncBunLockMetadata,
} from '../sync-package-metadata.mjs'

function writeJson(root, relativePath, value) {
  const path = join(root, relativePath)
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`)
}

function writeChangelog(root, workspace, version) {
  writeFileSync(
    join(root, workspace, 'CHANGELOG.md'),
    `# package\n\n## ${version}\n\n### Patch Changes\n`,
  )
}

test('parseJsonc preserves strings while accepting comments and trailing commas', () => {
  const parsed = parseJsonc(`{
    // comment
    "url": "https://example.com/a,}",
    "items": ["one", "two",],
  }`)
  assert.deepEqual(parsed, {
    items: ['one', 'two'],
    url: 'https://example.com/a,}',
  })
})

test('syncBunLockMetadata repairs importer versions and dependency ranges only', () => {
  const root = mkdtempSync(join(tmpdir(), 'vue-native-package-metadata-'))

  try {
    writeJson(root, 'package.json', {
      name: 'repo',
      private: true,
      workspaces: ['packages/*'],
    })
    writeJson(root, '.changeset/config.json', {
      fixed: [['runtime', 'navigation']],
    })
    writeJson(root, 'packages/runtime/package.json', {
      name: 'runtime',
      version: '0.7.6',
    })
    writeJson(root, 'packages/navigation/package.json', {
      dependencies: { runtime: '^0.7.6' },
      name: 'navigation',
      version: '0.7.6',
    })
    writeJson(root, 'packages/parser/package.json', {
      name: 'parser',
      version: '0.6.7',
    })
    writeChangelog(root, 'packages/runtime', '0.7.6')
    writeChangelog(root, 'packages/navigation', '0.7.6')
    writeChangelog(root, 'packages/parser', '0.6.7')
    writeFileSync(join(root, 'bun.lock'), `{
  "lockfileVersion": 1,
  "workspaces": {
    "": {
      "name": "repo",
    },
    "packages/navigation": {
      "name": "navigation",
      "version": "0.7.5",
      "dependencies": {
        "runtime": "^0.7.5",
      },
    },
    "packages/parser": {
      "name": "parser",
      "version": "0.6.6",
    },
    "packages/runtime": {
      "name": "runtime",
      "version": "0.7.5",
    },
  },
  "packages": {
    "unrelated": ["unrelated@1.0.0", "", {}, "hash"],
  },
}
`)

    const before = readFileSync(join(root, 'bun.lock'), 'utf8')
    assert.equal(collectPackageMetadataErrors({ repoRoot: root }).length, 4)

    const changed = syncBunLockMetadata({ repoRoot: root })
    assert.deepEqual(changed, [
      'packages/navigation dependencies.runtime',
      'packages/navigation version',
      'packages/parser version',
      'packages/runtime version',
    ])
    assert.deepEqual(collectPackageMetadataErrors({ repoRoot: root }), [])

    const after = readFileSync(join(root, 'bun.lock'), 'utf8')
    assert.equal(after.includes('"unrelated@1.0.0"'), true)
    assert.equal(after.replaceAll('0.7.6', '0.7.5').replace('0.6.7', '0.6.6'), before)
    assert.deepEqual(syncBunLockMetadata({ repoRoot: root }), [])
  } finally {
    rmSync(root, { force: true, recursive: true })
  }
})

test('metadata checker reports changelog and fixed-group divergence', () => {
  const root = mkdtempSync(join(tmpdir(), 'vue-native-package-policy-'))

  try {
    writeJson(root, 'package.json', {
      name: 'repo',
      private: true,
      workspaces: ['packages/*'],
    })
    writeJson(root, '.changeset/config.json', {
      fixed: [['runtime', 'navigation']],
    })
    writeJson(root, 'packages/runtime/package.json', {
      name: 'runtime',
      version: '0.7.6',
    })
    writeJson(root, 'packages/navigation/package.json', {
      dependencies: { runtime: '^0.6.0' },
      name: 'navigation',
      version: '0.7.5',
    })
    writeChangelog(root, 'packages/runtime', '0.7.5')
    writeChangelog(root, 'packages/navigation', '0.7.5')
    writeFileSync(join(root, 'bun.lock'), `{
  "workspaces": {
    "": { "name": "repo", },
    "packages/navigation": {
      "name": "navigation",
      "version": "0.7.5",
      "dependencies": {
        "runtime": "^0.6.0",
      },
    },
    "packages/runtime": {
      "name": "runtime",
      "version": "0.7.6",
    },
  },
}
`)

    const errors = collectPackageMetadataErrors({ repoRoot: root })
    assert.equal(
      errors.some(error => error.includes('runtime/CHANGELOG.md starts at "0.7.5"')),
      true,
    )
    assert.equal(
      errors.some(error => error.includes('fixed group versions diverge')),
      true,
    )
    assert.equal(
      errors.some(error => error.includes('does not accept workspace version "0.7.6"')),
      true,
    )
  } finally {
    rmSync(root, { force: true, recursive: true })
  }
})

test('metadata synchronization refuses to mask external resolution drift', () => {
  const root = mkdtempSync(join(tmpdir(), 'vue-native-external-metadata-'))

  try {
    writeJson(root, 'package.json', {
      devDependencies: { external: '^2.0.0' },
      name: 'repo',
      private: true,
      workspaces: [],
    })
    const lock = `{
  "workspaces": {
    "": {
      "name": "repo",
      "devDependencies": {
        "external": "^1.0.0",
      },
    },
  },
}
`
    writeFileSync(join(root, 'bun.lock'), lock)

    assert.throws(
      () => syncBunLockMetadata({ repoRoot: root }),
      /run bun install to repair .*external/,
    )
    assert.equal(readFileSync(join(root, 'bun.lock'), 'utf8'), lock)
  } finally {
    rmSync(root, { force: true, recursive: true })
  }
})
