import { resetNodeId } from './node'

export type EventCallback<T = unknown> = {
  bivarianceHack(payload: T): void
}['bivarianceHack']

interface NativeBridgeGlobals {
  __DEV__?: boolean
  __VN_flushOperations?: (json: string) => void
  __VN_handleEvent?: (nodeId: number, eventName: string, payload: unknown) => void
  __VN_resolveCallback?: (callbackId: number, result: unknown, error: unknown) => void
  __VN_handleGlobalEvent?: (eventName: string, payloadJSON: string) => boolean
  __VN_teardown?: () => void
}

interface PendingCallback {
  resolve: (result: unknown) => void
  reject: (error: unknown) => void
  /** Undefined when the caller opted out of the timeout (timeoutMs <= 0). */
  timeoutId: ReturnType<typeof setTimeout> | undefined
}

const bridgeGlobals = globalThis as typeof globalThis & NativeBridgeGlobals

// Expose the compile-time hot-reload token (injected by the Vite plugin's
// `define`) as a global so the native hot-reload client can authenticate to a
// network-exposed dev server (`vue-native dev --lan`). The `typeof` guard keeps
// this safe when the define is absent (e.g. unit tests). Vite replaces the
// standalone identifier on the right but not the property key on the left.
if (typeof __HOT_RELOAD_TOKEN__ !== 'undefined') {
  ;(globalThis as typeof globalThis & { __HOT_RELOAD_TOKEN__?: string }).__HOT_RELOAD_TOKEN__ = __HOT_RELOAD_TOKEN__
}

/**
 * Vue apps mounted through createApp().start() register their unmount callback
 * here so the native hot-reload hook can dispose Vue effects before the bridge
 * state and node IDs are reset.
 */
const appTeardowns = new Set<() => void>()
const stateResets = new Set<() => void>()

/**
 * Register a mounted Vue app for native-triggered teardown.
 *
 * This intentionally lives next to the global bridge hook rather than in the
 * app entry point: native owns the hook and must be able to invoke it without
 * introducing a circular import back into index.ts.
 */
export function registerAppTeardown(teardown: () => void): () => void {
  appTeardowns.add(teardown)

  return () => {
    appTeardowns.delete(teardown)
  }
}

/** Reset renderer caches that must not survive `__VN_teardown` / hot reload. */
export function registerBridgeStateReset(reset: () => void): () => void {
  stateResets.add(reset)
  return () => {
    stateResets.delete(reset)
  }
}

function teardownMountedApps(): void {
  const teardowns = [...appTeardowns]
  appTeardowns.clear()

  for (const teardown of teardowns) {
    try {
      teardown()
    } catch (err) {
      // A failed component cleanup must not prevent the bridge from resetting
      // or leave other mounted apps alive during a hot reload.
      console.error('[VueNative] Error unmounting app during teardown:', err)
    }
  }
}

/**
 * NativeBridge -- the communication layer between JavaScript and Swift/UIKit.
 *
 * All renderer operations (create, update, insert, remove) are batched into
 * a pending operations array. On the first enqueue within a microtask cycle,
 * a queueMicrotask callback is scheduled. When the microtask fires, all
 * accumulated operations are JSON-serialized and sent to Swift via
 * `globalThis.__VN_flushOperations(json)`.
 *
 * Operation format:
 *   { op: "<name>", args: [arg0, arg1, ...] }
 *
 * This matches the Swift NativeBridge.processOperations() parser which
 * extracts `operation["op"]` and `operation["args"]`.
 *
 * This batching strategy ensures that all synchronous Vue updates triggered
 * by a single state change are coalesced into one native bridge call,
 * minimizing JS-to-native context switches.
 */

export interface BridgeOperation {
  op: string
  args: unknown[]
}

class NativeBridgeImpl {
  /** Pending operations waiting to be flushed to native */
  private pendingOps: BridgeOperation[] = []

  /** Whether a microtask flush has been scheduled */
  private flushScheduled = false

  /** Event handler registry: "nodeId:eventName" -> callbacks */
  private eventHandlers = new Map<string, Set<EventCallback>>()

  /** Pending async callbacks from native module invocations */
  private pendingCallbacks = new Map<number, PendingCallback>()

  /** Auto-incrementing callback ID for async native module calls.
   *  Wraps around at MAX_SAFE_CALLBACK_ID to prevent overflow. */
  private nextCallbackId = 1

  /** Maximum callback ID before wraparound (safe for 32-bit signed int) */
  private static readonly MAX_CALLBACK_ID = 2_147_483_647

