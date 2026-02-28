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
