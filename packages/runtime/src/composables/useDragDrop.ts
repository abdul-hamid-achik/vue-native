import { getCurrentInstance, onUnmounted, ref, readonly } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'
import { usePlatform } from './usePlatform'

/**
 * macOS-only composable for drag and drop.
 * No-op on iOS and Android.
 *
 * @example
 * ```ts
 * const { enableDropZone, onDrop, isDragging } = useDragDrop()
 *
 * enableDropZone()
 * onDrop((files) => {
 *   console.log('Dropped files:', files)
 * })
 * ```
 */
export function useDragDrop() {
  const { isMacOS } = usePlatform()
  const isDragging = ref(false)
  const cleanups: Array<() => void> = []

  // Registered synchronously during setup so subscriptions made through the
  // on* helpers are released automatically on unmount, matching the rest of
  // the composable API (useCamera, useIAP, useNotifications).
  if (getCurrentInstance()) {
    onUnmounted(() => {
      for (const cleanup of cleanups.splice(0)) cleanup()
    })
  }

  function track(unsubscribe: () => void): () => void {
    cleanups.push(unsubscribe)
    return () => {
      const idx = cleanups.indexOf(unsubscribe)
      if (idx !== -1) cleanups.splice(idx, 1)
      unsubscribe()
    }
  }

  async function enableDropZone(): Promise<void> {
    if (!isMacOS) return
    await NativeBridge.invokeNativeModule('DragDrop', 'enableDropZone', [])
  }

  function onDrop(callback: (files: string[]) => void): () => void {
    if (!isMacOS) return () => {}
    return track(NativeBridge.onGlobalEvent<{ files?: unknown }>('dragdrop:drop', (payload) => {
      const files = Array.isArray(payload.files)
        ? payload.files.filter((file): file is string => typeof file === 'string')
        : []
      callback(files)
    }))
  }

  function onDragEnter(callback: () => void): () => void {
    if (!isMacOS) return () => {}
    return track(NativeBridge.onGlobalEvent('dragdrop:enter', () => {
      isDragging.value = true
      callback()
    }))
  }

  function onDragLeave(callback: () => void): () => void {
    if (!isMacOS) return () => {}
    return track(NativeBridge.onGlobalEvent('dragdrop:leave', () => {
      isDragging.value = false
      callback()
    }))
  }

  return { enableDropZone, onDrop, onDragEnter, onDragLeave, isDragging: readonly(isDragging) }
}