  /** Maximum number of pending callbacks before evicting the oldest */
  private static readonly MAX_PENDING_CALLBACKS = 1000

  /** Global event listeners: eventName -> Set of callbacks */
  private globalEventHandlers = new Map<string, Set<EventCallback>>()

  // ---------------------------------------------------------------------------
  // Operation batching
  // ---------------------------------------------------------------------------

  /**
   * Enqueue an operation to be sent to the native side.
   * If this is the first operation in the current microtask cycle,
   * schedule a flush via queueMicrotask.
   */
  private enqueue(op: string, args: unknown[]): void {
    this.pendingOps.push({ op, args })
    if (!this.flushScheduled) {
      this.flushScheduled = true
      queueMicrotask(() => this.flush())
    }
  }

  /**
   * Flush all pending operations to the native side by calling
   * __VN_flushOperations with the JSON-serialized operation array.
   */
  private flush(): void {
    this.flushScheduled = false
    if (this.pendingOps.length === 0) return

    const ops = this.pendingOps
    this.pendingOps = []

    const json = JSON.stringify(ops)
    const flushFn = bridgeGlobals.__VN_flushOperations
    if (typeof flushFn === 'function') {
      try {
        flushFn(json)
      } catch (err) {
        console.error('[VueNative] Error in __VN_flushOperations:', err)
      }
    } else {
      // The native runtime is not connected: every queued operation is dropped
      // and the UI will not update. Surface this loudly (throttled) and emit a
      // 'bridge:error' global event so apps can react instead of showing a
      // blank screen with a single buried console.warn.
      this.emitBridgeError(
        '[VueNative] __VN_flushOperations is not registered — '
        + `${ops.length} operation(s) dropped. `
        + 'Make sure the native runtime has been initialized.',
      )
    }
  }

  /** Timestamp of the last bridge-error log, used to throttle repeated warnings. */
  private lastBridgeErrorAt = 0

  /**
   * Emit a bridge-level error: throttled console output plus a 'bridge:error'
   * global event that application code can subscribe to via onGlobalEvent().
   */
  private emitBridgeError(message: string): void {
    const now = Date.now()
    if (now - this.lastBridgeErrorAt >= 5000) {
      this.lastBridgeErrorAt = now
      console.error(message)
    }
    const handlers = this.globalEventHandlers.get('bridge:error')
    if (handlers) {
      handlers.forEach((h) => {
        try {
          h({ message })
        } catch (err) {
          console.error('[VueNative] Error in bridge:error handler:', err)
        }
      })
    }
  }

  /**
   * Force an immediate synchronous flush. Used for testing and for
   * critical operations that must be committed before the next microtask.
   */
  flushSync(): void {
    this.flush()
  }

  /**
   * Return the number of pending operations. Useful for testing.
   */
  getPendingCount(): number {
    return this.pendingOps.length
  }

  // ---------------------------------------------------------------------------
  // Node lifecycle operations
  //
  // Operation names match the Swift NativeBridge.processOperations() switch:
  //   "create", "createText", "setText", "setElementText"
  // ---------------------------------------------------------------------------

  /**
   * Tell native to create a new view node.
   * Swift handler: handleCreate(args: [nodeId, type])
   */
  createNode(nodeId: number, type: string): void {
    this.enqueue('create', [nodeId, type])
  }

  /**
   * Tell native to create a text node.
   * Swift handler: handleCreateText(args: [nodeId, text])
   */
  createTextNode(nodeId: number, text: string): void {
    this.enqueue('createText', [nodeId, text])
  }

  /**
   * Update the text content of a text node.
   * Swift handler: handleSetText(args: [nodeId, text])
   */
  setText(nodeId: number, text: string): void {
    this.enqueue('setText', [nodeId, text])
  }

  /**
   * Set the text content of an element node (replaces all children with text).
   * Swift handler: handleSetElementText(args: [nodeId, text])
   */
  setElementText(nodeId: number, text: string): void {
    this.enqueue('setElementText', [nodeId, text])
  }

  // ---------------------------------------------------------------------------
  // Property / style updates
  // ---------------------------------------------------------------------------

  /**
   * Update a single property on a native view.
   * Swift handler: handleUpdateProp(args: [nodeId, key, value])
   */
  updateProp(nodeId: number, key: string, value: unknown): void {
    this.enqueue('updateProp', [nodeId, key, value])
  }

  /**
   * Update a single style property on a native view.
   * Swift handler: handleUpdateStyle(args: [nodeId, { key: value }])
   *
   * Each style property update is sent as a dictionary with one key,
   * matching the Swift side which iterates over the dictionary entries.
   */
  updateStyle(nodeId: number, key: string, value: unknown): void {
    this.enqueue('updateStyle', [nodeId, { [key]: value }])
  }

