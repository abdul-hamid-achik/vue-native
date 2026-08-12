import { getCurrentInstance, onUnmounted } from '@vue/runtime-core'
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
  const cleanups: Array<() => void> = []

  // Registered synchronously during setup so onMenuItemClick subscriptions are
  // released automatically on unmount, matching the rest of the composable API.
  if (getCurrentInstance()) {
    onUnmounted(() => {
      for (const cleanup of cleanups.splice(0)) cleanup()
    })
  }

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
    const unsubscribe = NativeBridge.onGlobalEvent<{ id?: string, title?: string }>('menu:itemClick', (payload) => {
      callback(payload.id ?? '', payload.title ?? '')
    })
    cleanups.push(unsubscribe)
    return () => {
      const idx = cleanups.indexOf(unsubscribe)
      if (idx !== -1) cleanups.splice(idx, 1)
      unsubscribe()
    }
  }

  return { setAppMenu, showContextMenu, onMenuItemClick }
}
