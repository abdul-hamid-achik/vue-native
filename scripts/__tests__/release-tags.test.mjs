import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { test } from 'node:test'
import {
  collectReleaseTargets,
  syncReleaseTags,
} from '../sync-release-tags.mjs'

function git(cwd, args) {
  return execFileSync('git', args, { cwd, encoding: 'utf8' }).trim()
}

function writeManifest(repo, workspace, manifest) {
  const path = join(repo, workspace, 'package.json')
  mkdirSync(dirname(path), { recursive: true })
  writeFileSync(path, `${JSON.stringify(manifest, null, 2)}\n`)
}

function createFixture() {
  const root = mkdtempSync(join(tmpdir(), 'vue-native-release-tags-'))
  const repo = join(root, 'repo')
  const remote = join(root, 'remote.git')
  mkdirSync(repo)
  git(repo, ['init', '--initial-branch=main'])
  git(repo, ['config', 'user.name', 'Release Test'])
  git(repo, ['config', 'user.email', 'release@example.com'])

  writeManifest(repo, 'packages/runtime', {
    name: '@scope/runtime',
    version: '0.7.5',
  })
  writeManifest(repo, 'packages/parser', {
    name: '@scope/parser',
    version: '0.6.6',
  })
  writeManifest(repo, 'packages/codegen', {
    description: 'before',
    name: '@scope/codegen',
    version: '0.6.6',
  })
  writeManifest(repo, 'packages/private-example', {
    name: '@scope/private-example',
    private: true,
    version: '1.0.0',
  })
  git(repo, ['add', '.'])
  git(repo, ['commit', '-m', 'base'])

  writeManifest(repo, 'packages/runtime', {
    name: '@scope/runtime',
    version: '0.7.6',
  })
  writeManifest(repo, 'packages/parser', {
    name: '@scope/parser',
    version: '0.6.7',
  })
  writeManifest(repo, 'packages/codegen', {
    description: 'after',
    name: '@scope/codegen',
    version: '0.6.6',
  })
  writeManifest(repo, 'packages/private-example', {
    name: '@scope/private-example',
    private: true,
    version: '1.0.1',
  })
  git(repo, ['add', '.'])
  git(repo, ['commit', '-m', 'release'])
  const releaseSha = git(repo, ['rev-parse', 'HEAD'])

  git(root, ['init', '--bare', remote])
  git(repo, ['remote', 'add', 'origin', remote])
  git(repo, ['push', 'origin', 'main'])
  return { releaseSha, remote, repo, root }
}

function remoteTagCommit(repo, tag) {
  const output = git(repo, [
    'ls-remote',
    '--tags',
    'origin',
    `refs/tags/${tag}^{}`,
  ])
  return output.split(/\s+/)[0]
}

test('release tags cover only public packages whose versions changed', () => {
  const fixture = createFixture()
  try {
    assert.deepEqual(
      collectReleaseTargets({
        cwd: fixture.repo,
        releaseSha: fixture.releaseSha,
      }).map(target => target.tag),
      ['@scope/parser@0.6.7', '@scope/runtime@0.7.6'],
    )

    const created = syncReleaseTags({
      cwd: fixture.repo,
      releaseSha: fixture.releaseSha,
    })
    assert.deepEqual(created.map(result => result.action), ['created', 'created'])
    for (const result of created) {
      assert.equal(remoteTagCommit(fixture.repo, result.tag), fixture.releaseSha)
      assert.equal(
        git(fixture.repo, ['cat-file', '-t', `refs/tags/${result.tag}`]),
        'tag',
      )
      git(fixture.repo, ['tag', '-d', result.tag])
    }

    const recovered = syncReleaseTags({
      cwd: fixture.repo,
      releaseSha: fixture.releaseSha,
    })
    assert.deepEqual(recovered.map(result => result.action), ['reused', 'reused'])
  } finally {
    rmSync(fixture.root, { force: true, recursive: true })
  }
})

test('release tag synchronization refuses a conflicting remote tag', () => {
  const fixture = createFixture()
  try {
    const wrongSha = git(fixture.repo, ['rev-parse', 'HEAD^'])
    git(fixture.repo, [
      'tag',
      '-a',
      '@scope/runtime@0.7.6',
      wrongSha,
      '-m',
      'conflict',
    ])
    git(fixture.repo, [
      'push',
      'origin',
      'refs/tags/@scope/runtime@0.7.6',
    ])

    assert.throws(
      () => syncReleaseTags({
        cwd: fixture.repo,
        releaseSha: fixture.releaseSha,
      }),
      /points to .* expected/,
    )
    assert.equal(
      remoteTagCommit(fixture.repo, '@scope/runtime@0.7.6'),
      wrongSha,
    )
    assert.equal(
      git(fixture.repo, [
        'ls-remote',
        '--tags',
        'origin',
        'refs/tags/@scope/parser@0.6.7',
      ]),
      '',
    )
  } finally {
    rmSync(fixture.root, { force: true, recursive: true })
  }
})