  /**
   * Update multiple style properties on a native view in a single bridge op.
   * Swift/Kotlin handler: handleUpdateStyle(args: [nodeId, { key1: val1, key2: val2, ... }])
   *
   * More efficient than calling updateStyle() per property — sends one op
   * instead of N ops, reducing JSON overhead and bridge dispatch.
   */
  updateStyles(nodeId: number, styles: Record<string, unknown>): void {
    this.enqueue('updateStyle', [nodeId, styles])
  }

  // ---------------------------------------------------------------------------
  // Tree mutations
  // ---------------------------------------------------------------------------

  /**
   * Append a child node to a parent node.
   * Swift handler: handleAppendChild(args: [parentId, childId])
   */
  appendChild(parentId: number, childId: number): void {
    this.enqueue('appendChild', [parentId, childId])
  }

  /**
   * Insert a child node before a reference node within a parent.
   * Swift handler: handleInsertBefore(args: [parentId, childId, beforeId])
   */
  insertBefore(parentId: number, childId: number, anchorId: number): void {
    this.enqueue('insertBefore', [parentId, childId, anchorId])
  }

  /**
   * Remove a child node from its parent.
   * Swift handler: handleRemoveChild(args: [childId])
   * Note: Swift only needs the childId since it calls removeFromSuperview().
   */
  removeChild(_parentId: number, childId: number): void {
    this.enqueue('removeChild', [childId])
  }

  // ---------------------------------------------------------------------------
  // Event handling
  // ---------------------------------------------------------------------------

  /**
   * Register an event listener for a node. Multiple callbacks may subscribe to
   * the same (node, event) pair — e.g. a declarative gesture ref plus a manual
   * `on()` binding. The native side is only told about the first subscription.
   * Swift handler: handleAddEventListener(args: [nodeId, eventName])
   */
  addEventListener<T = unknown>(nodeId: number, eventName: string, callback: EventCallback<T>): void {
    const key = `${nodeId}:${eventName}`
    let callbacks = this.eventHandlers.get(key)
    if (!callbacks) {
      callbacks = new Set()
      this.eventHandlers.set(key, callbacks)
      this.enqueue('addEventListener', [nodeId, eventName])
    }
    callbacks.add(callback as EventCallback)
  }

  /**
   * Remove a previously registered event listener. When `callback` is given,
   * only that subscription is removed; the native listener is torn down once
   * the last subscriber for the (node, event) pair is gone. Without `callback`
   * every subscription for the pair is removed at once.
   * Swift handler: handleRemoveEventListener(args: [nodeId, eventName])
   */
  removeEventListener(nodeId: number, eventName: string, callback?: EventCallback<never>): void {
    const key = `${nodeId}:${eventName}`
    const callbacks = this.eventHandlers.get(key)
    if (!callbacks) return
    if (callback) {
      callbacks.delete(callback as EventCallback)
      if (callbacks.size > 0) return
    }
    this.eventHandlers.delete(key)
    this.enqueue('removeEventListener', [nodeId, eventName])
  }

  /**
   * Swap one callback for another on a (node, event) pair. The native listener
   * only forwards events to JS, so a handler-identity change (a fresh inline
   * closure on every render) needs no native round-trip at all.
   */
  replaceEventListener<T = unknown>(
    nodeId: number,
    eventName: string,
    oldCallback: EventCallback<never>,
    newCallback: EventCallback<T>,
  ): void {
    const key = `${nodeId}:${eventName}`
    const callbacks = this.eventHandlers.get(key)
    if (callbacks?.delete(oldCallback as EventCallback)) {
      callbacks.add(newCallback as EventCallback)
      return
    }
    this.addEventListener(nodeId, eventName, newCallback)
  }

  /**
   * Drop every event subscription for a node without emitting bridge ops.
   * Called when a node is removed from the tree: the native subtree teardown
   * already destroys the views (and their listeners), so this only has to keep
   * the JS-side registry from leaking the callbacks and whatever they close over.
   */
  releaseNode(nodeId: number): void {
    const prefix = `${nodeId}:`
    for (const key of this.eventHandlers.keys()) {
      if (key.startsWith(prefix)) {
        this.eventHandlers.delete(key)
      }
    }
  }

