import { execFileSync, spawnSync } from 'node:child_process'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')

function runGit(args, { cwd, tolerateFailure = false } = {}) {
  const result = spawnSync('git', args, {
    cwd,
    encoding: 'utf8',
  })
  if (result.status !== 0 && !tolerateFailure) {
    const message = result.stderr.trim() || result.stdout.trim()
    throw new Error(`git ${args.join(' ')} failed: ${message}`)
  }
  return result
}

function gitOutput(args, cwd) {
  return execFileSync('git', args, { cwd, encoding: 'utf8' }).trim()
}

function manifestAtCommit({ cwd, path, sha }) {
  return JSON.parse(gitOutput(['show', `${sha}:${path}`], cwd))
}

export function collectReleaseTargets({
  cwd = root,
  releaseSha,
} = {}) {
  if (!releaseSha) throw new Error('releaseSha is required')
  const resolvedSha = gitOutput(['rev-parse', `${releaseSha}^{commit}`], cwd)
  const parents = gitOutput(
    ['rev-list', '--parents', '--max-count=1', resolvedSha],
    cwd,
  ).split(/\s+/)
  if (parents.length !== 2) {
    throw new Error(`${resolvedSha} must have exactly one parent`)
  }
  const parentSha = parents[1]
  const changedManifests = gitOutput(
    [
      'diff',
      '--name-only',
      '--diff-filter=AM',
      parentSha,
      resolvedSha,
      '--',
      'packages/*/package.json',
    ],
    cwd,
  ).split('\n').filter(Boolean)
  const targets = []

  for (const manifestPath of changedManifests) {
    const before = manifestAtCommit({ cwd, path: manifestPath, sha: parentSha })
    const after = manifestAtCommit({ cwd, path: manifestPath, sha: resolvedSha })
    if (after.private === true || before.version === after.version) continue
    if (typeof after.name !== 'string' || typeof after.version !== 'string') {
      throw new Error(`${manifestPath} has no public package name/version`)
    }
    targets.push({
      manifestPath,
      name: after.name,
      tag: `${after.name}@${after.version}`,
      version: after.version,
    })
  }

  return targets.sort((left, right) => left.tag.localeCompare(right.tag))
}

function tagCommitFromRemote({ cwd, remote, tag }) {
  const tagRef = `refs/tags/${tag}`
  const result = runGit(
    ['ls-remote', '--tags', remote, tagRef, `${tagRef}^{}`],
    { cwd, tolerateFailure: true },
  )
  if (result.status !== 0) {
    throw new Error(
      `Could not inspect ${tagRef} on ${remote}: ${result.stderr.trim()}`,
    )
  }
  const refs = new Map(
    result.stdout.trim().split('\n').filter(Boolean).map((line) => {
      const [sha, ref] = line.split(/\s+/)
      return [ref, sha]
    }),
  )
  if (!refs.has(tagRef)) return undefined
  if (!refs.has(`${tagRef}^{}`)) {
    throw new Error(`${tagRef} exists on ${remote} but is not annotated`)
  }
  return refs.get(`${tagRef}^{}`)
}

function localTagCommit({ cwd, tag }) {
  const tagRef = `refs/tags/${tag}`
  const exists = runGit(
    ['show-ref', '--verify', '--quiet', tagRef],
    { cwd, tolerateFailure: true },
  )
  if (exists.status !== 0) return undefined
  const type = gitOutput(['cat-file', '-t', tagRef], cwd)
  if (type !== 'tag') throw new Error(`${tagRef} exists locally but is not annotated`)
  return gitOutput(['rev-list', '--max-count=1', tagRef], cwd)
}

function assertExpectedCommit({ actual, expected, label }) {
  if (actual !== expected) {
    throw new Error(`${label} points to ${actual}, expected ${expected}`)
  }
}

