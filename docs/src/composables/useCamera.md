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
}
```

### Return Value

| Method | Signature | Description |
|--------|-----------|-------------|
| `launchCamera` | `(options?: CameraOptions) => Promise<CameraResult>` | Open the device camera to capture a photo. |
| `launchImageLibrary` | `(options?: CameraOptions) => Promise<CameraResult>` | Open the system photo picker to select an existing image. |

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
      <VButton title="Take Photo" :onPress="takePhoto" />
      <VButton title="Pick Image" :onPress="pickFromLibrary" />
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

## Notes

- On iOS, captured images are saved to a temporary directory as JPEG files. These are cleaned up by the OS — copy them to permanent storage if you need to keep them.
- On iOS, `launchImageLibrary` uses `PHPickerViewController` which does not require photo library permission for read-only selection.
- On iOS, camera access requires the `NSCameraUsageDescription` key in `Info.plist`.
- On Android, the default `CameraModule` is a stub that returns an error. You must provide a concrete implementation in your `VueNativeActivity` subclass using `registerForActivityResult`.
- When the user cancels, the returned `CameraResult` has `didCancel: true` and empty/zero values for `uri`, `width`, and `height`.
