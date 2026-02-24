/**
 * Vue 3 custom renderer targeting native iOS views via NativeBridge.
 *
 * This module implements the full set of RendererOptions required by
 * @vue/runtime-core's createRenderer(). Each operation translates to a
 * bridge call that gets batched and sent to Swift as a single JSON payload.
 */

import { createRenderer, type RendererOptions } from '@vue/runtime-core'
import { type NativeNode, createNativeNode, createTextNode, createCommentNode } from './node'
import { NativeBridge } from './bridge'

/**
 * Normalize an event name from Vue's "onXxx" convention to lowercase.
 * e.g. "onPress" -> "press", "onLongPress" -> "longpress"
 */
function toEventName(key: string): string {
  return key.slice(2).toLowerCase()
}

/**
 * Diff two style objects and send only the changed properties to native.
 * - Properties in nextStyle that differ from prevStyle are updated.
 * - Properties in prevStyle missing from nextStyle are set to null (removed).
 * Errors are caught to prevent breaking the Vue render loop.
 */
function patchStyle(
  nodeId: number,
  prevStyle: Record<string, any> | null | undefined,
  nextStyle: Record<string, any> | null | undefined,
): void {
  try {
    const prev = prevStyle || {}
    const next = nextStyle || {}

    // Update changed or new properties
    for (const key in next) {
      if (next[key] !== prev[key]) {
        NativeBridge.updateStyle(nodeId, key, next[key])
      }
    }

    // Remove properties that no longer exist
    for (const key in prev) {
      if (!(key in next)) {
        NativeBridge.updateStyle(nodeId, key, null)
      }
    }
  } catch (err) {
    console.error(`[VueNative] Error patching style on node ${nodeId}:`, err)
  }
}

const nodeOps: RendererOptions<NativeNode, NativeNode> = {
  /**
   * Create a native element node.
   */
  createElement(type: string): NativeNode {
    const node = createNativeNode(type)
    NativeBridge.createNode(node.id, type)
    return node
  },

  /**
   * Create a text node containing raw text content.
   */
  createText(text: string): NativeNode {
    const node = createTextNode(text)
    NativeBridge.createTextNode(node.id, text)
    return node
  },

  /**
   * Create a comment node. Comments are invisible placeholders used by Vue
   * for anchoring conditional and list rendering. We create a JS-side node
   * but do NOT send it to native — comments have no visual representation.
   */
  createComment(text: string): NativeNode {
    return createCommentNode(text)
  },

  /**
   * Update the text content of a text node.
   */
  setText(node: NativeNode, text: string): void {
    node.text = text
    NativeBridge.setText(node.id, text)
  },

  /**
   * Set the text content of an element, replacing all its children.
   */
  setElementText(node: NativeNode, text: string): void {
    // Clear JS-side children
    for (const child of node.children) {
      child.parent = null
    }
    node.children = []
    NativeBridge.setElementText(node.id, text)
  },

  /**
   * Patch a single prop on an element. Routes to the appropriate bridge
   * method based on the prop key:
   * - "on*" keys -> event listener management
   * - "style"  -> style diffing
   * - all else -> updateProp
   */
  patchProp(
    el: NativeNode,
    key: string,
    prevValue: any,
    nextValue: any,
  ): void {
    try {
      // Event handlers: keys starting with "on" followed by uppercase letter
      if (key.startsWith('on') && key.length > 2 && key[2] === key[2].toUpperCase()) {
        const eventName = toEventName(key)

        // Remove old handler if it existed
        if (prevValue) {
          NativeBridge.removeEventListener(el.id, eventName)
        }

        // Register new handler if provided
        if (nextValue) {
          NativeBridge.addEventListener(el.id, eventName, nextValue)
        }
        return
      }

      // Style prop: diff old and new style objects
      if (key === 'style') {
        patchStyle(el.id, prevValue, nextValue)
        return
      }

      // Regular props
      el.props[key] = nextValue
      NativeBridge.updateProp(el.id, key, nextValue)
    } catch (err) {
      console.error(`[VueNative] Error patching prop "${key}" on node ${el.id}:`, err)
    }
  },

  /**
   * Insert a child node into a parent, optionally before an anchor node.
   * Manages both the JS-side tree structure and the native-side tree.
   */
  insert(child: NativeNode, parent: NativeNode, anchor: NativeNode | null): void {
    // Remove from previous parent if re-parenting
    if (child.parent) {
      const oldParent = child.parent
      const idx = oldParent.children.indexOf(child)
      if (idx !== -1) {
        oldParent.children.splice(idx, 1)
      }
    }

    child.parent = parent

    try {
      if (anchor) {
        const anchorIdx = parent.children.indexOf(anchor)
        if (anchorIdx !== -1) {
          parent.children.splice(anchorIdx, 0, child)
        } else {
          // Anchor not found — append to end
          parent.children.push(child)
        }
        // Comment nodes are not sent to native, so only send insertBefore
        // for non-comment children with a non-comment anchor
        if (child.type !== '__COMMENT__') {
          if (anchor.type !== '__COMMENT__') {
            NativeBridge.insertBefore(parent.id, child.id, anchor.id)
          } else {
            // Anchor is a comment — find the next non-comment sibling to use as anchor
            const realAnchor = findNextNonComment(parent, anchor)
            if (realAnchor) {
              NativeBridge.insertBefore(parent.id, child.id, realAnchor.id)
            } else {
              NativeBridge.appendChild(parent.id, child.id)
            }
          }
        }
      } else {
        parent.children.push(child)
        if (child.type !== '__COMMENT__') {
          NativeBridge.appendChild(parent.id, child.id)
        }
      }
    } catch (err) {
      console.error(`[VueNative] Error inserting node ${child.id} into ${parent.id}:`, err)
    }
  },

  /**
   * Remove a child from the tree.
   */
  remove(child: NativeNode): void {
    const parent = child.parent
    if (parent) {
      const idx = parent.children.indexOf(child)
      if (idx !== -1) {
        parent.children.splice(idx, 1)
      }
      child.parent = null
      try {
        if (child.type !== '__COMMENT__') {
          NativeBridge.removeChild(parent.id, child.id)
        }
      } catch (err) {
        console.error(`[VueNative] Error removing node ${child.id}:`, err)
      }
    }
  },

  /**
   * Return the parent of a node.
   */
  parentNode(node: NativeNode): NativeNode | null {
    return node.parent
  },

  /**
   * Return the next sibling of a node in the parent's children array.
   */
  nextSibling(node: NativeNode): NativeNode | null {
    const parent = node.parent
    if (!parent) return null
    const idx = parent.children.indexOf(node)
    if (idx === -1 || idx >= parent.children.length - 1) return null
    return parent.children[idx + 1]
  },
}

/**
 * Find the next non-comment sibling after `anchor` in `parent.children`.
 * Used when an anchor is a comment node (invisible on native side) and
 * we need to find a real native node to insert before.
 */
function findNextNonComment(parent: NativeNode, anchor: NativeNode): NativeNode | null {
  const idx = parent.children.indexOf(anchor)
  if (idx === -1) return null
  for (let i = idx + 1; i < parent.children.length; i++) {
    if (parent.children[i].type !== '__COMMENT__') {
      return parent.children[i]
    }
  }
  return null
}

/**
 * The Vue 3 custom renderer instance for native iOS views.
 */
const { render, createApp: baseCreateApp } = createRenderer<NativeNode, NativeNode>(nodeOps)

export { render, baseCreateApp, nodeOps }