export function syncReleaseTags({
  cwd = root,
  dryRun = false,
  releaseSha,
  remote = 'origin',
} = {}) {
  const resolvedSha = gitOutput(['rev-parse', `${releaseSha}^{commit}`], cwd)
  const targets = collectReleaseTargets({ cwd, releaseSha: resolvedSha })
  if (targets.length === 0) {
    throw new Error(`${resolvedSha} contains no public package version changes`)
  }
  const states = targets.map((target) => {
    const tagRef = `refs/tags/${target.tag}`
    const remoteCommit = tagCommitFromRemote({
      cwd,
      remote,
      tag: target.tag,
    })
    if (remoteCommit) {
      assertExpectedCommit({
        actual: remoteCommit,
        expected: resolvedSha,
        label: `${tagRef} on ${remote}`,
      })
      return { localCommit: undefined, remoteCommit, target }
    }

    const localCommit = localTagCommit({ cwd, tag: target.tag })
    if (localCommit) {
      assertExpectedCommit({
        actual: localCommit,
        expected: resolvedSha,
        label: `${tagRef} locally`,
      })
    }
    return { localCommit, remoteCommit: undefined, target }
  })
  const results = []

  for (const { localCommit, remoteCommit, target } of states) {
    if (remoteCommit) {
      results.push({ ...target, action: 'reused' })
      continue
    }
    if (dryRun) {
      results.push({ ...target, action: 'would-create' })
      continue
    }
    const tagRef = `refs/tags/${target.tag}`
    if (!localCommit) {
      runGit(
        ['tag', '-a', target.tag, resolvedSha, '-m', target.tag],
        { cwd },
      )
    }

    const push = runGit(
      ['push', remote, tagRef],
      { cwd, tolerateFailure: true },
    )
    if (push.status !== 0) {
      const racedCommit = tagCommitFromRemote({
        cwd,
        remote,
        tag: target.tag,
      })
      if (!racedCommit) {
        throw new Error(
          `Could not push ${tagRef}: ${push.stderr.trim() || push.stdout.trim()}`,
        )
      }
      assertExpectedCommit({
        actual: racedCommit,
        expected: resolvedSha,
        label: `${tagRef} on ${remote}`,
      })
    }

    const publishedCommit = tagCommitFromRemote({
      cwd,
      remote,
      tag: target.tag,
    })
    assertExpectedCommit({
      actual: publishedCommit,
      expected: resolvedSha,
      label: `${tagRef} on ${remote}`,
    })
    results.push({ ...target, action: 'created' })
  }

  return results
}

function usage() {
  process.stdout.write(
    'Usage: bun scripts/sync-release-tags.mjs --release-sha <sha> '
    + '[--remote <name>] [--dry-run] [--json]\n',
  )
}

function parseArgs(args) {
  const options = {
    dryRun: false,
    json: false,
    remote: 'origin',
    releaseSha: undefined,
  }

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index]
    if (argument === '--help' || argument === '-h') {
      usage()
      process.exit(0)
    } else if (argument === '--dry-run') {
      options.dryRun = true
    } else if (argument === '--json') {
      options.json = true
    } else if (argument === '--remote' || argument === '--release-sha') {
      const value = args[index + 1]
      if (!value || value.startsWith('-')) {
        throw new Error(`${argument} requires a value`)
      }
      if (argument === '--remote') options.remote = value
      else options.releaseSha = value
      index += 1
    } else {
      throw new Error(`Unknown argument: ${argument}`)
    }
  }
  if (!options.releaseSha) throw new Error('--release-sha is required')
  return options
}

const scriptPath = fileURLToPath(import.meta.url)
if (process.argv[1] && resolve(process.argv[1]) === scriptPath) {
  const options = parseArgs(process.argv.slice(2))
  const results = syncReleaseTags(options)
  if (options.json) {
    process.stdout.write(`${JSON.stringify({ ok: true, results }, null, 2)}\n`)
  } else {
    for (const result of results) {
      process.stdout.write(`${result.action}: ${result.tag}\n`)
    }
  }
}
