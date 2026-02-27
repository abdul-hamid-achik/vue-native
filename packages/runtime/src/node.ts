import { markRaw } from '@vue/reactivity'

export interface NativeNode {
  id: number
  type: string // 'VView', 'VText', 'VButton', '__TEXT__', '__COMMENT__', '__ROOT__'
  props: Record<string, any>
  children: NativeNode[]
  parent: NativeNode | null
  isText: boolean
  text?: string
}

let nextNodeId = 1

/** Maximum safe node ID for 32-bit signed integer (Java/Kotlin int, Swift Int32) */
const MAX_NODE_ID = 2_147_483_647

/** Set of currently allocated node IDs for collision avoidance during wraparound */
const activeNodeIds = new Set<number>()

/**
 * Reset the node ID counter and active ID set. Used for testing and hot reload teardown.
 */
export function resetNodeId(): void {
  nextNodeId = 1
  activeNodeIds.clear()
}

/**
 * Release a node ID back to the pool. Should be called when a node is
 * removed from the tree and will no longer be referenced.
 */
export function releaseNodeId(id: number): void {
  activeNodeIds.delete(id)
}

/**
 * Get the next node ID, wrapping around at MAX_NODE_ID to prevent overflow
 * on platforms using 32-bit integers for node IDs.
 * When wrapping, skips IDs that are still in use to avoid collisions.
 */
function getNextNodeId(): number {
  const id = nextNodeId
  if (nextNodeId >= MAX_NODE_ID) {
    nextNodeId = 1
    // Skip IDs still in active use after wraparound
    while (activeNodeIds.has(nextNodeId) && nextNodeId < MAX_NODE_ID) {
      nextNodeId++
    }
  } else {
    nextNodeId++
  }
  activeNodeIds.add(id)
  return id
}

/**
 * Create a NativeNode representing a native UIKit view element.
 * The node is wrapped with markRaw() to prevent Vue's reactivity system
 * from deeply tracking its internals, which would cause performance issues
 * and unnecessary re-renders.
 */
export function createNativeNode(type: string): NativeNode {
  const node: NativeNode = {
    id: getNextNodeId(),
    type,
    props: {},
    children: [],
    parent: null,
    isText: false,
  }
  // CRITICAL: markRaw prevents Vue's reactivity from tracking node internals.
  // Without this, Vue would recursively make all node properties reactive,
  // leading to infinite loops and massive performance degradation.
  return markRaw(node)
}

/**
 * Create a text node representing raw text content.
 * Text nodes use the special '__TEXT__' type and carry their content
 * in the `text` property.
 */
export function createTextNode(text: string): NativeNode {
  const node: NativeNode = {
    id: getNextNodeId(),
    type: '__TEXT__',
    props: {},
    children: [],
    parent: null,
    isText: true,
    text,
  }
  return markRaw(node)
}

/**
 * Create a comment node used as a placeholder by Vue's virtual DOM.
 * Comments are no-ops on the native side — they exist only so Vue
 * can track insertion points for conditional/list rendering.
 */
export function createCommentNode(_text: string): NativeNode {
  const node: NativeNode = {
    id: getNextNodeId(),
    type: '__COMMENT__',
    props: {},
    children: [],
    parent: null,
    isText: false,
  }
  return markRaw(node)
}
