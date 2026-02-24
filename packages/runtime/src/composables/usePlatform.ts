declare const __PLATFORM__: string

export type Platform = 'ios' | 'android'

/**
 * Returns the current platform ('ios' or 'android').
 *
 * Relies on the `__PLATFORM__` compile-time constant injected by the Vite plugin.
 * Falls back to 'ios' if not defined.
 *
 * @example
 * ```ts
 * const { platform, isIOS, isAndroid } = usePlatform()
 * ```
 */
export function usePlatform() {
  const platform: Platform = (typeof __PLATFORM__ !== 'undefined' ? __PLATFORM__ : 'ios') as Platform
  const isIOS = platform === 'ios'
  const isAndroid = platform === 'android'
  return { platform, isIOS, isAndroid }
}
