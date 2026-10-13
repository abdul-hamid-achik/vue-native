/**
 * `vue-native run ios` spawned xcodebuild with piped stdio and read only
 * stderr. A cold build fills the stdout pipe, after which xcodebuild blocked
 * on its next write and the command hung with no CPU use.
 */
import { describe, expect, it } from 'vitest'
import { runManagedProcess } from '../managed-process'

const WRITE_ONE_MEGABYTE = 'process.stdout.write("x".repeat(1 << 20)); process.stderr.write("y".repeat(1 << 20))'

describe('runManagedProcess', () => {
  it('drains piped streams that have no handler, so a chatty child can exit', async () => {
    const result = await runManagedProcess(process.execPath, ['-e', WRITE_ONE_MEGABYTE], { stdio: 'pipe' })

    expect(result.code).toBe(0)
  }, 15_000)

  it('still delivers output to a handler', async () => {
    let bytes = 0
    const result = await runManagedProcess(
      process.execPath,
      ['-e', WRITE_ONE_MEGABYTE],
      { stdio: 'pipe' },
      { stdout: (data) => { bytes += data.length } },
    )

    expect(result.code).toBe(0)
    expect(bytes).toBe(1 << 20)
  }, 15_000)
})
