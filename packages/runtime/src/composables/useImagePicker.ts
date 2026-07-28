import { NativeBridge } from '../bridge'

/** A photo returned by {@link useImagePicker}. */
export interface PickedImage {
  /** File URI of the picked image (a temp copy you own). */
  uri: string
  /** Pixel width of the image. */
  width: number
  /** Pixel height of the image. */
  height: number
}

/**
 * Image picker composable — present the platform photo picker and get a result.
 *
 * Backed by the native `ImagePicker` module (`PHPickerViewController` on iOS,
 * the system Photo Picker on Android, `NSOpenPanel` on macOS). Requires the
 * photos permission (see `usePermissions`).
 *
 * @example
 * ```ts
 * const { pickImage } = useImagePicker()
 * const photo = await pickImage()
 * if (photo) console.log(photo.uri, photo.width, photo.height)
 * ```
 */
export function useImagePicker() {
  /**
   * Present the photo picker. Resolves to the picked image, or `null` if the
   * user cancelled.
   */
  async function pickImage(options: { mediaType?: 'photo' } = {}): Promise<PickedImage | null> {
    try {
      return await NativeBridge.invokeNativeModule<PickedImage | null>('ImagePicker', 'pickImage', [options])
    } catch {
      return null
    }
  }

  return { pickImage }
}
