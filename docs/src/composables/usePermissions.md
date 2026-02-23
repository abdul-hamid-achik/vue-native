# usePermissions

Check and request runtime permissions for device capabilities such as camera, microphone, photo library, location, and notifications.

## Usage

```vue
<script setup>
import { usePermissions } from '@thelacanians/vue-native-runtime'

const { request, check } = usePermissions()

async function enableCamera() {
  const status = await check('camera')
  if (status === 'notDetermined') {
    const result = await request('camera')
    if (result === 'granted') {
      // Camera access granted
    }
  }
}
</script>
```

## API

```ts
usePermissions(): {
  request: (permission: Permission) => Promise<PermissionStatus>
  check: (permission: Permission) => Promise<PermissionStatus>
}
```

### Return Value

| Property | Type | Description |
|----------|------|-------------|
| `request` | `(permission: Permission) => Promise<PermissionStatus>` | Request a permission from the user. Shows the system dialog if the permission has not been determined yet. |
| `check` | `(permission: Permission) => Promise<PermissionStatus>` | Check the current status of a permission without prompting the user. |

### Permission Types

| Permission | Description |
|------------|-------------|
| `'camera'` | Camera access (iOS: AVCaptureDevice, Android: CAMERA) |
| `'microphone'` | Microphone access (iOS: AVCaptureDevice audio, Android: RECORD_AUDIO) |
| `'photos'` | Photo library access (iOS: PHPhotoLibrary, Android: READ_MEDIA_IMAGES or READ_EXTERNAL_STORAGE) |
| `'location'` | Location when in use (iOS: CLLocationManager, Android: ACCESS_FINE_LOCATION) |
| `'locationAlways'` | Background location access (iOS: requestAlwaysAuthorization, Android: ACCESS_BACKGROUND_LOCATION) |
| `'notifications'` | Push notification permission (iOS: UNUserNotificationCenter, Android: POST_NOTIFICATIONS on API 33+) |

### Permission Status Values

| Status | Description |
|--------|-------------|
| `'granted'` | The user has granted the permission. |
| `'denied'` | The user has denied the permission. |
| `'restricted'` | The permission is restricted by the system (iOS only, e.g. parental controls). |
| `'limited'` | Limited access granted (iOS Photos only). |
| `'notDetermined'` | The user has not yet been asked for this permission. |

## Platform Support

| Platform | Support |
|----------|---------|
| iOS | Uses native iOS permission APIs (AVFoundation, Photos, CoreLocation, UserNotifications) |
| Android | Uses Android runtime permissions via ActivityCompat. Requires the corresponding permissions in AndroidManifest.xml. |

## Example

```vue
<script setup>
import { ref } from '@thelacanians/vue-native-runtime'
import { usePermissions } from '@thelacanians/vue-native-runtime'

const { request, check } = usePermissions()
const cameraStatus = ref('unknown')
const locationStatus = ref('unknown')

async function checkCamera() {
  cameraStatus.value = await check('camera')
}

async function requestCamera() {
  cameraStatus.value = await request('camera')
}

async function requestLocation() {
  locationStatus.value = await request('location')
}
</script>

<template>
  <VView :style="{ padding: 20 }">
    <VText>Camera: {{ cameraStatus }}</VText>
    <VButton title="Check Camera" :onPress="checkCamera" />
    <VButton title="Request Camera" :onPress="requestCamera" />

    <VText :style="{ marginTop: 20 }">Location: {{ locationStatus }}</VText>
    <VButton title="Request Location" :onPress="requestLocation" />
  </VView>
</template>
```

## Notes

- On iOS, once a permission is `'denied'`, calling `request()` again will not show the system dialog. The user must enable the permission manually in Settings.
- On Android, the `'notifications'` permission only applies to API 33+ (Android 13). On older versions, notifications are allowed by default.
- The `'restricted'` status is iOS-only and indicates the permission is restricted by device policy (e.g. parental controls or MDM).
- The `'limited'` status only applies to `'photos'` on iOS, where the user has granted access to selected photos only.
- Always `check()` before `request()` to avoid showing the system dialog unnecessarily.
