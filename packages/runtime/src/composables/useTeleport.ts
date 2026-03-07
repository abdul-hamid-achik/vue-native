import { NativeBridge } from '../bridge'
import type { NativeNode } from '../node'

/**
 * Composable for programmatic teleportation.
 * Allows moving native nodes to different containers (e.g., modal, root).
 *
 * @param target - Teleport target name ('modal', 'root', etc.)
 * @returns Object with teleport function
 *
 * @example
 * ```ts
 * import { useTeleport } from '@thelacanians/vue-native-runtime'
 *
 * const { teleport } = useTeleport('modal')
 * const node = createNativeNode('VView')
 * teleport(node)
 * ```
 */
export function useTeleport(target: string) {
  /**
   * Teleport a native node to the specified target.
   * @param node - The native node to teleport
   */
  const teleport = (node: NativeNode): void => {
    NativeBridge.teleportTo(target, node.id)
  }

  return { teleport }
}
