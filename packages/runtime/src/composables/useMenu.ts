import { NativeBridge } from '../bridge'
import { usePlatform } from './usePlatform'

export interface MenuItem {
  id?: string
  title: string
  key?: string
  disabled?: boolean
  separator?: boolean
}

export interface MenuSection {
  title: string
  items: MenuItem[]
}

/**
 * macOS-only composable for menu bar and context menu control.
 * No-op on iOS and Android.
 *
 * @example
 * ```ts
 * const { setAppMenu, showContextMenu, onMenuItemClick } = useMenu()
 *
 * setAppMenu([
 *   { title: 'File', items: [{ id: 'new', title: 'New', key: 'n' }] },
 *   { title: 'Edit', items: [{ id: 'copy', title: 'Copy', key: 'c' }] },
 * ])
 *
 * onMenuItemClick((id, title) => {
 *   console.log('Clicked:', id, title)
 * })
 * ```
 */
export function useMenu() {
  const { isMacOS } = usePlatform()

  async function setAppMenu(sections: MenuSection[]): Promise<void> {
    if (!isMacOS) return
    await NativeBridge.invokeNativeModule('Menu', 'setAppMenu', [sections])
  }

  async function showContextMenu(items: MenuItem[]): Promise<void> {
    if (!isMacOS) return
    await NativeBridge.invokeNativeModule('Menu', 'showContextMenu', [items])
  }

  function onMenuItemClick(callback: (id: string, title: string) => void): () => void {
    if (!isMacOS) return () => {}
    return NativeBridge.onGlobalEvent('menu:itemClick', (payload: any) => {
      callback(payload.id, payload.title)
    })
  }

  return { setAppMenu, showContextMenu, onMenuItemClick }
}
