import { NativeBridge } from '../bridge'
import { usePlatform } from './usePlatform'

export interface OpenFileOptions {
  multiple?: boolean
  allowedTypes?: string[]
  title?: string
}

export interface SaveFileOptions {
  title?: string
  defaultName?: string
}

/**
 * macOS-only composable for native file open/save dialogs.
 * No-op on iOS and Android.
 *
 * @example
 * ```ts
 * const { openFile, openDirectory, saveFile } = useFileDialog()
 *
 * const files = await openFile({ multiple: true, allowedTypes: ['png', 'jpg'] })
 * const dir = await openDirectory()
 * const savePath = await saveFile({ defaultName: 'export.json' })
 * ```
 */
export function useFileDialog() {
  const { isMacOS } = usePlatform()

  // timeoutMs=0 on all three: an NSOpenPanel/NSSavePanel stays open until the
  // user dismisses it, which can be far longer than the default 30s.
  async function openFile(options?: OpenFileOptions): Promise<string[] | null> {
    if (!isMacOS) return null
    return await NativeBridge.invokeNativeModule('FileDialog', 'openFile', [options || {}], 0) as string[] | null
  }

  async function openDirectory(options?: { title?: string }): Promise<string | null> {
    if (!isMacOS) return null
    return await NativeBridge.invokeNativeModule('FileDialog', 'openDirectory', [options || {}], 0) as string | null
  }

  async function saveFile(options?: SaveFileOptions): Promise<string | null> {
    if (!isMacOS) return null
    return await NativeBridge.invokeNativeModule('FileDialog', 'saveFile', [options || {}], 0) as string | null
  }

  return { openFile, openDirectory, saveFile }
}
