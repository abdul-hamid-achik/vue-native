import { NativeBridge } from '../bridge'
import { usePlatform } from './usePlatform'

export interface WindowInfo {
  width: number
  height: number
  x: number
  y: number
  isFullScreen: boolean
  isVisible: boolean
  title: string
}

/**
 * macOS-only composable for window management.
 * No-op on iOS and Android.
 *
 * @example
 * ```ts
 * const { setTitle, setSize, center, minimize, toggleFullScreen, getInfo } = useWindow()
 * setTitle('My App')
 * setSize(1024, 768)
 * ```
 */
export function useWindow() {
  const { isMacOS } = usePlatform()

  async function setTitle(title: string): Promise<void> {
    if (!isMacOS) return
    await NativeBridge.invokeNativeModule('Window', 'setTitle', [title])
  }

  async function setSize(width: number, height: number): Promise<void> {
    if (!isMacOS) return
    await NativeBridge.invokeNativeModule('Window', 'setSize', [width, height])
  }

  async function center(): Promise<void> {
    if (!isMacOS) return
    await NativeBridge.invokeNativeModule('Window', 'center', [])
  }

  async function minimize(): Promise<void> {
    if (!isMacOS) return
    await NativeBridge.invokeNativeModule('Window', 'minimize', [])
  }

  async function toggleFullScreen(): Promise<void> {
    if (!isMacOS) return
    await NativeBridge.invokeNativeModule('Window', 'toggleFullScreen', [])
  }

  async function close(): Promise<void> {
    if (!isMacOS) return
    await NativeBridge.invokeNativeModule('Window', 'close', [])
  }

  async function getInfo(): Promise<WindowInfo | null> {
    if (!isMacOS) return null
    return await NativeBridge.invokeNativeModule('Window', 'getInfo', []) as WindowInfo
  }

  return { setTitle, setSize, center, minimize, toggleFullScreen, close, getInfo }
}
