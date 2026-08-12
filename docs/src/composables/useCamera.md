# useCamera

Launch the device camera for photo capture or open the image library to pick existing photos. Returns image metadata including a temporary file URI, dimensions, and MIME type.

## Usage

```vue
<script setup>
import { ref } from 'vue'
import { useCamera } from '@thelacanians/vue-native-runtime'

const { launchCamera, launchImageLibrary } = useCamera()
const photoUri = ref('')

async function takePhoto() {
  const result = await launchCamera()
  if (!result.didCancel) {
    photoUri.value = result.uri
  }
}
</script>
```

## API

```ts
useCamera(): {
  launchCamera: (options?: CameraOptions) => Promise<CameraResult>
  launchImageLibrary: (options?: CameraOptions) => Promise<CameraResult>
  captureVideo: (options?: VideoCaptureOptions) => Promise<VideoCaptureResult>
  scanQRCode: () => Promise<void>
  stopQRScan: () => Promise<void>
  onQRCodeDetected: (callback: (result: QRCodeResult) => void) => () => void
}
```

### Return Value

| Method | Signature | Description |
|--------|-----------|-------------|
| `launchCamera` | `(options?: CameraOptions) => Promise<CameraResult>` | Open the device camera to capture a photo. |
| `launchImageLibrary` | `(options?: CameraOptions) => Promise<CameraResult>` | Open the system photo picker to select an existing image. |
| `captureVideo` | `(options?: VideoCaptureOptions) => Promise<VideoCaptureResult>` | Record a video using the device camera. |
| `scanQRCode` | `() => Promise<void>` | Start the QR code scanner using the rear camera. |
| `stopQRScan` | `() => Promise<void>` | Stop an active QR code scanning session. |
| `onQRCodeDetected` | `(callback: (result: QRCodeResult) => void) => () => void` | Register a callback for detected QR codes. Returns an unsubscribe function. |

### Types

```ts
interface CameraOptions {
  mediaType?: 'photo' | 'video'    // Default: 'photo'
  quality?: number                  // JPEG compression 0-1. Default: 0.9
  selectionLimit?: number           // Max images to select (library only). Default: 1
}

interface CameraResult {
  uri: string           // Temporary file URI (e.g., "file:///tmp/...")
  width: number         // Image width in pixels
  height: number        // Image height in pixels
  type: string          // MIME type (e.g., "image/jpeg")
  didCancel?: boolean   // true if the user dismissed the picker
}

interface VideoCaptureOptions {
  quality?: 'low' | 'medium' | 'high'  // Video quality preset. Default: 'medium'
  maxDuration?: number                  // Maximum recording duration in seconds
  frontCamera?: boolean                 // Use front camera. Default: false
}

interface VideoCaptureResult {
  uri: string           // Temporary file URI for the recorded video
  duration: number      // Video duration in seconds
  type: string          // MIME type (e.g., "video/mp4")
  didCancel?: boolean   // true if the user cancelled recording
}

interface QRCodeResult {
  data: string          // The decoded QR code content
  type: string          // Barcode type (e.g., "qr", "ean13")
  bounds: {             // Bounding box of the detected code in the camera preview
    x: number
    y: number
    width: number
    height: number
  }
}
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `options` | `CameraOptions` | Optional configuration for media type, quality, and selection limit. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Camera uses `UIImagePickerController`. Image library uses `PHPickerViewController` (no permission dialog required for selection). Requires `NSCameraUsageDescription` in `Info.plist` for camera access. `scanQRCode` is supported. |
| Android | `launchCamera`, `launchImageLibrary`, and `captureVideo` are fully implemented via `ACTION_IMAGE_CAPTURE` / `ACTION_VIDEO_CAPTURE` intents and the system photo picker, with result payloads identical in shape to iOS. `scanQRCode` is **not implemented** -- it returns an actionable error (it would require CameraX + ML Kit or a raw Camera2 session, which this module does not depend on). `stopQRScan` is a no-op. |
| macOS | Photo capture and image selection are supported. Video capture and QR scanning return an explicit unsupported error. |

### Android specifics

- `launchImageLibrary` is **single-select on Android** -- the `selectionLimit` option has no effect there (it shares `ImagePickerModule`'s picker intent, which only supports picking one image).
- `captureVideo`'s `quality` option maps to the platform's binary `EXTRA_VIDEO_QUALITY` extra: anything other than `'low'` (including `'medium'` and `'high'`) resolves to the high-quality bucket, since Android only distinguishes low (`0`) from high (`1`).
- `frontCamera` on Android is best-effort: there is no public, guaranteed API to force the front camera on an implicit `ACTION_VIDEO_CAPTURE` intent. Some stock camera apps honor an undocumented extra; others ignore it and open on the rear camera.
- Cancellation (back button, no camera app, etc.) resolves the same `{ didCancel: true }` shape as iOS for all three methods.

## Example

```vue
<script setup>
import { ref } from 'vue'
import { useCamera } from '@thelacanians/vue-native-runtime'

