import { NativeBridge } from '../bridge'

/** A node in the native view tree returned by {@link useInspector}. */
export interface ViewTreeNode {
  /** Native node id. */
  id: number
  /** Component/element type (e.g. "VView", "VText"). */
  type: string
  /** Props set on the node. */
  props?: Record<string, unknown>
  /** Layout frame in the parent's coordinate space. */
  frame?: { x: number, y: number, width: number, height: number }
  /** Child nodes. */
  children?: ViewTreeNode[]
}

/**
 * Inspector composable — introspect the live native view tree.
 *
 * Useful for debugging layout and building devtools. The tree is serialized by
 * the native side (the `Inspector` module walks its view registry).
 *
 * @example
 * ```ts
 * const { dumpTree } = useInspector()
 * const tree = await dumpTree()
 * console.log(JSON.stringify(tree, null, 2))
 * ```
 */
export function useInspector() {
  /** Dump the current native view tree (root node with nested children). */
  async function dumpTree(): Promise<ViewTreeNode | null> {
    try {
      return await NativeBridge.invokeNativeModule<ViewTreeNode | null>('Inspector', 'dumpTree', [])
    } catch {
      return null
    }
  }

  return { dumpTree }
}
