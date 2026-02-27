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
| iOS | Camera uses `UIImagePickerController`. Image library uses `PHPickerViewController` (no permission dialog required for selection). Requires `NSCameraUsageDescription` in `Info.plist` for camera access. |
| Android | Requires Activity-level integration. The base `CameraModule` is a stub — override your `VueNativeActivity` subclass with `registerForActivityResult` to provide camera and gallery intents. |

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
- On Android, the default `CameraModule` is a stub that returns an error. You must provide a concrete implementation in your `VueNativeActivity` subclass using `registerForActivityResult`.
- When the user cancels, the returned `CameraResult` has `didCancel: true` and empty/zero values for `uri`, `width`, and `height`.
- `captureVideo` returns the recorded video URI and duration. Videos are saved to a temporary directory.
- QR code scanning uses the rear camera. Call `stopQRScan()` to release the camera when done.
- `onQRCodeDetected` can fire multiple times if scanning continues — stop the scan after the first detection if you only need one result.