  /**
   * Called from Swift via globalThis.__VN_handleEvent when a native event fires.
   * Looks up the registered handlers and invokes them with the event payload.
   */
  handleNativeEvent(nodeId: number, eventName: string, payload: unknown): void {
    const key = `${nodeId}:${eventName}`
    const handlers = this.eventHandlers.get(key)
    if (handlers && handlers.size > 0) {
      for (const handler of [...handlers]) {
        try {
          handler(payload)
        } catch (err) {
          console.error(`[VueNative] Error in event handler "${eventName}" on node ${nodeId}:`, err)
        }
      }
    } else if (__DEV__) {
      console.warn(
        `[VueNative] No handler registered for event "${eventName}" on node ${nodeId}`,
      )
    }
  }

  // ---------------------------------------------------------------------------
  // Root view
  // ---------------------------------------------------------------------------

  /**
   * Tell native which node ID is the root of the view tree.
   * Swift handler: handleSetRootView(args: [nodeId])
   */
  setRootView(nodeId: number): void {
    this.enqueue('setRootView', [nodeId])
  }

  // ---------------------------------------------------------------------------
  // Native module invocation
  // ---------------------------------------------------------------------------

  /**
   * Invoke a native module method asynchronously. Returns a Promise that
   * resolves when Swift/Kotlin calls __VN_resolveCallback with the matching callbackId.
   *
   * The result is typed as `T` (default `unknown`) so callers assert the module
   * contract once at the call site — e.g. `invokeNativeModule<GeoCoordinates>(...)`
   * — and the compiler verifies the rest of the usage. The bridge cannot validate
   * the native payload at runtime, so `T` is an assertion, not a runtime check.
   *
   * A 30-second timeout is applied by default. If the native side never responds
   * (e.g. due to a crash or unregistered module), the Promise rejects with a clear
   * error instead of hanging forever. Pass `timeoutMs <= 0` to disable the timeout
   * for legitimately long-running operations (large downloads, video capture, IAP).
   */
  invokeNativeModule<T = unknown>(
    moduleName: string,
    methodName: string,
    args: unknown[] = [],
    timeoutMs = 30_000,
  ): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      // Wraparound safety: if the id is already in use, reject the orphaned
      // callback before overwriting to prevent ID collision and leaked promises.
      if (this.pendingCallbacks.has(this.nextCallbackId)) {
        const orphaned = this.pendingCallbacks.get(this.nextCallbackId)
        if (orphaned) {
          clearTimeout(orphaned.timeoutId)
          orphaned.reject(
            new Error(
              '[VueNative] Native bridge callback ID overflow — orphaned callback was rejected',
            ),
          )
        }
      }

      const callbackId = this.nextCallbackId
      if (this.nextCallbackId >= NativeBridgeImpl.MAX_CALLBACK_ID) {
        this.nextCallbackId = 1
      } else {
        this.nextCallbackId++
      }

      // timeoutMs <= 0 disables the timeout for long-running native operations.
      const timeoutId = timeoutMs > 0
        ? setTimeout(() => {
            if (this.pendingCallbacks.has(callbackId)) {
              this.pendingCallbacks.delete(callbackId)
              reject(new Error(
                `[VueNative] Native module ${moduleName}.${methodName} timed out after ${timeoutMs}ms. `
                + 'Common causes: (1) the module is not registered in NativeModuleRegistry, '
                + `(2) method '${methodName}' does not exist, or (3) the native handler crashed `
                + 'silently. Check the native logs for "[VueNative]" warnings, or pass a larger '
                + 'timeoutMs (or 0 to disable) for long-running operations.',
              ))
            }
          }, timeoutMs)
        : undefined

      // Evict oldest callback if queue is at capacity to prevent unbounded growth
      if (this.pendingCallbacks.size >= NativeBridgeImpl.MAX_PENDING_CALLBACKS) {
        const oldestKey = this.pendingCallbacks.keys().next().value
        if (oldestKey !== undefined) {
          const oldest = this.pendingCallbacks.get(oldestKey)
          if (oldest) {
            clearTimeout(oldest.timeoutId)
            oldest.reject(new Error('Callback queue full, evicting oldest pending callback'))
            this.pendingCallbacks.delete(oldestKey)
          }
        }
      }

