/**
 * Unit tests for native-project helpers, focused on Gradle failure surfacing.
 */
import { describe, it, expect } from 'vitest'
import { formatGradleFailure } from '../native-project'

describe('formatGradleFailure', () => {
  it('extracts the "What went wrong" block up to the "Try" section', () => {
    const stderr = [
      'Starting a Gradle Daemon',
      'FAILURE: Build failed with an exception.',
      '',
      '* What went wrong:',
      'SDK location not found. Define a valid location in the ANDROID_HOME',
      'environment variable or in sdk.dir in local.properties.',
      '',
      '* Try:',
      '> Run with --stacktrace option to get the stack trace.',
      '',
      'BUILD FAILED in 2s',
    ].join('\n')

    const result = formatGradleFailure(stderr)
    expect(result).toContain('* What went wrong:')
    expect(result).toContain('SDK location not found')
    expect(result).not.toContain('Run with --stacktrace')
    expect(result).not.toContain('BUILD FAILED')
  })

  it('keeps the block to the end when there is no "Try" section', () => {
    const stderr = [
      'FAILURE: Build failed with an exception.',
      '',
      '* What went wrong:',
      'A problem occurred evaluating root project.',
    ].join('\n')

    const result = formatGradleFailure(stderr)
    expect(result).toContain('A problem occurred evaluating root project')
  })

  it('falls back to the last lines when no failure block is present', () => {
    const lines = Array.from({ length: 40 }, (_, i) => `line ${i}`)
    const result = formatGradleFailure(lines.join('\n'))
    expect(result).toContain('line 39')
    expect(result).toContain('line 20')
    expect(result).not.toContain('line 0')
  })

  it('returns an empty string for empty stderr', () => {
    expect(formatGradleFailure('')).toBe('')
    expect(formatGradleFailure('   \n  ')).toBe('')
  })
})
