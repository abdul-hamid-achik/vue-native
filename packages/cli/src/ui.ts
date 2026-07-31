import * as p from '@clack/prompts'
import { ConfigError } from './config.js'

/**
 * Clack prompts resolve to a symbol when the user cancels (Ctrl+C / Esc).
 * Unwrap the real value or exit cleanly with a cancel message so commands
 * stay terse and never operate on a cancelled prompt.
 */
export function unwrap<T>(value: T | symbol): T {
  if (p.isCancel(value)) {
    p.cancel('Cancelled.')
    process.exit(1)
  }
  return value as T
}

/**
 * Interactive prompts need a real terminal. In CI or piped usage we skip
 * prompting and fall back to explicit flags (or a clear error) instead of
 * waiting forever for input that will never arrive.
 */
export function canPrompt(): boolean {
  return Boolean(process.stdin.isTTY && process.stdout.isTTY)
}

const PLATFORMS = ['ios', 'android', 'macos'] as const
type Platform = (typeof PLATFORMS)[number]

/**
 * Resolve the target platform: validate an explicit value, otherwise prompt
 * with a select when attached to a terminal. Non-interactive usage must pass
 * the platform explicitly so CI and scripts never hang waiting for input.
 */
export async function resolvePlatform(provided: string | undefined): Promise<Platform> {
  if (provided !== undefined) {
    if (!PLATFORMS.includes(provided as Platform)) {
      throw new ConfigError('Platform must be "ios", "android", or "macos"')
    }
    return provided as Platform
  }
  if (!canPrompt()) {
    throw new ConfigError(
      'Platform is required. Pass it as an argument: vue-native <command> <ios|android|macos>',
    )
  }
  return unwrap(await p.select({
    message: 'Which platform?',
    options: [
      { value: 'ios', label: 'iOS', hint: 'iPhone / iPad simulator or device' },
      { value: 'android', label: 'Android', hint: 'emulator or device' },
      { value: 'macos', label: 'macOS', hint: 'Mac app' },
    ],
  })) as Platform
}

export { p }
