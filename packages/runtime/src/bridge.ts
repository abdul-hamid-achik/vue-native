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

// __DEV__ is a compile-time constant replaced by the Vite plugin.
// This declaration makes TypeScript aware of it. At runtime without a bundler
// (e.g. in tests), the fallback below ensures it exists on globalThis.
declare const __DEV__: boolean

export type EventCallback = (payload: any) => void

export interface BridgeOperation {
  op: string
  args: any[]
}

class NativeBridgeImpl {
  /** Pending operations waiting to be flushed to native */
  private pendingOps: BridgeOperation[] = []

  /** Whether a microtask flush has been scheduled */
  private flushScheduled = false

  /** Event handler registry: "nodeId:eventName" -> callback */
  private eventHandlers = new Map<string, EventCallback>()

  /** Pending async callbacks from native module invocations */
  private pendingCallbacks = new Map<number, {
    resolve: (result: any) => void
    reject: (error: any) => void
  }>()

  /** Auto-incrementing callback ID for async native module calls */
  private nextCallbackId = 1

  /** Global event listeners: eventName -> Set of callbacks */
  private globalEventHandlers = new Map<string, Set<(payload: any) => void>>()

  // ---------------------------------------------------------------------------
  // Operation batching
  // ---------------------------------------------------------------------------

  /**
   * Enqueue an operation to be sent to the native side.
   * If this is the first operation in the current microtask cycle,
   * schedule a flush via queueMicrotask.
   */
  private enqueue(op: string, args: any[]): void {
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
    const flushFn = (globalThis as any).__VN_flushOperations
    if (typeof flushFn === 'function') {
      flushFn(json)
    } else if (__DEV__) {
      console.warn(
        '[VueNative] __VN_flushOperations is not registered. ' +
        'Make sure the Swift runtime has been initialized.'
      )
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
  updateProp(nodeId: number, key: string, value: any): void {
    this.enqueue('updateProp', [nodeId, key, value])
  }

  /**
   * Update a single style property on a native view.
   * Swift handler: handleUpdateStyle(args: [nodeId, { key: value }])
   *
   * Each style property update is sent as a dictionary with one key,
   * matching the Swift side which iterates over the dictionary entries.
   */
  updateStyle(nodeId: number, key: string, value: any): void {
    this.enqueue('updateStyle', [nodeId, { [key]: value }])
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
   * Register an event listener for a node.
   * The native side will call __VN_handleEvent when this event fires.
   * Swift handler: handleAddEventListener(args: [nodeId, eventName])
   */
  addEventListener(nodeId: number, eventName: string, callback: EventCallback): void {
    const key = `${nodeId}:${eventName}`
    this.eventHandlers.set(key, callback)
    this.enqueue('addEventListener', [nodeId, eventName])
  }

  /**
   * Remove a previously registered event listener.
   * Swift handler: handleRemoveEventListener(args: [nodeId, eventName])
   */
  removeEventListener(nodeId: number, eventName: string): void {
    const key = `${nodeId}:${eventName}`
    this.eventHandlers.delete(key)
    this.enqueue('removeEventListener', [nodeId, eventName])
  }

  /**
   * Called from Swift via globalThis.__VN_handleEvent when a native event fires.
   * Looks up the registered handler and invokes it with the event payload.
   */
  handleNativeEvent(nodeId: number, eventName: string, payload: any): void {
    const key = `${nodeId}:${eventName}`
    const handler = this.eventHandlers.get(key)
    if (handler) {
      handler(payload)
    } else if (__DEV__) {
      console.warn(
        `[VueNative] No handler registered for event "${eventName}" on node ${nodeId}`
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
   * resolves when Swift calls __VN_resolveCallback with the matching callbackId.
   */
  invokeNativeModule(moduleName: string, methodName: string, args: any[] = []): Promise<any> {
    return new Promise((resolve, reject) => {
      const callbackId = this.nextCallbackId++
      this.pendingCallbacks.set(callbackId, { resolve, reject })
      this.enqueue('invokeNativeModule', [moduleName, methodName, args, callbackId])
    })
  }

  /**
   * Invoke a native module method synchronously.
   * This sends the operation immediately and expects no callback.
   * Use sparingly -- prefer the async variant.
   */
  invokeNativeModuleSync(moduleName: string, methodName: string, args: any[] = []): void {
    this.enqueue('invokeNativeModuleSync', [moduleName, methodName, args])
  }

  /**
   * Called from Swift via globalThis.__VN_resolveCallback when an async
   * native module invocation completes.
   */
  resolveCallback(callbackId: number, result: any, error: any): void {
    const pending = this.pendingCallbacks.get(callbackId)
    if (!pending) {
      if (__DEV__) {
        console.warn(
          `[VueNative] Received callback for unknown callbackId: ${callbackId}`
        )
      }
      return
    }
    this.pendingCallbacks.delete(callbackId)
    if (error != null) {
      pending.reject(typeof error === 'string' ? new Error(error) : error)
    } else {
      pending.resolve(result)
    }
  }

  // ---------------------------------------------------------------------------
  // Global push events
  // ---------------------------------------------------------------------------

  /**
   * Register a handler for a push-based global event from native.
   * Returns an unsubscribe function.
   */
  onGlobalEvent(eventName: string, handler: (payload: any) => void): () => void {
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
  handleGlobalEvent(eventName: string, payloadJSON: string): void {
    let payload: any
    try {
      payload = JSON.parse(payloadJSON)
    } catch {
      payload = {}
    }
    const handlers = this.globalEventHandlers.get(eventName)
    if (handlers) {
      handlers.forEach(h => h(payload))
    }
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
    this.pendingCallbacks.clear()
    this.nextCallbackId = 1
    this.globalEventHandlers.clear()
  }
}

// Provide a fallback for __DEV__ if not defined (e.g. during testing).
// Avoids referencing `process` which does not exist in JavaScriptCore.
if (typeof (globalThis as any).__DEV__ === 'undefined') {
  ;(globalThis as any).__DEV__ = true
}

/**
 * Singleton bridge instance used by the renderer and application code.
 */
export const NativeBridge = new NativeBridgeImpl()

// Register global entry points that Swift calls into
;(globalThis as any).__VN_handleEvent = NativeBridge.handleNativeEvent.bind(NativeBridge)
;(globalThis as any).__VN_resolveCallback = NativeBridge.resolveCallback.bind(NativeBridge)
;(globalThis as any).__VN_handleGlobalEvent = NativeBridge.handleGlobalEvent.bind(NativeBridge)
