import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface UpdateInfo {
  /** Whether an update is available. */
  updateAvailable: boolean
  /** Version string of the available update. */
  version: string
  /** URL to download the update bundle. */
  downloadUrl: string
  /** Required 64-character hexadecimal SHA-256 digest of the bundle. */
  hash: string
  /** Size of the update in bytes. */
  size: number
  /** Release notes for the update. */
  releaseNotes: string
  /**
   * Base64 ECDSA (P-256, SHA-256, DER) signature over the bundle bytes.
   * Required: the native module verifies it against the publisher key
   * configured natively and rejects the update when it is missing or invalid.
   */
  signature?: string
}

export interface VersionInfo {
  /** Current bundle version identifier. */
  version: string
  /** Whether the app is currently running an OTA bundle. */
  isUsingOTA: boolean
  /** Path to the active OTA bundle, or empty string if using embedded. */
  bundlePath: string
}

export type UpdateStatus = 'idle' | 'checking' | 'downloading' | 'ready' | 'error'

const SHA256_HEX_PATTERN = /^[a-f\d]{64}$/i

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (typeof error === 'object' && error !== null && 'message' in error) {
    const message = (error as { message?: unknown }).message
    if (typeof message === 'string') return message
  }
  return String(error)
}

/**
 * Composable for managing Over-The-Air (OTA) JS bundle updates.
 *
 * Downloads versioned JS bundles from a server, verifies integrity via SHA-256
 * AND authenticity via an ECDSA (P-256) publisher signature, and applies them on
 * the next production app launch.
 *
 * ## Publisher key configuration (BREAKING CHANGE)
 *
 * The publisher key can no longer be supplied from JavaScript. It used to be set
 * with an `OTA.setVerifyKey` call, but a key settable by the very code it
 * authenticates is not a trust anchor: anything that executed once in the JS
 * context — a compromised dependency, a message injected through `VWebView` —
 * could install its own key, sign its own bundle, and pass verification.
 *
 * Configure it natively instead:
 * - **iOS:** `VueNativeOTAVerifyKey` in `Info.plist` (base64 DER / SPKI), or
 *   `OTAModule.configurePublisherKey(base64SPKI:)` from host Swift.
 * - **Android:** `<meta-data android:name="com.vuenative.ota.verifyKey" .../>` in
 *   `AndroidManifest.xml`, or `OTAModule.configurePublisherKey(base64)` from host
 *   Kotlin.
 *
 * With no key configured, updates FAIL CLOSED and are rejected — the old
 * hash-only fallback is gone, because a matching SHA-256 only proves the bytes
 * were not corrupted, not who produced them.
 *
 * Native also rejects any bundle whose version is not strictly greater than the
 * installed one, so a signed-but-older bundle cannot be reinstalled.
 *
 * @param serverUrl - URL of the update server endpoint
 * @param options.verifyKey - **Deprecated and ignored.** See above; the key must
 *   come from native configuration. Supplying it logs a warning in development.
 *
 * @example
 * ```ts
 * const {
 *   checkForUpdate, downloadUpdate, applyUpdate, rollback,
 *   currentVersion, availableVersion, downloadProgress,
 *   isChecking, isDownloading, error,
 * } = useOTAUpdate('https://updates.myapp.com/check')
 *
 * await checkForUpdate()
 * if (availableVersion.value) {
 *   await downloadUpdate()
 *   await applyUpdate()
 *   // Restart app to load the new bundle
 * }
 * ```
 */
