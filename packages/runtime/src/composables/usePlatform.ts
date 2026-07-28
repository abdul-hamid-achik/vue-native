declare const __PLATFORM__: string

export type Platform = 'ios' | 'android' | 'macos'

/**
 * Returns the current platform and convenience boolean flags.
 *
 * Relies on the `__PLATFORM__` compile-time constant injected by the Vite plugin.
 * Falls back to 'ios' if not defined.
 *
 * @example
 * ```ts
 * const { platform, isIOS, isAndroid, isMacOS, isApple, isDesktop, isMobile } = usePlatform()
 * ```
 */
export function usePlatform() {
  const platform: Platform = (typeof __PLATFORM__ !== 'undefined' ? __PLATFORM__ : 'ios') as Platform
  const isIOS = platform === 'ios'
  const isAndroid = platform === 'android'
  const isMacOS = platform === 'macos'
  const isApple = isIOS || isMacOS
  const isDesktop = isMacOS
  const isMobile = isIOS || isAndroid
  return { platform, isIOS, isAndroid, isMacOS, isApple, isDesktop, isMobile }
}

function currentPlatform(): Platform {
  return (typeof __PLATFORM__ !== 'undefined' ? __PLATFORM__ : 'ios') as Platform
}

/**
 * Per-platform value map for {@link selectPlatform}, mirroring React Native's
 * `Platform.select`. `apple` covers both ios and macos when a platform-specific
 * key is absent; `default` is the final fallback.
 */
export interface PlatformSelectSpec<T> {
  ios?: T
  android?: T
  macos?: T
  apple?: T
  default?: T
}

/**
 * Pick a value for the current platform.
 *
 * @example
 * ```ts
 * const shadow = selectPlatform({
 *   ios: { shadowRadius: 4 },
 *   android: { elevation: 4 },
 *   default: {},
 * })
 * ```
 */
export function selectPlatform<T>(spec: PlatformSelectSpec<T>): T | undefined {
  const platform = currentPlatform()
  const exact = spec[platform]
  if (exact !== undefined) return exact
  if ((platform === 'ios' || platform === 'macos') && spec.apple !== undefined) return spec.apple
  return spec.default
}
