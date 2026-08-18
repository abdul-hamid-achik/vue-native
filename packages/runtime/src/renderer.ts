/**
 * Vue 3 custom renderer targeting native iOS views via NativeBridge.
 *
 * This module implements the full set of RendererOptions required by
 * @vue/runtime-core's createRenderer(). Each operation translates to a
 * bridge call that gets batched and sent to Swift as a single JSON payload.
 */

import { createRenderer, type RendererOptions } from '@vue/runtime-core'
import { type NativeNode, createNativeNode, createTextNode, createCommentNode, releaseNodeId } from './node'
import { NativeBridge, registerBridgeStateReset } from './bridge'

/**
 * Normalize an event name from Vue's "onXxx" convention.
 * e.g. "onPress" -> "press", "onLongPress" -> "longPress"
 */
function toEventName(key: string): string {
  const name = key.slice(2)
  return name.charAt(0).toLowerCase() + name.slice(1)
}

type EventHandler = (payload: unknown) => void

function isEventHandler(value: unknown): value is EventHandler {
  return typeof value === 'function'
}

/**
 * Vue accepts an array of event handlers. The bridge has one native callback
 * slot per event, so combine an array into a single callback before storing it.
 */
function getEventHandler(value: unknown): EventHandler | null {
  if (isEventHandler(value)) {
    return value
  }

  if (Array.isArray(value) && value.length > 0 && value.every(isEventHandler)) {
    return (payload: unknown) => {
      for (const handler of value) {
        handler(payload)
      }
    }
  }

  return null
}

/**
 * Diff two style objects and send changed properties to native as a single
 * batched `updateStyle` operation. Instead of sending one bridge op per
 * property, we collect all changed keys into one dict and send them together.
 * This reduces bridge round-trips from O(n) to O(1) per style patch.
 *
 * Errors are caught to prevent breaking the Vue render loop.
 */
function flattenStyle(style: unknown): Record<string, unknown> {
  if (style == null || style === false) return {}
  if (Array.isArray(style)) {
    const merged: Record<string, unknown> = {}
    for (const entry of style) {
      Object.assign(merged, flattenStyle(entry))
    }
    return merged
  }
  if (typeof style === 'object') {
    return style as Record<string, unknown>
  }
  return {}
}

function patchStyle(
  nodeId: number,
  prevStyle: unknown,
  nextStyle: unknown,
): void {
  try {
    const prev = flattenStyle(prevStyle)
    const next = flattenStyle(nextStyle)
    const changes: Record<string, unknown> = {}
    let hasChanges = false

    // Collect changed or new properties
    for (const key in next) {
      if (next[key] !== prev[key]) {
        changes[key] = next[key]
        hasChanges = true
      }
    }

    // Collect removed properties (set to null)
    for (const key in prev) {
      if (!(key in next)) {
        changes[key] = null
        hasChanges = true
      }
    }

    // Send all changes in a single bridge operation
    if (hasChanges) {
      NativeBridge.updateStyles(nodeId, changes)
    }
  } catch (err) {
    console.error(`[VueNative] Error patching style on node ${nodeId}:`, err)
  }
}

/**
 * Native removeChild tears down an entire native subtree in one operation.
 * Mirror that ownership change in the JS-side ID allocator so descendants do
 * not remain permanently marked as active after their parent is removed or
 * replaced with element text.
 */
function releaseSubtree(node: NativeNode): void {
  const children = node.children.splice(0)
  for (const child of children) {
    child.parent = null
    releaseSubtree(child)
  }
  // Native teardown already destroyed the views; drop the JS-side event
  // subscriptions so removed nodes cannot pin their handler closures forever.
  NativeBridge.releaseNode(node.id)
  releaseNodeId(node.id)
}

/**
 * Exact callback registered on the bridge per (node, event). Array-valued
 * props are combined into a fresh wrapper function, so removal has to target
 * the wrapper that was actually registered, not a rebuilt one.
 */
const registeredHandlers = new WeakMap<NativeNode, Map<string, EventHandler>>()

/**
 * Placeholder parent nodes returned by querySelector for <Teleport to="...">.
 * They are JS-only (never announced to native); insert() translates their
 * children into `teleportTo` operations against the named native container.
 */
const TELEPORT_TARGET_TYPE = '__TELEPORT_TARGET__'
const teleportTargets = new Map<string, NativeNode>()

registerBridgeStateReset(() => {
  teleportTargets.clear()
})

function isTeleportTarget(node: NativeNode): boolean {
  return node.type === TELEPORT_TARGET_TYPE
}

