# useOTAUpdate

Over-The-Air (OTA) JavaScript bundle updates for iOS and Android. Vue Native downloads a versioned bundle from your server, verifies its SHA-256 digest, and selects it on the next production app launch. OTA delivery is not a way to bypass platform rules: review the current Apple App Store and Google Play policies for dynamically downloaded code before shipping it.

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
  downloadUpdate: (url?: string, hash?: string, version?: string) => Promise<void>
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

Download a new bundle. With no arguments, it uses the URL, hash, and version from the last successful `checkForUpdate()` call. All three values are required by the native contract; a direct download must provide them explicitly.

| Parameter | Type | Description |
|-----------|------|-------------|
| `url` | `string?` | Download URL. Defaults to `lastUpdateInfo.downloadUrl`. |
| `hash` | `string?` | Expected 64-character hexadecimal SHA-256 digest. Defaults to `lastUpdateInfo.hash`. |
| `version` | `string?` | Offered version to persist with the bundle. Defaults to `lastUpdateInfo.version`. |

#### `applyUpdate()`

Verify and apply the downloaded bundle. Native code verifies the file again inside `applyUpdate()` so a caller cannot bypass the integrity check. The new bundle is selected on the next production app launch.

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

The `downloadUrl` should point to the IIFE output of your Vite build. `hash` is required and must be the lowercase or uppercase hexadecimal SHA-256 digest of those exact bytes. The runtime rejects incomplete metadata before starting a download.

## Platform Details

| Aspect | iOS | Android |
|--------|-----|---------|
| Storage location | `Application Support/VueNativeOTA/bundle-<sha256>.js` (excluded from backup) | `filesDir/VueNativeOTA/bundle-<sha256>.js` |
| Version tracking | `UserDefaults` | `SharedPreferences` |
| Hash verification | `CommonCrypto` SHA-256 | `java.security.MessageDigest` SHA-256 |
| HTTP client | `URLSession` | `OkHttp` |
| Progress events | `URLSessionDownloadDelegate` | Manual byte tracking |

Content-addressed filenames keep the active and previous bundles separate, so applying a new update does not overwrite the one retained for one-step rollback. Applied state contains the path, offered version, and verified hash; incomplete state is treated as invalid.

### Startup and fallback behavior

- When no development server is configured, the iOS and Android base hosts resolve the applied OTA state before loading the embedded bundle.
- The selected file must remain inside Vue Native's private OTA directory, be readable non-empty UTF-8 text, and still match its persisted SHA-256 digest.
- Missing, moved, unreadable, tampered, or partially persisted state is cleared and the immutable embedded bundle is loaded instead.
- If JavaScript evaluation fails, both hosts clear the applied state. Android recreates the Activity with a fresh V8 runtime; iOS clears partial timers/native state and loads the embedded bundle.
- Development-server sessions intentionally ignore applied OTA state so live reload and OTA cannot race each other.
- macOS does not currently register the OTA module or load OTA bundles. Do not advertise OTA support for macOS.

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

- **A SHA-256 hash is mandatory.** The bundle is checked after download, immediately before apply, and again during startup selection.
- **A hash is integrity metadata, not a signature.** If an attacker can replace both the bundle and the update response, the hash alone does not authenticate the publisher. Vue Native does not currently include public-key bundle-signature verification.
- **Use HTTPS for the check endpoint and bundle URL in production.** The native clients accept HTTP so local/test infrastructure can work; the framework cannot determine whether a host is production.
- Keep update metadata and bundles behind the same authentication, authorization, rollout, and audit controls you use for a production release pipeline. Consider adding native public-key signature verification before OTA is used for high-risk applications.
- Ship only JavaScript compatible with the native APIs in the installed app binary. An OTA bundle cannot add native permissions, entitlements, SDKs, components, or module methods.
- SHA-256/readability validation cannot prove application semantics. Test the exact production bundle, use staged rollout, and retain an operational rollback path.

## Notes

- OTA updates only change the JavaScript bundle. Native code changes still require an app-store release.
- The new bundle is loaded on the **next app launch** after `applyUpdate()` is called. To force an immediate reload, you would need to restart the app.
- Bundle storage uses private Application Support (iOS) or internal files storage (Android), so bundles persist across app restarts and are not exposed as user documents.
- The `rollback()` function keeps one previous applied OTA version. If that file is missing or invalid, rollback selects the embedded app-store bundle.
- Download progress events fire via `ota:downloadProgress` global events, which the composable listens to automatically.
- Automatic crash watchdogs and health-based rollout decisions are not built in. Add release telemetry and server-side rollout controls before relying on OTA in production.
- If an applied bundle fails during evaluation, iOS discards and recreates the JavaScriptCore context before loading the embedded bundle. Android invalidates the applied bundle and recreates the Activity so the embedded bundle starts in a clean V8 runtime. Physical-device failed-startup and process-relaunch behavior should still be included in release testing.