export function useOTAUpdate(
  serverUrl: string,
  options: {
    /**
     * @deprecated Ignored. The OTA publisher key must be configured natively
     * (Info.plist `VueNativeOTAVerifyKey` on iOS, manifest meta-data
     * `com.vuenative.ota.verifyKey` on Android). A key supplied from JavaScript
     * is not a trust anchor, so `OTA.setVerifyKey` is rejected by the native
     * modules.
     */
    verifyKey?: string
  } = {},
) {
  const currentVersion = ref<string>('embedded')
  const availableVersion = ref<string | null>(null)
  const downloadProgress = ref(0)
  const isChecking = ref(false)
  const isDownloading = ref(false)
  const status = ref<UpdateStatus>('idle')
  const error = ref<string | null>(null)

  // Cached update info from last check
  let lastUpdateInfo: UpdateInfo | null = null

  // The key is no longer forwarded to native. Fail loudly rather than silently
  // ignoring the option, so an app relying on the old behaviour learns that its
  // updates are now being rejected for want of a natively configured key.
  if (options.verifyKey) {
    console.warn(
      '[vue-native] useOTAUpdate: the `verifyKey` option is ignored. Configure the OTA publisher key '
      + 'natively instead (Info.plist "VueNativeOTAVerifyKey" on iOS, AndroidManifest meta-data '
      + '"com.vuenative.ota.verifyKey" on Android). Updates are rejected until one is configured.',
    )
  }

  // Listen for download progress events
  const unsubscribe = NativeBridge.onGlobalEvent('ota:downloadProgress', (payload: {
    progress: number
    bytesDownloaded: number
    totalBytes: number
  }) => {
    downloadProgress.value = payload.progress
  })

  onUnmounted(unsubscribe)

  // Fetch current version on init
  NativeBridge.invokeNativeModule<VersionInfo>('OTA', 'getCurrentVersion', []).then((info) => {
    currentVersion.value = info.version
  }).catch((err: unknown) => {
    if (__DEV__) console.warn('[vue-native] OTA.getCurrentVersion failed:', err)
  })

  async function checkForUpdate(): Promise<UpdateInfo> {
    isChecking.value = true
    status.value = 'checking'
    error.value = null

    try {
      const info: UpdateInfo = await NativeBridge.invokeNativeModule('OTA', 'checkForUpdate', [serverUrl])
      if (info.updateAvailable) {
        if (!info.version || !info.downloadUrl || !SHA256_HEX_PATTERN.test(info.hash)) {
          throw new Error('Update server returned incomplete or invalid update metadata.')
        }
      }

      lastUpdateInfo = info
      if (info.updateAvailable) {
        availableVersion.value = info.version
      } else {
        availableVersion.value = null
      }
      status.value = 'idle'
      return info
    } catch (err: unknown) {
      error.value = getErrorMessage(err)
      status.value = 'error'
      throw err
    } finally {
      isChecking.value = false
    }
  }

  async function downloadUpdate(url?: string, hash?: string, version?: string, signature?: string): Promise<void> {
    const downloadUrl = url || lastUpdateInfo?.downloadUrl
    const expectedHash = hash || lastUpdateInfo?.hash
    const offeredVersion = version || lastUpdateInfo?.version
    const bundleSignature = signature ?? lastUpdateInfo?.signature ?? null

    if (!downloadUrl) {
      const msg = 'No download URL. Call checkForUpdate() first or provide a URL.'
      error.value = msg
      status.value = 'error'
      throw new Error(msg)
    }

    if (!expectedHash || !SHA256_HEX_PATTERN.test(expectedHash)) {
      const msg = 'A valid 64-character SHA-256 hash is required for OTA updates.'
      error.value = msg
      status.value = 'error'
      throw new Error(msg)
    }

    if (!offeredVersion) {
      const msg = 'No update version. Call checkForUpdate() first or provide a version.'
      error.value = msg
      status.value = 'error'
      throw new Error(msg)
    }

    isDownloading.value = true
    downloadProgress.value = 0
    status.value = 'downloading'
    error.value = null

    try {
      // timeoutMs=0 disables the bridge timeout: downloads are long-running and
      // report liveness via 'ota:downloadProgress' events. A fixed 30s timeout
      // would reject the promise while native is still writing, and the cleanup
      // below would then delete an in-flight download. The 4th arg carries the
      // optional publisher signature for verification when a verifyKey is set.
      await NativeBridge.invokeNativeModule('OTA', 'downloadUpdate', [downloadUrl, expectedHash, offeredVersion, bundleSignature], 0)
      status.value = 'ready'
    } catch (err: unknown) {
      // Clean up partial download to prevent corrupted bundles from being applied later
      await NativeBridge.invokeNativeModule('OTA', 'cleanupPartialDownload', []).catch((err: unknown) => {
        if (__DEV__) console.warn('[vue-native] OTA.cleanupPartialDownload failed:', err)
      })
      error.value = getErrorMessage(err)
      status.value = 'error'
      throw err
    } finally {
      isDownloading.value = false
    }
  }

  async function applyUpdate(): Promise<void> {
    if (status.value !== 'ready') {
      throw new Error('No update ready to apply. Call downloadUpdate() first.')
    }

    error.value = null

    // Verify bundle integrity before applying to prevent corrupted bundles
    try {
      await NativeBridge.invokeNativeModule('OTA', 'verifyBundle', [])
    } catch (err: unknown) {
      await NativeBridge.invokeNativeModule('OTA', 'cleanupPartialDownload', []).catch((cleanupError: unknown) => {
        if (__DEV__) console.warn('[vue-native] OTA.cleanupPartialDownload failed:', cleanupError)
      })
      status.value = 'error'
      error.value = 'Bundle verification failed: ' + getErrorMessage(err)
      throw err
    }

    try {
      await NativeBridge.invokeNativeModule('OTA', 'applyUpdate', [])
      // Refresh current version
      const info: VersionInfo = await NativeBridge.invokeNativeModule('OTA', 'getCurrentVersion', [])
      currentVersion.value = info.version
      availableVersion.value = null
      status.value = 'idle'
    } catch (err: unknown) {
      error.value = getErrorMessage(err)
      status.value = 'error'
      throw err
    }
  }

  async function rollback(): Promise<void> {
    error.value = null
    try {
      await NativeBridge.invokeNativeModule('OTA', 'rollback', [])
      const info: VersionInfo = await NativeBridge.invokeNativeModule('OTA', 'getCurrentVersion', [])
      currentVersion.value = info.version
      status.value = 'idle'
    } catch (err: unknown) {
      error.value = getErrorMessage(err)
      status.value = 'error'
      throw err
    }
  }

  async function getCurrentVersion(): Promise<VersionInfo> {
    const info: VersionInfo = await NativeBridge.invokeNativeModule('OTA', 'getCurrentVersion', [])
    currentVersion.value = info.version
    return info
  }

  return {
    checkForUpdate,
    downloadUpdate,
    applyUpdate,
    rollback,
    getCurrentVersion,
    currentVersion,
    availableVersion,
    downloadProgress,
    isChecking,
    isDownloading,
    status,
    error,
  }
}
