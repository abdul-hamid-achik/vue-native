import { NativeBridge } from '../bridge'

export type BiometryType = 'faceID' | 'touchID' | 'opticID' | 'biometric' | 'none'

export interface BiometryResult {
  success: boolean
  error?: string
}

/**
 * Biometric authentication (Face ID / Touch ID).
 *
 * @example
 * const { authenticate, getSupportedBiometry } = useBiometry()
 * const type = await getSupportedBiometry() // 'faceID' | 'touchID' | 'biometric' | 'none'
 * const result = await authenticate('Confirm your identity')
 */
export function useBiometry() {
  async function authenticate(reason = 'Authenticate'): Promise<BiometryResult> {
    // timeoutMs=0: the Face ID / Touch ID prompt is human-gated.
    return NativeBridge.invokeNativeModule('Biometry', 'authenticate', [reason], 0)
  }

  async function getSupportedBiometry(): Promise<BiometryType> {
    return NativeBridge.invokeNativeModule('Biometry', 'getSupportedBiometry')
  }

  async function isAvailable(): Promise<boolean> {
    return NativeBridge.invokeNativeModule('Biometry', 'isAvailable')
  }

  return { authenticate, getSupportedBiometry, isAvailable }
}
