import { ref, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface SharedElementFrame {
  x: number
  y: number
  width: number
  height: number
}

export interface SharedElementRegistration {
  /** The shared element identifier. */
  id: string
  /** The native view ID this registration is bound to. */
  viewId: number
}

/** Registry of shared element IDs to their native view IDs. */
const sharedElementRegistry = new Map<string, number>()

/**
 * Register a native view id for a future shared-element transition.
 *
 * This is a **registry only**. Navigation copies `sharedElements` onto the
 * route entry; no measurement or native animation runs yet. Treat the API
 * as experimental until a real transition path exists.
 *
 * @example
 * const { register, unregister } = useSharedElementTransition('hero-image')
 *
 * // In setup, after the view is mounted:
 * register(viewId)
 *
 * // Cleanup happens automatically on unmount
 */
export function useSharedElementTransition(elementId: string) {
  const viewId = ref<number | null>(null)

  function register(nativeViewId: number): void {
    viewId.value = nativeViewId
    sharedElementRegistry.set(elementId, nativeViewId)
  }

  function unregister(): void {
    viewId.value = null
    sharedElementRegistry.delete(elementId)
  }

  onUnmounted(() => {
    unregister()
  })

  return {
    id: elementId,
    viewId,
    register,
    unregister,
  }
}

/**
 * Measure the frame (position + size) of a native view.
 * Used internally by the shared element transition system.
 */
export async function measureViewFrame(nativeViewId: number): Promise<SharedElementFrame> {
  return NativeBridge.invokeNativeModule('Animation', 'measureView', [nativeViewId])
}

/**
 * Get the registered native view ID for a shared element.
 */
export function getSharedElementViewId(elementId: string): number | undefined {
  return sharedElementRegistry.get(elementId)
}

/**
 * Get all currently registered shared element IDs.
 */
export function getRegisteredSharedElements(): string[] {
  return Array.from(sharedElementRegistry.keys())
}

/**
 * Clear all shared element registrations. Used during navigation transitions
 * to reset state.
 */
export function clearSharedElementRegistry(): void {
  sharedElementRegistry.clear()
}