      this.pendingCallbacks.set(callbackId, {
        resolve: result => resolve(result as T),
        reject: error => reject(error),
        timeoutId,
      })
      this.enqueue('invokeNativeModule', [moduleName, methodName, args, callbackId])
    })
  }

  /**
   * @deprecated Native module invocations cannot safely return a value through
   * the batched JSON bridge. This compatibility alias now uses the reliable
   * asynchronous callback path; migrate callers to invokeNativeModule().
   */
  invokeNativeModuleSync<T = unknown>(
    moduleName: string,
    methodName: string,
    args: unknown[] = [],
  ): Promise<T> {
    return this.invokeNativeModule<T>(moduleName, methodName, args)
  }

  /**
   * Called from Swift via globalThis.__VN_resolveCallback when an async
   * native module invocation completes.
   */
  resolveCallback(callbackId: number, result: unknown, error: unknown): void {
    const pending = this.pendingCallbacks.get(callbackId)
    if (!pending) {
      console.warn(
        `[VueNative] Received callback for unknown callbackId: ${callbackId}. `
        + 'This likely means the callback already timed out or was evicted. '
        + 'The late response has been discarded.',
      )
      return
    }
    clearTimeout(pending.timeoutId)
    this.pendingCallbacks.delete(callbackId)
    if (error != null) {
      pending.reject(typeof error === 'string' ? new Error(error) : error)
    } else {
      pending.resolve(result)
    }
  }

  /**
   * Create teleport markers in native.
   * Used for Teleport component to render content outside parent hierarchy.
   */
  createTeleport(parentId: number, startId: number, endId: number): void {
    this.enqueue('createTeleport', [parentId, startId, endId])
  }

  /**
   * Remove teleport markers from native.
   * Cleans up teleport containers and markers.
   */
  removeTeleport(parentId: number, startId: number, endId: number): void {
    this.enqueue('removeTeleport', [parentId, startId, endId])
  }

  /**
   * Move a node to a teleport target.
   * @param target - Teleport target name ('modal', 'root', etc.)
   * @param nodeId - Node ID to teleport
   */
  teleportTo(target: string, nodeId: number): void {
    this.enqueue('teleportTo', [target, nodeId])
  }

  // ---------------------------------------------------------------------------
  // Global push events
  // ---------------------------------------------------------------------------

  /**
   * Register a handler for a push-based global event from native.
   * Returns an unsubscribe function.
   */
  onGlobalEvent<T = unknown>(eventName: string, handler: EventCallback<T>): () => void {
    if (!this.globalEventHandlers.has(eventName)) {
      this.globalEventHandlers.set(eventName, new Set())
    }
    this.globalEventHandlers.get(eventName)!.add(handler)
    return () => {
      this.globalEventHandlers.get(eventName)?.delete(handler)
    }
  }

  /**
   * Called from Swift via globalThis.__VN_handleGlobalEvent when a push event fires.
   */
  handleGlobalEvent(eventName: string, payloadJSON: string): boolean {
    let payload: unknown = {}
    try {
      payload = JSON.parse(payloadJSON)
    } catch {
      payload = {}
    }
    const handlers = this.globalEventHandlers.get(eventName)
    if (!handlers || handlers.size === 0) {
      return false
    }

    handlers.forEach((h) => {
      try {
        h(payload)
      } catch (err) {
        console.error(`[VueNative] Error in global event handler "${eventName}":`, err)
      }
    })

    return true
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /**
   * Reset all internal state. Used for testing.
   */
  reset(): void {
    this.pendingOps = []
    this.flushScheduled = false
    this.eventHandlers.clear()
    // Clear pending callback timeouts before discarding the map
    for (const pending of this.pendingCallbacks.values()) {
      clearTimeout(pending.timeoutId)
    }
    this.pendingCallbacks.clear()
    this.nextCallbackId = 1
    this.globalEventHandlers.clear()
    this.lastBridgeErrorAt = 0
  }
}

// Provide a fallback for __DEV__ if not defined (e.g. during testing).
// Avoids referencing `process` which does not exist in JavaScriptCore.
if (typeof bridgeGlobals.__DEV__ === 'undefined') {
  bridgeGlobals.__DEV__ = true
}

/**
 * Singleton bridge instance used by the renderer and application code.
 */
export const NativeBridge = new NativeBridgeImpl()

// Register global entry points that Swift/Kotlin calls into
bridgeGlobals.__VN_handleEvent = NativeBridge.handleNativeEvent.bind(NativeBridge)
bridgeGlobals.__VN_resolveCallback = NativeBridge.resolveCallback.bind(NativeBridge)
bridgeGlobals.__VN_handleGlobalEvent = NativeBridge.handleGlobalEvent.bind(NativeBridge)

// Teardown function called by native before hot reload to reset all JS state
bridgeGlobals.__VN_teardown = () => {
  teardownMountedApps()
  for (const reset of stateResets) {
    try {
      reset()
    } catch (err) {
      console.error('[VueNative] Error resetting renderer state during teardown:', err)
    }
  }
  NativeBridge.reset()
  resetNodeId()
}
