import { NativeBridge } from '../bridge'

export type BiometryType = 'faceID' | 'touchID' | 'opticID' | 'none'

export interface BiometryResult {
  success: boolean
  error?: string
}

/**
 * Biometric authentication (Face ID / Touch ID).
 *
 * @example
 * const { authenticate, getSupportedBiometry } = useBiometry()
 * const type = await getSupportedBiometry() // 'faceID' | 'touchID' | 'none'
 * const result = await authenticate('Confirm your identity')
 */
export function useBiometry() {
  async function authenticate(reason = 'Authenticate'): Promise<BiometryResult> {
    return NativeBridge.invokeNativeModule<BiometryResult>('Biometry', 'authenticate', [reason])
  }

  async function getSupportedBiometry(): Promise<BiometryType> {
    return NativeBridge.invokeNativeModule<BiometryType>('Biometry', 'getSupportedBiometry')
  }

  async function isAvailable(): Promise<boolean> {
    return NativeBridge.invokeNativeModule<boolean>('Biometry', 'isAvailable')
  }

  return { authenticate, getSupportedBiometry, isAvailable }
}