const nodeOps: RendererOptions<NativeNode, NativeNode> = {
  /**
   * Create a native element node.
   *
   * Vue core mounts detached 'div' containers for internal bookkeeping
   * (KeepAlive's storage container, Suspense's hidden container). Those are
   * created as real — but never screen-attached — VViews, so moving a subtree
   * into one detaches its native views from screen and moving it back
   * reattaches them (native appendChild moves views without destroying them).
   */
  createElement(type: string): NativeNode {
    const node = createNativeNode(type === 'div' ? 'VView' : type)
    NativeBridge.createNode(node.id, node.type)
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
    // The native operation replaces the full subtree, so clear both the
    // JS-side parent links and their allocated node IDs.
    for (const child of [...node.children]) {
      // Native setElementText only updates the component's text prop. Explicitly
      // remove existing native child subtrees first so a VView cannot retain
      // stale visual descendants when Vue switches from children to text.
      if (child.type !== '__COMMENT__') {
        NativeBridge.removeChild(node.id, child.id)
      }
      child.parent = null
      releaseSubtree(child)
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
    prevValue: unknown,
    nextValue: unknown,
  ): void {
    try {
      // Event handlers use Vue's onXxx convention. Do not claim ordinary
      // on-prefixed props (for example VSwitch.onTintColor) unless either
      // side is actually a function or an array of functions.
      const previousHandler = getEventHandler(prevValue)
      const nextHandler = getEventHandler(nextValue)
      if (/^on[A-Z]/.test(key) && (previousHandler || nextHandler)) {
        const eventName = toEventName(key)

        // Track the exact callback registered for this prop so updates and
        // removals never touch other subscribers on the same (node, event)
        // pair (manual gesture bindings, v-model listeners).
        const nodeHandlers = registeredHandlers.get(el)
        const registered = nodeHandlers?.get(eventName)

        if (registered && nextHandler) {
          // Handler-identity change: swap in place, no native round-trip.
          NativeBridge.replaceEventListener(el.id, eventName, registered, nextHandler)
          nodeHandlers!.set(eventName, nextHandler)
        } else if (registered) {
          NativeBridge.removeEventListener(el.id, eventName, registered)
          nodeHandlers!.delete(eventName)
        } else if (nextHandler) {
          NativeBridge.addEventListener(el.id, eventName, nextHandler)
          let handlerMap = nodeHandlers
          if (!handlerMap) {
            handlerMap = new Map()
            registeredHandlers.set(el, handlerMap)
          }
          handlerMap.set(eventName, nextHandler)
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
      // Children of a teleport target are appended to the named native
      // container ('modal', 'root', ...) via teleportTo. Anchor order is not
      // representable there; comments and the empty text anchors Vue mounts
      // into the target are tracked JS-side only.
      if (isTeleportTarget(parent)) {
        const anchorIdx = anchor ? parent.children.indexOf(anchor) : -1
        if (anchorIdx !== -1) {
          parent.children.splice(anchorIdx, 0, child)
        } else {
          parent.children.push(child)
        }
        if (child.type !== '__COMMENT__' && !(child.isText && !child.text)) {
          NativeBridge.teleportTo(parent.props.target as string, child.id)
        }
        return
      }

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
      releaseSubtree(child)
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

  /**
   * Resolve a string Teleport target to its placeholder parent node.
   *
   * Vue's <Teleport to="..."> resolves string targets through this hook; the
   * runtime has no DOM, so target names map to the named native containers
   * that `teleportTo` understands ('modal', 'root'). A leading '#' is
   * tolerated for DOM-style habits. One cached placeholder per name keeps
   * repeated queries pointing at the same parent node.
   */
  querySelector(selector: string): NativeNode | null {
    const name = selector.startsWith('#') ? selector.slice(1) : selector
    let target = teleportTargets.get(name)
    if (!target) {
      target = createNativeNode(TELEPORT_TARGET_TYPE)
      target.props.target = name
      teleportTargets.set(name, target)
    }
    return target
  },

  /**
   * Insert static content (for Teleport).
   * Creates teleport boundary markers.
   */
  insertStaticContent(
    content: string,
    parent: NativeNode,
    anchor: NativeNode | null,
    _namespace: string | undefined,
    _start?: NativeNode | null,
    _end?: NativeNode | null,
  ): [NativeNode, NativeNode] {
    // Create teleport boundary markers
    const startNode = createNativeNode('__TELEPORT_START__')
    const endNode = createNativeNode('__TELEPORT_END__')

    if (anchor) {
      // Insert before anchor
      const idx = parent.children.indexOf(anchor)
      if (idx !== -1) {
        parent.children.splice(idx, 0, startNode)
        parent.children.splice(idx + 1, 0, endNode)
      }
    } else {
      // Append to parent
      parent.children.push(startNode, endNode)
    }

    // Notify native bridge of teleport markers
    NativeBridge.createTeleport(parent.id, startNode.id, endNode.id)

    return [startNode, endNode]
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
