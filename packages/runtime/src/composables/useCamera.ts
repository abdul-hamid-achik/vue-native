import { NativeBridge } from '../bridge'

export interface CameraOptions {
  mediaType?: 'photo' | 'video'
  quality?: number
  selectionLimit?: number
}

export interface CameraResult {
  uri: string
  width: number
  height: number
  type: string
  didCancel?: boolean
}

/**
 * Launch the camera or image library.
 *
 * @example
 * const { launchCamera, launchImageLibrary } = useCamera()
 * const result = await launchImageLibrary()
 * if (!result.didCancel) imageUri.value = result.uri
 */
export function useCamera() {
  async function launchCamera(options: CameraOptions = {}): Promise<CameraResult> {
    return NativeBridge.invokeNativeModule('Camera', 'launchCamera', [options])
  }

  async function launchImageLibrary(options: CameraOptions = {}): Promise<CameraResult> {
    return NativeBridge.invokeNativeModule('Camera', 'launchImageLibrary', [options])
  }

  return { launchCamera, launchImageLibrary }
}
