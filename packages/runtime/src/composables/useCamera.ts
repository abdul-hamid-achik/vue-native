import { onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

// ─── Types ────────────────────────────────────────────────────────────────

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

export interface VideoCaptureOptions {
  /** Video quality: 'low' | 'medium' | 'high'. Default: 'medium' */
  quality?: 'low' | 'medium' | 'high'
  /** Maximum recording duration in seconds */
  maxDuration?: number
  /** Use front camera. Default: false */
  frontCamera?: boolean
}

export interface VideoCaptureResult {
  uri: string
  duration: number
  type: string
  didCancel?: boolean
}

export interface QRCodeResult {
  /** Decoded QR code / barcode data */
  data: string
  /** Barcode type (e.g. "org.iso.QRCode", "org.gs1.EAN-13") */
  type: string
  /** Bounding rectangle of the detected code in normalized coordinates (0-1) */
  bounds: { x: number, y: number, width: number, height: number }
}

// ─── useCamera composable ─────────────────────────────────────────────────

/**
 * Camera composable for photo capture, video recording, and QR code scanning.
 *
 * @example
 * const { launchCamera, launchImageLibrary, captureVideo, scanQRCode, stopQRScan, onQRCodeDetected } = useCamera()
 *
 * // Photo
 * const photo = await launchCamera()
 * if (!photo.didCancel) imageUri.value = photo.uri
 *
 * // Video
 * const video = await captureVideo({ quality: 'high', maxDuration: 30 })
 * if (!video.didCancel) videoUri.value = video.uri
 *
 * // QR scanning
 * onQRCodeDetected((result) => {
 *   console.log('Scanned:', result.data)
 * })
 * await scanQRCode()
 */
export function useCamera() {
  const qrCleanups: Array<() => void> = []

  async function launchCamera(options: CameraOptions = {}): Promise<CameraResult> {
    return NativeBridge.invokeNativeModule('Camera', 'launchCamera', [options])
  }

  async function launchImageLibrary(options: CameraOptions = {}): Promise<CameraResult> {
    return NativeBridge.invokeNativeModule('Camera', 'launchImageLibrary', [options])
  }

  async function captureVideo(options: VideoCaptureOptions = {}): Promise<VideoCaptureResult> {
    return NativeBridge.invokeNativeModule('Camera', 'captureVideo', [options])
  }

  async function scanQRCode(): Promise<void> {
    return NativeBridge.invokeNativeModule('Camera', 'scanQRCode')
  }

  async function stopQRScan(): Promise<void> {
    return NativeBridge.invokeNativeModule('Camera', 'stopQRScan')
  }

  function onQRCodeDetected(callback: (result: QRCodeResult) => void): () => void {
    const unsubscribe = NativeBridge.onGlobalEvent('camera:qrDetected', callback)
    qrCleanups.push(unsubscribe)
    return unsubscribe
  }

  onUnmounted(() => {
    // Stop QR scanning if running
    NativeBridge.invokeNativeModule('Camera', 'stopQRScan').catch(() => {})
    // Clean up all QR event listeners
    qrCleanups.forEach(fn => fn())
    qrCleanups.length = 0
  })

  return { launchCamera, launchImageLibrary, captureVideo, scanQRCode, stopQRScan, onQRCodeDetected }
}
