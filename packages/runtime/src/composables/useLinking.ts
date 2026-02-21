import { NativeBridge } from '../bridge'

/**
 * Utilities for opening URLs and checking URL scheme support.
 *
 * @example
 * const { openURL, canOpenURL } = useLinking()
 * await openURL('https://example.com')
 */
export function useLinking() {
  async function openURL(url: string): Promise<void> {
    await NativeBridge.invokeNativeModule('Linking', 'openURL', [url])
  }

  async function canOpenURL(url: string): Promise<boolean> {
    return NativeBridge.invokeNativeModule('Linking', 'canOpenURL', [url])
  }

  return { openURL, canOpenURL }
}
