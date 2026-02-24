# useOTAUpdate

Over-The-Air (OTA) bundle updates for deploying new JavaScript bundles without going through app store review. Downloads new bundles from your server, verifies integrity with SHA-256, and applies them on the next app launch.

## Usage

```vue
<script setup>
import { useOTAUpdate } from '@thelacanians/vue-native-runtime'

const {
  checkForUpdate, downloadUpdate, applyUpdate, rollback,
  currentVersion, availableVersion, downloadProgress,
  isChecking, isDownloading, status, error,
} = useOTAUpdate('https://updates.myapp.com/api/check')
</script>
```

## API

```ts
useOTAUpdate(serverUrl: string): {
  checkForUpdate: () => Promise<UpdateInfo>
  downloadUpdate: (url?: string, hash?: string) => Promise<void>
  applyUpdate: () => Promise<void>
  rollback: () => Promise<void>
  getCurrentVersion: () => Promise<VersionInfo>
  currentVersion: Ref<string>
  availableVersion: Ref<string | null>
  downloadProgress: Ref<number>
  isChecking: Ref<boolean>
  isDownloading: Ref<boolean>
  status: Ref<UpdateStatus>
  error: Ref<string | null>
}
```

### Methods

#### `checkForUpdate()`

Check the update server for a new bundle version. Returns the update info.

**Returns:** `Promise<UpdateInfo>`

**UpdateInfo:**

| Property | Type | Description |
|----------|------|-------------|
| `updateAvailable` | `boolean` | Whether a new version is available. |
| `version` | `string` | Version string of the available update. |
| `downloadUrl` | `string` | URL to download the new bundle. |
| `hash` | `string` | SHA-256 hash for integrity verification. |
| `size` | `number` | Bundle size in bytes. |
| `releaseNotes` | `string` | Release notes for this version. |

#### `downloadUpdate(url?, hash?)`

Download a new bundle. If `url` and `hash` are omitted, uses values from the last `checkForUpdate()` call.

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | `string?` | Download URL. Defaults to `lastUpdateInfo.downloadUrl`. |
| `hash` | `string?` | Expected SHA-256 hash. Defaults to `lastUpdateInfo.hash`. |

#### `applyUpdate()`

Apply the downloaded bundle. The new bundle will be loaded on the next app launch.

#### `rollback()`

Revert to the previous bundle version. If no previous OTA bundle exists, reverts to the embedded (app store) bundle.

#### `getCurrentVersion()`

Get the current bundle version info.

**Returns:** `Promise<VersionInfo>`

**VersionInfo:**

| Property | Type | Description |
|----------|------|-------------|
| `version` | `string` | Current bundle version identifier. |
| `isUsingOTA` | `boolean` | Whether the app is running an OTA bundle. |
| `bundlePath` | `string` | Path to the active OTA bundle, or empty if using embedded. |

### Reactive State

| Property | Type | Description |
|----------|------|-------------|
| `currentVersion` | `Ref<string>` | Current bundle version (initialized on composable creation). |
| `availableVersion` | `Ref<string \| null>` | Available update version (set after `checkForUpdate`). |
| `downloadProgress` | `Ref<number>` | Download progress from 0 to 1. |
| `isChecking` | `Ref<boolean>` | `true` while checking for updates. |
| `isDownloading` | `Ref<boolean>` | `true` while downloading a bundle. |
| `status` | `Ref<UpdateStatus>` | Current status: `'idle'`, `'checking'`, `'downloading'`, `'ready'`, or `'error'`. |
| `error` | `Ref<string \| null>` | Error message if something went wrong. |

## Update Server Requirements

Your update server must expose an endpoint that responds to GET requests with the following:

### Request Headers

The native module sends these headers with each check:

| Header | Description |
|--------|-------------|
| `X-Current-Version` | The currently installed bundle version. |
| `X-Platform` | `'ios'` or `'android'`. |
| `X-App-Id` | The app's bundle identifier / package name. |

### Response Format

The server should return JSON:

