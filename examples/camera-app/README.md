# Camera App

Demonstrates camera access, image picker, and QR code scanning.

## What It Demonstrates

- **Components:** VView, VText, VButton, VImage, VModal
- **Composables:** `useCamera`, `usePermissions`
- **Features:**
  - Take photos with camera
  - Pick from photo library
  - Scan QR codes
  - Permission handling

## Key Features

- Camera capture with preview
- Photo library access
- QR code scanning
- Permission requests
- Image display

## How to Run

```bash
cd examples/camera-app
bun install
bun vue-native dev
```

**Note:** Requires physical device or simulator with camera support.

## Key Concepts

### Camera Permissions

```typescript
const { request } = usePermissions()

const granted = await request('camera')
if (!granted) {
  alert('Camera permission required')
  return
}
```

### Take Photo

```typescript
const { launchCamera } = useCamera()

const result = await launchCamera({
  mediaType: 'photo',
  cameraType: 'back',
})

if (result.assets) {
  photoUri.value = result.assets[0].uri
}
```

### Pick from Library

```typescript
const { launchImageLibrary } = useCamera()

const result = await launchImageLibrary({
  mediaType: 'photo',
  selectionLimit: 1,
})
```

### QR Code Scanning

```typescript
const { scanQRCode, onQRCodeDetected } = useCamera()

onQRCodeDetected((data) => {
  console.log('QR Code detected:', data)
})

await scanQRCode()
```

## File Structure

```
examples/camera-app/
├── app/
│   ├── main.ts
│   ├── App.vue
│   └── CameraApp.vue
├── native/
└── package.json
```

## Learn More

- [useCamera](../../docs/src/composables/useCamera.md)
- [usePermissions](../../docs/src/composables/usePermissions.md)
- [VImage Component](../../docs/src/components/VImage.md)

## Try This

Experiment with:
1. Add video recording
2. Implement image filters
3. Add flash control
4. Create photo gallery view
5. Add image upload functionality