const { launchCamera, launchImageLibrary } = useCamera()
const image = ref<{ uri: string; width: number; height: number } | null>(null)

async function takePhoto() {
  const result = await launchCamera({ quality: 0.8 })
  if (!result.didCancel) {
    image.value = result
  }
}

async function pickFromLibrary() {
  const result = await launchImageLibrary({ selectionLimit: 1 })
  if (!result.didCancel) {
    image.value = result
  }
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText :style="{ fontSize: 18, fontWeight: 'bold', marginBottom: 12 }">
      Camera Demo
    </VText>
    <VView :style="{ flexDirection: 'row', gap: 12, marginBottom: 16 }">
      <VButton :onPress="takePhoto"><VText>Take Photo</VText></VButton>
      <VButton :onPress="pickFromLibrary"><VText>Pick Image</VText></VButton>
    </VView>
    <VImage
      v-if="image"
      :source="{ uri: image.uri }"
      :style="{ width: 300, height: 300, borderRadius: 12 }"
      resizeMode="cover"
    />
    <VText v-if="image" :style="{ marginTop: 8, color: '#888' }">
      {{ image.width }}x{{ image.height }}
    </VText>
  </VView>
</template>
```

## Video Capture

Use `captureVideo` to record video with the device camera:

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { useCamera } from '@thelacanians/vue-native-runtime'

const { captureVideo } = useCamera()
const videoUri = ref('')

async function recordVideo() {
  const result = await captureVideo({ quality: 'high', maxDuration: 30 })
  if (!result.didCancel) {
    videoUri.value = result.uri
  }
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VButton :onPress="recordVideo"><VText>Record Video</VText></VButton>
    <VText v-if="videoUri">Recorded: {{ videoUri }}</VText>
  </VView>
</template>
```

## QR Code Scanning

Use `scanQRCode`, `stopQRScan`, and `onQRCodeDetected` to scan QR codes:

```vue
<script setup>
import { ref, onUnmounted } from '@thelacanians/vue-native-runtime'
import { useCamera } from '@thelacanians/vue-native-runtime'

const { scanQRCode, stopQRScan, onQRCodeDetected } = useCamera()
const scannedData = ref('')
const scanning = ref(false)

const unsubscribe = onQRCodeDetected((result) => {
  scannedData.value = result.data
  stopQRScan()
  scanning.value = false
})

onUnmounted(() => unsubscribe())

async function startScan() {
  scanning.value = true
  await scanQRCode()
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VButton :onPress="startScan" :disabled="scanning">
      <VText>{{ scanning ? 'Scanning...' : 'Scan QR Code' }}</VText>
    </VButton>
    <VText v-if="scannedData">Scanned: {{ scannedData }}</VText>
  </VView>
</template>
```

## Notes

- On iOS, captured images are saved to a temporary directory as JPEG files. These are cleaned up by the OS — copy them to permanent storage if you need to keep them.
- On iOS, `launchImageLibrary` uses `PHPickerViewController` which does not require photo library permission for read-only selection.
- On iOS, camera access requires the `NSCameraUsageDescription` key in `Info.plist`.
- On Android, `launchCamera` and `captureVideo` write to a private `cacheDir/vuenative-camera` file and grant the camera app write access via a `FileProvider`; the OS/app is responsible for cleaning these up eventually, so copy files you need to keep to permanent storage.
- When the user cancels, the returned `CameraResult` (or `VideoCaptureResult`) has `didCancel: true` and no `uri`/`width`/`height`/`duration` fields, on both iOS and Android.
- `captureVideo` returns the recorded video URI and duration. Videos are saved to a temporary directory.
- QR code scanning uses the rear camera on iOS. Call `stopQRScan()` to release the camera when done. On Android, `scanQRCode` rejects with an actionable error instead -- it is not implemented on that platform.
- `onQRCodeDetected` can fire multiple times if scanning continues — stop the scan after the first detection if you only need one result.
