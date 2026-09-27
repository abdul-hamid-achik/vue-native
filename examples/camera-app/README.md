# Camera App

Demonstrates camera access, image picker, and QR code scanning.

> **Requires a native host.** This directory ships Vue source and build config
> only — there is no `ios/`, `android/`, or `macos/` app shell here. `bun run
> dev:ios`, `dev:android` and `dev:macos` build the JS bundle but have nothing
> to run it in. To see this app on a device or simulator:
>
> ```bash
> bunx vue-native create my-app   # scaffolds iOS + Android hosts
> ```
>
> Then copy `app/`, `vite.config.ts` and `env.d.ts` from this example over the
> scaffold's equivalents, run `bun run build` here, and open the generated
> project in Xcode or Android Studio. `vue-native create` does not scaffold a
> macOS shell yet.

## What It Demonstrates

- **Components:** VView, VText, VButton, VImage, VScrollView, VActivityIndicator, VSafeArea
- **Composables:** `useCamera`, `usePermissions`
- **Features:**
  - Request the camera permission before use, and handle denial
  - Capture a photo with `launchCamera()`
  - Pick an existing image with `launchImageLibrary()`
  - Display captured images and show an activity indicator while the async call runs

There is no QR-code scanning in this example. `useCamera().scanQRCode()` exists in
the runtime but is not wired up here.

## Key Features

- Camera capture
- Photo library access
- Permission request and denial handling
- Image display with an activity indicator while loading

## How to Run

```bash
cd examples/camera-app
bun install
bun run dev:ios
# or: bun run dev:android
```

This directory contains Vue source only. Copy it into a generated project with
the required iOS or Android host integration before running it. Camera capture
requires a physical device or a simulator/emulator with camera support.

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
│   └── App.vue
├── vite.config.ts
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