```json
{
  "updateAvailable": true,
  "version": "2.1.0",
  "downloadUrl": "https://cdn.myapp.com/bundles/2.1.0/bundle.js",
  "hash": "a1b2c3d4e5f6...sha256hash",
  "size": 245760,
  "releaseNotes": "Bug fixes and performance improvements"
}
```

When no update is available:

```json
{
  "updateAvailable": false
}
```

### Bundle Hosting

The `downloadUrl` should point to a JS bundle file. The bundle is the IIFE output of your Vite build. You can host it on any CDN or static file server.

## Platform Details

| Aspect | iOS | Android |
|--------|-----|---------|
| Storage location | `Documents/VueNativeOTA/bundle.js` | `filesDir/VueNativeOTA/bundle.js` |
| Version tracking | `UserDefaults` | `SharedPreferences` |
| Hash verification | `CommonCrypto` SHA-256 | `java.security.MessageDigest` SHA-256 |
| HTTP client | `URLSession` | `OkHttp` |
| Progress events | `URLSessionDownloadDelegate` | Manual byte tracking |

## Example

```vue
<script setup>
import { useOTAUpdate, createStyleSheet } from '@thelacanians/vue-native-runtime'

const {
  checkForUpdate, downloadUpdate, applyUpdate, rollback,
  currentVersion, availableVersion, downloadProgress,
  isChecking, isDownloading, status, error,
} = useOTAUpdate('https://updates.myapp.com/api/check')

async function handleCheckForUpdate() {
  const info = await checkForUpdate()
  if (info.updateAvailable) {
    console.log(`Update ${info.version} available (${info.size} bytes)`)
  }
}

async function handleUpdate() {
  await downloadUpdate()
  await applyUpdate()
  // The new bundle loads on next app launch
}

const styles = createStyleSheet({
  container: { flex: 1, padding: 20, justifyContent: 'center' },
  progress: { height: 4, backgroundColor: '#e0e0e0', borderRadius: 2, marginVertical: 12 },
  progressFill: { height: 4, backgroundColor: '#4FC08D', borderRadius: 2 },
  error: { color: '#e74c3c', marginTop: 8 },
})
</script>

<template>
  <VView :style="styles.container">
    <VText>Current version: {{ currentVersion }}</VText>
    <VText v-if="availableVersion">Update available: {{ availableVersion }}</VText>

    <VButton :onPress="handleCheckForUpdate" :disabled="isChecking">
      <VText>{{ isChecking ? 'Checking...' : 'Check for Update' }}</VText>
    </VButton>

    <VView v-if="isDownloading" :style="styles.progress">
      <VView :style="[styles.progressFill, { width: `${downloadProgress * 100}%` }]" />
    </VView>

    <VButton v-if="availableVersion" :onPress="handleUpdate" :disabled="isDownloading">
      <VText>{{ isDownloading ? `Downloading ${Math.round(downloadProgress * 100)}%` : 'Download & Apply' }}</VText>
    </VButton>

    <VButton :onPress="rollback">
      <VText>Rollback</VText>
    </VButton>

    <VText v-if="error" :style="styles.error">{{ error }}</VText>
  </VView>
</template>
```

## Security Considerations

- **Always provide a SHA-256 hash** with your bundles. The native module verifies the hash before saving the bundle, preventing tampered downloads from being applied.
- **Use HTTPS** for both the update check endpoint and the bundle download URL.
- **Sign your bundles** on the server side and verify signatures if your app handles sensitive data.
- The rollback mechanism ensures you can always revert to a known-good bundle if an OTA update causes issues.

## Notes

- OTA updates only change the JavaScript bundle. Native code changes still require an app store update.
- The new bundle is loaded on the **next app launch** after `applyUpdate()` is called. To force an immediate reload, you would need to restart the app.
- Bundle storage uses the app's Documents directory (iOS) or internal files directory (Android), so bundles persist across app restarts.
- The `rollback()` function keeps one previous version. If you need to roll back further, you roll back to the embedded (original app store) bundle.
- Download progress events fire via `ota:downloadProgress` global events, which the composable listens to automatically.
