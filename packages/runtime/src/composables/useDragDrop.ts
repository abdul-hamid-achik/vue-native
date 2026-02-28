import { ref, readonly } from '@vue/runtime-core'
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

  async function enableDropZone(): Promise<void> {
    if (!isMacOS) return
    await NativeBridge.invokeNativeModule('DragDrop', 'enableDropZone', [])
  }

  function onDrop(callback: (files: string[]) => void): () => void {
    if (!isMacOS) return () => {}
    return NativeBridge.onGlobalEvent('dragdrop:drop', (payload: any) => {
      callback(payload.files || [])
    })
  }

  function onDragEnter(callback: () => void): () => void {
    if (!isMacOS) return () => {}
    return NativeBridge.onGlobalEvent('dragdrop:enter', () => {
      isDragging.value = true
      callback()
    })
  }

  function onDragLeave(callback: () => void): () => void {
    if (!isMacOS) return () => {}
    return NativeBridge.onGlobalEvent('dragdrop:leave', () => {
      isDragging.value = false
      callback()
    })
  }

  return { enableDropZone, onDrop, onDragEnter, onDragLeave, isDragging: readonly(isDragging) }
}
