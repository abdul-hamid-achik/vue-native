import { NativeBridge } from '../bridge'

export interface ShareContent {
  message?: string
  url?: string
}

export interface ShareResult {
  shared: boolean
}

/**
 * Show the native share sheet.
 *
 * @example
 * const { share } = useShare()
 * await share({ message: 'Hello from Vue Native!', url: 'https://example.com' })
 */
export function useShare() {
  async function share(content: ShareContent): Promise<ShareResult> {
    return NativeBridge.invokeNativeModule('Share', 'share', [content])
  }

  return { share }
}
