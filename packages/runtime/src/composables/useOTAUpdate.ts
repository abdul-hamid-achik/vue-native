import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface UpdateInfo {
  /** Whether an update is available. */
  updateAvailable: boolean
  /** Version string of the available update. */
  version: string
  /** URL to download the update bundle. */
  downloadUrl: string
  /** SHA-256 hash of the bundle for integrity verification. */
  hash: string
  /** Size of the update in bytes. */
  size: number
  /** Release notes for the update. */
  releaseNotes: string
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

/**
 * Composable for managing Over-The-Air (OTA) JS bundle updates.
 *
 * Downloads new JS bundles from a server, verifies integrity via SHA-256,
 * and applies them on the next app launch.
 *
 * @param serverUrl - URL of the update server endpoint
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
 *   // Restart app to load new bundle
 * }
 * ```
 */
export function useOTAUpdate(serverUrl: string) {
  const currentVersion = ref<string>('embedded')
  const availableVersion = ref<string | null>(null)
  const downloadProgress = ref(0)
  const isChecking = ref(false)
  const isDownloading = ref(false)
  const status = ref<UpdateStatus>('idle')
  const error = ref<string | null>(null)

  // Cached update info from last check
  let lastUpdateInfo: UpdateInfo | null = null

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
  NativeBridge.invokeNativeModule('OTA', 'getCurrentVersion', []).then((info: VersionInfo) => {
    currentVersion.value = info.version
  }).catch(() => {})

  async function checkForUpdate(): Promise<UpdateInfo> {
    isChecking.value = true
    status.value = 'checking'
    error.value = null

    try {
      const info: UpdateInfo = await NativeBridge.invokeNativeModule('OTA', 'checkForUpdate', [serverUrl])
      lastUpdateInfo = info
      if (info.updateAvailable) {
        availableVersion.value = info.version
      } else {
        availableVersion.value = null
      }
      status.value = info.updateAvailable ? 'idle' : 'idle'
      return info
    } catch (err: any) {
      error.value = err?.message || String(err)
      status.value = 'error'
      throw err
    } finally {
      isChecking.value = false
    }
  }

  async function downloadUpdate(url?: string, hash?: string): Promise<void> {
    const downloadUrl = url || lastUpdateInfo?.downloadUrl
    const expectedHash = hash || lastUpdateInfo?.hash

    if (!downloadUrl) {
      const msg = 'No download URL. Call checkForUpdate() first or provide a URL.'
      error.value = msg
      status.value = 'error'
      throw new Error(msg)
    }

    isDownloading.value = true
    downloadProgress.value = 0
    status.value = 'downloading'
    error.value = null

    try {
      await NativeBridge.invokeNativeModule('OTA', 'downloadUpdate', [downloadUrl, expectedHash || ''])
      status.value = 'ready'
    } catch (err: any) {
      error.value = err?.message || String(err)
      status.value = 'error'
      throw err
    } finally {
      isDownloading.value = false
    }
  }

  async function applyUpdate(): Promise<void> {
    error.value = null
    try {
      await NativeBridge.invokeNativeModule('OTA', 'applyUpdate', [])
      // Refresh current version
      const info: VersionInfo = await NativeBridge.invokeNativeModule('OTA', 'getCurrentVersion', [])
      currentVersion.value = info.version
      availableVersion.value = null
      status.value = 'idle'
    } catch (err: any) {
      error.value = err?.message || String(err)
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
    } catch (err: any) {
      error.value = err?.message || String(err)
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
