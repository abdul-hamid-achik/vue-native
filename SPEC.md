# Vue Native — Technical Specification v1.0

## iOS-First Implementation (Android/Kotlin Support Planned)

**Author:** Abdul (Spec) + Claude (Research & Architecture)
**Date:** February 20, 2026
**Status:** Draft — Ready for Implementation with Claude Code

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Layer 1: JavaScript Runtime & Vue Custom Renderer](#3-layer-1-javascript-runtime--vue-custom-renderer)
4. [Layer 2: The Bridge (JS ↔ Swift Communication)](#4-layer-2-the-bridge-js--swift-communication)
5. [Layer 3: Native Component Registry (Swift/UIKit)](#5-layer-3-native-component-registry-swiftuikit)
6. [Layer 4: Layout Engine (Yoga/Flexbox)](#6-layer-4-layout-engine-yogaflexbox)
7. [Layer 5: Native Module System (Composables)](#7-layer-5-native-module-system-composables)
8. [Layer 6: Navigation System](#8-layer-6-navigation-system)
9. [Layer 7: Styling System](#9-layer-7-styling-system)
10. [Layer 8: Developer Experience & Tooling](#10-layer-8-developer-experience--tooling)
11. [Layer 9: Build System & Bundling](#11-layer-9-build-system--bundling)
12. [Layer 10: Hot Reload / Dev Server](#12-layer-10-hot-reload--dev-server)
13. [Project Structure & Monorepo](#13-project-structure--monorepo)
14. [Implementation Roadmap](#14-implementation-roadmap)
15. [Component API Reference](#15-component-api-reference)
16. [Native Module API Reference](#16-native-module-api-reference)
17. [Developer-Facing API (What Users Write)](#17-developer-facing-api-what-users-write)
18. [Performance Targets & Benchmarks](#18-performance-targets--benchmarks)
19. [Testing Strategy](#19-testing-strategy)
20. [Future: Android/Kotlin Port](#20-future-androidkotlin-port)
21. [Appendix A: React Native Architecture Comparison](#appendix-a-react-native-architecture-comparison)
22. [Appendix B: JavaScript Engine Decision Matrix](#appendix-b-javascript-engine-decision-matrix)
23. [Appendix C: Full RendererOptions Interface](#appendix-c-full-rendereroptions-interface)

---

## 1. Executive Summary

**Vue Native** is a framework that enables Vue.js 3 developers to build truly native iOS applications using Vue's Single File Components (SFCs), Composition API, and reactivity system. It renders to native UIKit components — not a WebView — achieving performance comparable to React Native.

### Core Thesis

Vue 3's `createRenderer()` API was specifically designed to allow Vue's core runtime to target non-DOM environments. By implementing a custom renderer that maps Vue's virtual node operations to native iOS UIKit views through a high-performance bridge, we can deliver a first-class mobile development experience for Vue's massive developer community.

### Why Vue Has an Advantage Over React for This

1. **Fine-grained reactivity**: Vue knows exactly which property changed and which component depends on it. No reconciliation/diffing needed for state updates — only the affected native view gets an update call. React Native must diff entire subtrees.
2. **Standalone reactivity package**: `@vue/reactivity` is ~5KB and works independently. It can power reactive state on any platform.
3. **SFC compiler with static analysis**: Vue's compiler can identify static vs dynamic template sections at build time, hoisting static content and reducing runtime work. This is critical on mobile where CPU matters.
4. **Composition API > Hooks**: No rules-of-hooks restrictions. Composables can be called conditionally, in loops, and composed freely. This maps perfectly to native module access patterns.
5. **Smaller runtime**: Vue 3's runtime-core is ~10KB gzipped vs React's ~40KB. Matters on mobile.
6. **Untapped market**: Vue has ~2M+ active developers with no production-grade native mobile story. React Native exists because React developers demanded it. Vue developers deserve the same.

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| JS Engine (Phase 1) | JavaScriptCore (built-in) | Zero app size overhead, built into iOS, proven performance, Apple-maintained |
| JS Engine (Phase 2+) | Hermes (optional) | AOT bytecode compilation, faster cold starts, smaller bundles — switchable |
| Layout Engine | Yoga (Facebook) | Battle-tested in React Native, Flexbox model familiar to web devs, Swift bindings exist via FlexLayout |
| Bridge Protocol (Phase 1) | JSON over synchronous JSC calls | Fast to implement, JSContext allows direct Swift↔JS function calls |
| Bridge Protocol (Phase 2+) | Binary MessagePack | Lower serialization overhead for high-frequency updates |
| Component Framework | UIKit | Mature, stable, well-documented. SwiftUI is too opinionated and hard to imperatively control from JS |
| Build Tooling | Vite + custom plugin | Fast HMR, native ES module support, Vue ecosystem standard |
| Package Format | Swift Package + npm | SPM for native, npm for JS packages |

---

## 2. Architecture Overview

### High-Level Data Flow

```
┌─────────────────────────────────────────────────────┐
│                  Developer's .vue Files              │
│  <template> + <script setup> + <style>               │
└─────────────────────┬───────────────────────────────┘
                      │ Vite + @vue-native/compiler
                      ▼
┌─────────────────────────────────────────────────────┐
│              Compiled Vue Component Bundle            │
│  (render functions + reactive setup + style objects)  │
└─────────────────────┬───────────────────────────────┘
                      │ Loaded by
                      ▼
┌─────────────────────────────────────────────────────┐
│   JAVASCRIPT RUNTIME (JavaScriptCore / Hermes)       │
│                                                      │
│  ┌───────────────────────────────────────────┐       │
│  │  @vue/runtime-core                        │       │
│  │  + Vue Native Custom Renderer             │       │
│  │    (implements RendererOptions)            │       │
│  │                                           │       │
│  │  createElement() → NativeBridge.create()   │       │
│  │  patchProp()     → NativeBridge.update()   │       │
│  │  insert()        → NativeBridge.insert()   │       │
│  │  remove()        → NativeBridge.remove()   │       │
│  └───────────────────┬───────────────────────┘       │
│                      │                               │
│  ┌───────────────────┴───────────────────────┐       │
│  │  NativeBridge (JS Side)                   │       │
│  │  - Batches operations per frame            │       │
│  │  - Serializes to JSON/MessagePack          │       │
│  │  - Calls Swift via JSContext bindings       │       │
│  └───────────────────┬───────────────────────┘       │
└──────────────────────┼──────────────────────────────┘
                       │ JSContext.setObject / JSExport
                       ▼
┌─────────────────────────────────────────────────────┐
│   NATIVE RUNTIME (Swift / UIKit)                     │
│                                                      │
│  ┌───────────────────────────────────────────┐       │
│  │  NativeBridge (Swift Side)                │       │
│  │  - Deserializes operations                │       │
│  │  - Routes to Component Registry           │       │
│  │  - Dispatches to main thread              │       │
│  └───────────────────┬───────────────────────┘       │
│                      │                               │
│  ┌───────────────────┴───────────────────────┐       │
│  │  Component Registry                       │       │
│  │  Maps: "VText" → UILabel                  │       │
│  │        "VView" → UIView                   │       │
│  │        "VImage" → UIImageView             │       │
│  │        "VScroll" → UIScrollView           │       │
│  │        "VList" → UITableView/UICollectionView │   │
│  │        "VInput" → UITextField             │       │
│  │        ... 40+ components                 │       │
│  └───────────────────┬───────────────────────┘       │
│                      │                               │
│  ┌───────────────────┴───────────────────────┐       │
│  │  Layout Engine (Yoga via FlexLayout)       │       │
│  │  - Receives style props                   │       │
│  │  - Computes Flexbox layout                │       │
│  │  - Applies frames to UIViews              │       │
│  └───────────────────────────────────────────┘       │
│                                                      │
│  ┌───────────────────────────────────────────┐       │
│  │  Native Module Registry                   │       │
│  │  Camera, Geolocation, Haptics, Storage,   │       │
│  │  Notifications, HealthKit, etc.            │       │
│  └───────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────┘
```

### Thread Model

```
┌─────────────────────────────────────────────────────┐
│  JS Thread                                           │
│  - Vue runtime, reactivity, component logic          │
│  - Runs on JavaScriptCore's default thread           │
│  - All user code executes here                       │
├─────────────────────────────────────────────────────┤
│  Layout Thread (Background)                          │
│  - Yoga layout calculations                          │
│  - Can run in parallel with JS thread                │
│  - Produces frame/position data for UI thread        │
├─────────────────────────────────────────────────────┤
│  Main/UI Thread                                      │
│  - All UIKit operations                              │
│  - View creation, property updates, insertions       │
│  - Animation execution                               │
│  - Touch event handling → dispatched to JS thread    │
└─────────────────────────────────────────────────────┘
```

---

## 3. Layer 1: JavaScript Runtime & Vue Custom Renderer

### 3.1 The Custom Renderer

Vue 3's `createRenderer<HostNode, HostElement>()` accepts a `RendererOptions` object that defines how to create, update, and manipulate "nodes." In standard Vue, these are DOM elements. In Vue Native, they are lightweight JS objects that represent native views.

#### Core Renderer Implementation

```typescript
// packages/runtime/src/renderer.ts

import { createRenderer, type RendererOptions } from '@vue/runtime-core'
import { NativeBridge } from './bridge'

// A lightweight JS-side representation of a native node
interface NativeNode {
  id: number           // Unique ID, used to reference the Swift-side UIView
  type: string         // Component type: "VView", "VText", "VButton", etc.
  props: Record<string, any>
  children: NativeNode[]
  parent: NativeNode | null
  isText: boolean      // True for raw text nodes (createText)
  text?: string        // Text content for text nodes
}

let nextNodeId = 1

function createNativeNode(type: string): NativeNode {
  const node: NativeNode = {
    id: nextNodeId++,
    type,
    props: {},
    children: [],
    parent: null,
    isText: false,
  }
  // Tell Swift to create this native view
  NativeBridge.createNode(node.id, type)
  return node
}

const rendererOptions: RendererOptions<NativeNode, NativeNode> = {

  // --- Element Creation ---

  createElement(type: string): NativeNode {
    return createNativeNode(type)
  },

  createText(text: string): NativeNode {
    const node: NativeNode = {
      id: nextNodeId++,
      type: '__TEXT__',
      props: {},
      children: [],
      parent: null,
      isText: true,
      text,
    }
    NativeBridge.createTextNode(node.id, text)
    return node
  },

  createComment(text: string): NativeNode {
    // Comments are no-ops in native — return a placeholder node
    return {
      id: nextNodeId++,
      type: '__COMMENT__',
      props: {},
      children: [],
      parent: null,
      isText: false,
    }
  },

  // --- Text Operations ---

  setText(node: NativeNode, text: string): void {
    if (node.isText) {
      node.text = text
      NativeBridge.setText(node.id, text)
    }
  },

  setElementText(node: NativeNode, text: string): void {
    // Sets text content of an element (like innerHTML for text)
    // Clear children and set text directly
    NativeBridge.setElementText(node.id, text)
  },

  // --- Property Patching ---

  patchProp(
    el: NativeNode,
    key: string,
    prevValue: any,
    nextValue: any
  ): void {
    if (key.startsWith('on')) {
      // Event handler: onPress, onChangeText, onScroll, etc.
      const eventName = key.slice(2).toLowerCase()
      if (nextValue) {
        NativeBridge.addEventListener(el.id, eventName, nextValue)
      } else {
        NativeBridge.removeEventListener(el.id, eventName)
      }
    } else if (key === 'style') {
      // Style object — diff and send only changed properties
      const prevStyle = prevValue || {}
      const nextStyle = nextValue || {}
      const changes: Record<string, any> = {}
      
      // Find changed or new properties
      for (const prop in nextStyle) {
        if (nextStyle[prop] !== prevStyle[prop]) {
          changes[prop] = nextStyle[prop]
        }
      }
      // Find removed properties (set to null)
      for (const prop in prevStyle) {
        if (!(prop in nextStyle)) {
          changes[prop] = null
        }
      }
      
      if (Object.keys(changes).length > 0) {
        NativeBridge.updateStyle(el.id, changes)
      }
    } else {
      // Regular prop update
      el.props[key] = nextValue
      NativeBridge.updateProp(el.id, key, nextValue)
    }
  },

  // --- Tree Operations ---

  insert(child: NativeNode, parent: NativeNode, anchor?: NativeNode | null): void {
    if (child.type === '__COMMENT__') return // skip comments
    
    child.parent = parent
    if (anchor) {
      const index = parent.children.indexOf(anchor)
      parent.children.splice(index, 0, child)
      NativeBridge.insertBefore(parent.id, child.id, anchor.id)
    } else {
      parent.children.push(child)
      NativeBridge.appendChild(parent.id, child.id)
    }
  },

  remove(child: NativeNode): void {
    if (child.type === '__COMMENT__') return
    
    if (child.parent) {
      const index = child.parent.children.indexOf(child)
      if (index > -1) child.parent.children.splice(index, 1)
    }
    child.parent = null
    NativeBridge.removeChild(child.id)
  },

  // --- Parent/Sibling Traversal ---

  parentNode(node: NativeNode): NativeNode | null {
    return node.parent
  },

  nextSibling(node: NativeNode): NativeNode | null {
    if (!node.parent) return null
    const index = node.parent.children.indexOf(node)
    return node.parent.children[index + 1] || null
  },

  // --- Misc ---

  setScopeId(el: NativeNode, id: string): void {
    // Scoped styles — we handle this differently in native
    // Store for potential use in style isolation
    el.props.__scopeId = id
  },
}

// Create the renderer and export the public API
const { render, createApp: baseCreateApp } = createRenderer(rendererOptions)

// Wrap createApp to inject Vue Native defaults
export function createApp(rootComponent: any, rootProps?: any) {
  const app = baseCreateApp(rootComponent, rootProps)
  
  // Register built-in components
  app.component('VView', VViewComponent)
  app.component('VText', VTextComponent)
  app.component('VButton', VButtonComponent)
  app.component('VImage', VImageComponent)
  app.component('VScroll', VScrollComponent)
  app.component('VInput', VInputComponent)
  app.component('VList', VListComponent)
  app.component('VStack', VStackComponent)
  // ... more built-in components
  
  // Custom start method for native
  const originalMount = app.mount.bind(app)
  app.start = () => {
    // Create a virtual root node
    const root = createNativeNode('__ROOT__')
    NativeBridge.setRootView(root.id)
    originalMount(root as any)
    return app
  }
  
  return app
}

// Re-export Vue core APIs
export * from '@vue/runtime-core'
```

### 3.2 Built-in Component Definitions (JS Side)

Each built-in component is a thin Vue component that maps to a native element type:

```typescript
// packages/runtime/src/components/VView.ts
import { defineComponent, h } from '@vue/runtime-core'

export const VViewComponent = defineComponent({
  name: 'VView',
  props: {
    style: Object,
    accessibilityLabel: String,
    accessibilityHint: String,
    testID: String,
  },
  setup(props, { slots }) {
    return () => h('VView', { ...props }, slots.default?.())
  }
})

// packages/runtime/src/components/VText.ts
export const VTextComponent = defineComponent({
  name: 'VText',
  props: {
    style: Object,
    numberOfLines: Number,
    selectable: Boolean,
    accessibilityRole: String,
  },
  setup(props, { slots }) {
    return () => h('VText', { ...props }, slots.default?.())
  }
})

// packages/runtime/src/components/VButton.ts
export const VButtonComponent = defineComponent({
  name: 'VButton',
  props: {
    style: Object,
    disabled: Boolean,
    onPress: Function,
    onLongPress: Function,
    activeOpacity: { type: Number, default: 0.7 },
  },
  setup(props, { slots }) {
    return () => h('VButton', { ...props }, slots.default?.())
  }
})

// packages/runtime/src/components/VInput.ts
export const VInputComponent = defineComponent({
  name: 'VInput',
  props: {
    modelValue: String,
    placeholder: String,
    secureTextEntry: Boolean,
    keyboardType: String,    // 'default' | 'numeric' | 'email' | 'phone'
    returnKeyType: String,   // 'done' | 'next' | 'search' | 'go'
    autoCapitalize: String,  // 'none' | 'sentences' | 'words' | 'characters'
    autoCorrect: Boolean,
    maxLength: Number,
    multiline: Boolean,
    style: Object,
  },
  emits: ['update:modelValue', 'focus', 'blur', 'submit'],
  setup(props, { emit }) {
    return () => h('VInput', {
      ...props,
      text: props.modelValue,
      onChangetext: (text: string) => emit('update:modelValue', text),
      onFocus: () => emit('focus'),
      onBlur: () => emit('blur'),
      onSubmit: () => emit('submit'),
    })
  }
})

// packages/runtime/src/components/VImage.ts
export const VImageComponent = defineComponent({
  name: 'VImage',
  props: {
    source: [String, Object],  // URL string or { uri, width, height } object
    resizeMode: {
      type: String,
      default: 'cover',        // 'cover' | 'contain' | 'stretch' | 'center'
    },
    style: Object,
    onLoad: Function,
    onError: Function,
  },
  setup(props) {
    return () => h('VImage', { ...props })
  }
})

// packages/runtime/src/components/VList.ts
export const VListComponent = defineComponent({
  name: 'VList',
  props: {
    data: { type: Array, required: true },
    keyExtractor: { type: Function, required: true },
    renderItem: { type: Function, required: true },
    horizontal: Boolean,
    showsScrollIndicator: { type: Boolean, default: true },
    onEndReached: Function,
    onEndReachedThreshold: { type: Number, default: 0.5 },
    refreshing: Boolean,
    onRefresh: Function,
    style: Object,
    itemHeight: Number,  // For fixed-height optimization
  },
  setup(props) {
    // VList uses a special native component that handles view recycling
    // Items are rendered lazily as they scroll into view
    return () => h('VList', {
      ...props,
      // The native side will call back to JS to render each item
      // using the renderItem function
    })
  }
})

// packages/runtime/src/components/VStack.ts  
// Convenience component — a VView with flexDirection pre-set
export const VStackComponent = defineComponent({
  name: 'VStack',
  props: {
    direction: { type: String, default: 'column' }, // 'column' | 'row'
    spacing: Number,
    padding: [Number, Object],
    align: String,      // maps to alignItems
    justify: String,    // maps to justifyContent
    style: Object,
  },
  setup(props, { slots }) {
    const style = {
      flexDirection: props.direction,
      gap: props.spacing,
      padding: props.padding,
      alignItems: props.align,
      justifyContent: props.justify,
      ...props.style,
    }
    return () => h('VView', { style }, slots.default?.())
  }
})
```

---

## 4. Layer 2: The Bridge (JS ↔ Swift Communication)

### 4.1 Bridge Design Philosophy

The bridge is the most critical performance component. We implement it in two phases:

**Phase 1 (MVP):** Direct JSContext function calls with JSON payloads. iOS's built-in JavaScriptCore framework allows Swift functions to be registered as callable JS functions, and vice versa. This is synchronous on the JS side and requires no serialization overhead for simple types.

**Phase 2 (Optimization):** Operation batching + MessagePack binary serialization for high-frequency updates (animations, scrolling).

### 4.2 Bridge — JavaScript Side

```typescript
// packages/runtime/src/bridge.ts

type EventCallback = (...args: any[]) => void

interface PendingOperation {
  op: 'create' | 'createText' | 'setText' | 'setElementText' |
      'updateProp' | 'updateStyle' | 'insertBefore' | 'appendChild' |
      'removeChild' | 'addEventListener' | 'removeEventListener' |
      'setRootView'
  args: any[]
}

class NativeBridgeImpl {
  private eventHandlers: Map<string, EventCallback> = new Map()
  private pendingOps: PendingOperation[] = []
  private isFlushing: boolean = false
  private batchMode: boolean = false

  // Called from Swift when a native event occurs
  // This function is registered on the global scope so Swift can call it
  handleNativeEvent(nodeId: number, eventName: string, payload: any): void {
    const key = `${nodeId}:${eventName}`
    const handler = this.eventHandlers.get(key)
    if (handler) {
      handler(payload)
    }
  }

  // --- Public API used by the renderer ---

  createNode(id: number, type: string): void {
    this.enqueue({ op: 'create', args: [id, type] })
  }

  createTextNode(id: number, text: string): void {
    this.enqueue({ op: 'createText', args: [id, text] })
  }

  setText(id: number, text: string): void {
    this.enqueue({ op: 'setText', args: [id, text] })
  }

  setElementText(id: number, text: string): void {
    this.enqueue({ op: 'setElementText', args: [id, text] })
  }

  updateProp(id: number, key: string, value: any): void {
    this.enqueue({ op: 'updateProp', args: [id, key, value] })
  }

  updateStyle(id: number, changes: Record<string, any>): void {
    this.enqueue({ op: 'updateStyle', args: [id, changes] })
  }

  insertBefore(parentId: number, childId: number, anchorId: number): void {
    this.enqueue({ op: 'insertBefore', args: [parentId, childId, anchorId] })
  }

  appendChild(parentId: number, childId: number): void {
    this.enqueue({ op: 'appendChild', args: [parentId, childId] })
  }

  removeChild(childId: number): void {
    this.enqueue({ op: 'removeChild', args: [childId] })
  }

  addEventListener(id: number, eventName: string, handler: EventCallback): void {
    const key = `${id}:${eventName}`
    this.eventHandlers.set(key, handler)
    this.enqueue({ op: 'addEventListener', args: [id, eventName] })
  }

  removeEventListener(id: number, eventName: string): void {
    const key = `${id}:${eventName}`
    this.eventHandlers.delete(key)
    this.enqueue({ op: 'removeEventListener', args: [id, eventName] })
  }

  setRootView(id: number): void {
    this.enqueue({ op: 'setRootView', args: [id] })
  }

  // --- Invoke a native module method (async) ---

  async invokeNativeModule(moduleName: string, methodName: string, args: any[]): Promise<any> {
    return new Promise((resolve, reject) => {
      const callbackId = this.registerCallback(resolve, reject)
      // __VN_invokeModule is registered by Swift on the JSContext
      ;(globalThis as any).__VN_invokeModule(moduleName, methodName, JSON.stringify(args), callbackId)
    })
  }

  // --- Invoke a native module method (sync, for fast reads) ---

  invokeNativeModuleSync(moduleName: string, methodName: string, args: any[]): any {
    const result = (globalThis as any).__VN_invokeModuleSync(moduleName, methodName, JSON.stringify(args))
    return JSON.parse(result)
  }

  // --- Operation Batching ---

  private enqueue(op: PendingOperation): void {
    this.pendingOps.push(op)
    if (!this.isFlushing) {
      this.scheduleFlush()
    }
  }

  private scheduleFlush(): void {
    // Microtask-based batching: all synchronous Vue updates are collected,
    // then flushed in one batch to native.
    // queueMicrotask ensures we flush after the current synchronous execution
    // but before the next frame.
    if (!this.batchMode) {
      queueMicrotask(() => this.flush())
      this.batchMode = true
    }
  }

  private flush(): void {
    this.isFlushing = true
    this.batchMode = false
    
    if (this.pendingOps.length === 0) {
      this.isFlushing = false
      return
    }

    // Send all operations to Swift in a single call
    const ops = this.pendingOps
    this.pendingOps = []

    // __VN_flushOperations is registered by Swift on the JSContext
    ;(globalThis as any).__VN_flushOperations(JSON.stringify(ops))

    this.isFlushing = false
  }

  // --- Callback management for async native calls ---

  private callbackCounter = 0
  private pendingCallbacks: Map<number, { resolve: Function; reject: Function }> = new Map()

  private registerCallback(resolve: Function, reject: Function): number {
    const id = this.callbackCounter++
    this.pendingCallbacks.set(id, { resolve, reject })
    return id
  }

  // Called from Swift when an async operation completes
  resolveCallback(callbackId: number, result: string | null, error: string | null): void {
    const cb = this.pendingCallbacks.get(callbackId)
    if (cb) {
      this.pendingCallbacks.delete(callbackId)
      if (error) {
        cb.reject(new Error(error))
      } else {
        cb.resolve(result ? JSON.parse(result) : null)
      }
    }
  }
}

export const NativeBridge = new NativeBridgeImpl()

// Expose to global scope so Swift can call these
;(globalThis as any).__VN_handleEvent = NativeBridge.handleNativeEvent.bind(NativeBridge)
;(globalThis as any).__VN_resolveCallback = NativeBridge.resolveCallback.bind(NativeBridge)
```

### 4.3 Bridge — Swift Side

```swift
// Sources/VueNativeCore/Bridge/NativeBridge.swift

import JavaScriptCore
import UIKit

/// The main bridge between JavaScript and native Swift.
/// Manages the JSContext, registers native functions, and processes operations.
class NativeBridge {
    
    static let shared = NativeBridge()
    
    private var jsContext: JSContext!
    private var jsThread: Thread!
    private let componentRegistry = ComponentRegistry.shared
    private let moduleRegistry = NativeModuleRegistry.shared
    
    /// Map of node IDs to their native UIView instances
    private var viewRegistry: [Int: UIView] = [:]
    
    /// Map of node IDs to their Yoga layout nodes
    private var layoutNodes: [Int: YogaNode] = [:]
    
    /// The root view controller's view
    private var rootView: UIView?
    
    // MARK: - Initialization
    
    func initialize(rootViewController: UIViewController) {
        self.rootView = rootViewController.view
        
        // Create JS context on a dedicated thread
        jsThread = Thread {
            self.jsContext = JSContext()
            self.jsContext.exceptionHandler = { context, exception in
                print("[Vue Native] JS Error: \(exception?.toString() ?? "unknown")")
            }
            
            // Register native functions on the JS context
            self.registerBridgeFunctions()
            
            // Load polyfills (setTimeout, setInterval, console, etc.)
            self.loadPolyfills()
            
            // Load the Vue Native runtime bundle
            self.loadBundle()
            
            // Start the JS run loop
            RunLoop.current.run()
        }
        jsThread.name = "com.vuenative.js"
        jsThread.start()
    }
    
    // MARK: - Register Bridge Functions
    
    private func registerBridgeFunctions() {
        
        // __VN_flushOperations: Called from JS with a batch of UI operations
        let flushOps: @convention(block) (String) -> Void = { [weak self] opsJson in
            guard let self = self,
                  let data = opsJson.data(using: .utf8),
                  let ops = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { return }
            
            // Process all operations on the main thread
            DispatchQueue.main.async {
                self.processOperations(ops)
            }
        }
        jsContext.setObject(flushOps, forKeyedSubscript: "__VN_flushOperations" as NSString)
        
        // __VN_invokeModule: Async native module invocation
        let invokeModule: @convention(block) (String, String, String, Int) -> Void = {
            [weak self] moduleName, methodName, argsJson, callbackId in
            guard let self = self else { return }
            
            self.moduleRegistry.invoke(
                module: moduleName,
                method: methodName,
                args: argsJson,
                callback: { result, error in
                    // Resolve on JS thread
                    self.performOnJSThread {
                        let resultJson = result.flatMap { try? String(data: JSONSerialization.data(withJSONObject: $0), encoding: .utf8) }
                        self.jsContext.evaluateScript(
                            "__VN_resolveCallback(\(callbackId), \(resultJson.map { "'\($0)'" } ?? "null"), \(error.map { "'\($0)'" } ?? "null"))"
                        )
                    }
                }
            )
        }
        jsContext.setObject(invokeModule, forKeyedSubscript: "__VN_invokeModule" as NSString)
        
        // __VN_invokeModuleSync: Synchronous native module invocation
        let invokeModuleSync: @convention(block) (String, String, String) -> String = {
            [weak self] moduleName, methodName, argsJson in
            guard let self = self else { return "{}" }
            return self.moduleRegistry.invokeSync(module: moduleName, method: methodName, args: argsJson)
        }
        jsContext.setObject(invokeModuleSync, forKeyedSubscript: "__VN_invokeModuleSync" as NSString)
    }
    
    // MARK: - Process Batched Operations
    
    /// Process a batch of operations from JavaScript on the main thread
    private func processOperations(_ ops: [[String: Any]]) {
        for op in ops {
            guard let opType = op["op"] as? String,
                  let args = op["args"] as? [Any]
            else { continue }
            
            switch opType {
            case "create":
                guard let id = args[0] as? Int,
                      let type = args[1] as? String
                else { continue }
                createNativeView(id: id, type: type)
                
            case "createText":
                guard let id = args[0] as? Int,
                      let text = args[1] as? String
                else { continue }
                createTextView(id: id, text: text)
                
            case "setText":
                guard let id = args[0] as? Int,
                      let text = args[1] as? String
                else { continue }
                updateText(id: id, text: text)
                
            case "updateProp":
                guard let id = args[0] as? Int,
                      let key = args[1] as? String
                else { continue }
                let value = args.count > 2 ? args[2] : nil
                updateProp(id: id, key: key, value: value)
                
            case "updateStyle":
                guard let id = args[0] as? Int,
                      let changes = args[1] as? [String: Any]
                else { continue }
                updateStyle(id: id, changes: changes)
                
            case "appendChild":
                guard let parentId = args[0] as? Int,
                      let childId = args[1] as? Int
                else { continue }
                appendChild(parentId: parentId, childId: childId)
                
            case "insertBefore":
                guard let parentId = args[0] as? Int,
                      let childId = args[1] as? Int,
                      let anchorId = args[2] as? Int
                else { continue }
                insertBefore(parentId: parentId, childId: childId, anchorId: anchorId)
                
            case "removeChild":
                guard let childId = args[0] as? Int
                else { continue }
                removeChild(childId: childId)
                
            case "addEventListener":
                guard let id = args[0] as? Int,
                      let eventName = args[1] as? String
                else { continue }
                addEventListener(id: id, eventName: eventName)
                
            case "setRootView":
                guard let id = args[0] as? Int
                else { continue }
                setRootView(id: id)
                
            default:
                print("[Vue Native] Unknown operation: \(opType)")
            }
        }
        
        // After processing all operations, trigger a layout pass
        performLayout()
    }
    
    // MARK: - View Operations
    
    private func createNativeView(id: Int, type: String) {
        let view = componentRegistry.createView(type: type)
        viewRegistry[id] = view
        
        // Create corresponding Yoga layout node
        let yogaNode = YogaNode()
        layoutNodes[id] = yogaNode
        
        // Enable Yoga layout on the view
        view.yoga.isEnabled = true
    }
    
    private func createTextView(id: Int, text: String) {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        viewRegistry[id] = label
        
        let yogaNode = YogaNode()
        layoutNodes[id] = yogaNode
        label.yoga.isEnabled = true
    }
    
    private func updateText(id: Int, text: String) {
        if let label = viewRegistry[id] as? UILabel {
            label.text = text
        }
    }
    
    private func updateProp(id: Int, key: String, value: Any?) {
        guard let view = viewRegistry[id] else { return }
        componentRegistry.updateProp(view: view, key: key, value: value)
    }
    
    private func updateStyle(id: Int, changes: [String: Any]) {
        guard let view = viewRegistry[id] else { return }
        
        for (prop, value) in changes {
            StyleEngine.applyStyleProp(view: view, prop: prop, value: value)
        }
    }
    
    private func appendChild(parentId: Int, childId: Int) {
        guard let parent = viewRegistry[parentId],
              let child = viewRegistry[childId]
        else { return }
        parent.addSubview(child)
    }
    
    private func insertBefore(parentId: Int, childId: Int, anchorId: Int) {
        guard let parent = viewRegistry[parentId],
              let child = viewRegistry[childId],
              let anchor = viewRegistry[anchorId],
              let anchorIndex = parent.subviews.firstIndex(of: anchor)
        else { return }
        parent.insertSubview(child, at: anchorIndex)
    }
    
    private func removeChild(childId: Int) {
        guard let child = viewRegistry[childId] else { return }
        child.removeFromSuperview()
        viewRegistry.removeValue(forKey: childId)
        layoutNodes.removeValue(forKey: childId)
    }
    
    private func addEventListener(id: Int, eventName: String) {
        guard let view = viewRegistry[id] else { return }
        componentRegistry.addEventListener(view: view, event: eventName) { [weak self] payload in
            self?.dispatchEventToJS(nodeId: id, eventName: eventName, payload: payload)
        }
    }
    
    private func setRootView(id: Int) {
        guard let view = viewRegistry[id], let root = rootView else { return }
        view.frame = root.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.addSubview(view)
    }
    
    // MARK: - Layout
    
    private func performLayout() {
        guard let root = rootView,
              let rootNativeView = root.subviews.last
        else { return }
        
        // Yoga calculates layout for the entire tree
        rootNativeView.yoga.applyLayout(preservingOrigin: true)
    }
    
    // MARK: - Event Dispatch
    
    private func dispatchEventToJS(nodeId: Int, eventName: String, payload: Any?) {
        performOnJSThread {
            let payloadJson: String
            if let payload = payload {
                payloadJson = (try? String(
                    data: JSONSerialization.data(withJSONObject: payload),
                    encoding: .utf8
                )) ?? "null"
            } else {
                payloadJson = "null"
            }
            self.jsContext.evaluateScript(
                "__VN_handleEvent(\(nodeId), '\(eventName)', \(payloadJson))"
            )
        }
    }
    
    // MARK: - Thread Helpers
    
    private func performOnJSThread(_ block: @escaping () -> Void) {
        // Execute on the JS thread
        perform(#selector(executeBlock), on: jsThread, with: block, waitUntilDone: false)
    }
    
    @objc private func executeBlock(_ block: () -> Void) {
        block()
    }
    
    // MARK: - Bundle Loading
    
    private func loadPolyfills() {
        // Register setTimeout, setInterval, console, fetch, etc.
        JSPolyfills.register(in: jsContext)
    }
    
    private func loadBundle() {
        guard let bundlePath = Bundle.main.path(forResource: "vue-native-bundle", ofType: "js"),
              let bundleCode = try? String(contentsOfFile: bundlePath, encoding: .utf8)
        else {
            fatalError("[Vue Native] Could not load JS bundle")
        }
        jsContext.evaluateScript(bundleCode)
    }
}
```

### 4.4 JS Polyfills for JSContext

```swift
// Sources/VueNativeCore/Bridge/JSPolyfills.swift

import JavaScriptCore

/// Provides browser-like APIs in JSContext (setTimeout, console, etc.)
class JSPolyfills {
    
    static var timers: [String: Timer] = [:]
    
    static func register(in context: JSContext) {
        
        // --- console ---
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("[Vue Native JS] \(message)")
        }
        let consoleWarn: @convention(block) (String) -> Void = { message in
            print("[Vue Native JS ⚠️] \(message)")
        }
        let consoleError: @convention(block) (String) -> Void = { message in
            print("[Vue Native JS ❌] \(message)")
        }
        
        context.evaluateScript("var console = {};")
        context.objectForKeyedSubscript("console").setObject(consoleLog, forKeyedSubscript: "log" as NSString)
        context.objectForKeyedSubscript("console").setObject(consoleWarn, forKeyedSubscript: "warn" as NSString)
        context.objectForKeyedSubscript("console").setObject(consoleError, forKeyedSubscript: "error" as NSString)
        
        // --- setTimeout / clearTimeout ---
        let setTimeout: @convention(block) (JSValue, Double) -> String = { callback, ms in
            let uuid = UUID().uuidString
            let timeInterval = ms / 1000.0
            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
                    callback.call(withArguments: [])
                    timers.removeValue(forKey: uuid)
                }
                timers[uuid] = timer
            }
            return uuid
        }
        context.setObject(setTimeout, forKeyedSubscript: "setTimeout" as NSString)
        
        let clearTimeout: @convention(block) (String) -> Void = { uuid in
            timers[uuid]?.invalidate()
            timers.removeValue(forKey: uuid)
        }
        context.setObject(clearTimeout, forKeyedSubscript: "clearTimeout" as NSString)
        
        // --- setInterval / clearInterval ---
        let setInterval: @convention(block) (JSValue, Double) -> String = { callback, ms in
            let uuid = UUID().uuidString
            let timeInterval = ms / 1000.0
            DispatchQueue.main.async {
                let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
                    callback.call(withArguments: [])
                }
                timers[uuid] = timer
            }
            return uuid
        }
        context.setObject(setInterval, forKeyedSubscript: "setInterval" as NSString)
        
        let clearInterval: @convention(block) (String) -> Void = { uuid in
            timers[uuid]?.invalidate()
            timers.removeValue(forKey: uuid)
        }
        context.setObject(clearInterval, forKeyedSubscript: "clearInterval" as NSString)
        
        // --- queueMicrotask (critical for Vue's scheduler) ---
        let queueMicrotask: @convention(block) (JSValue) -> Void = { callback in
            // Execute on next tick of the JS run loop
            DispatchQueue.main.async {
                callback.call(withArguments: [])
            }
        }
        context.setObject(queueMicrotask, forKeyedSubscript: "queueMicrotask" as NSString)
        
        // --- Promise (JSC has native Promise support, but ensure it's available) ---
        // JavaScriptCore includes native Promise since iOS 13+
        
        // --- requestAnimationFrame ---
        let raf: @convention(block) (JSValue) -> Int = { callback in
            let id = Int.random(in: 1...Int.max)
            // Use CADisplayLink on main thread for frame-synced callbacks
            DispatchQueue.main.async {
                let displayLink = CADisplayLink(target: DisplayLinkProxy(callback: callback), selector: #selector(DisplayLinkProxy.tick))
                displayLink.add(to: .current, forMode: .common)
                // Auto-remove after one frame
                displayLink.isPaused = false
            }
            return id
        }
        context.setObject(raf, forKeyedSubscript: "requestAnimationFrame" as NSString)
    }
}

/// Helper class to bridge CADisplayLink to JSValue callback
@objc class DisplayLinkProxy: NSObject {
    let callback: JSValue
    
    init(callback: JSValue) {
        self.callback = callback
    }
    
    @objc func tick(displayLink: CADisplayLink) {
        callback.call(withArguments: [displayLink.timestamp * 1000])
        displayLink.invalidate()
    }
}
```

---

## 5. Layer 3: Native Component Registry (Swift/UIKit)

### 5.1 Component Registry

```swift
// Sources/VueNativeCore/Components/ComponentRegistry.swift

import UIKit

/// Factory protocol for creating native views
protocol NativeComponentFactory {
    func createView() -> UIView
    func updateProp(view: UIView, key: String, value: Any?)
    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void)
}

/// Central registry mapping JS component types to native view factories
class ComponentRegistry {
    
    static let shared = ComponentRegistry()
    
    private var factories: [String: NativeComponentFactory] = [:]
    
    init() {
        // Register built-in components
        register("VView",       factory: VViewFactory())
        register("VText",       factory: VTextFactory())
        register("VButton",     factory: VButtonFactory())
        register("VImage",      factory: VImageFactory())
        register("VInput",      factory: VInputFactory())
        register("VScroll",     factory: VScrollFactory())
        register("VList",       factory: VListFactory())
        register("VSwitch",     factory: VSwitchFactory())
        register("VSlider",     factory: VSliderFactory())
        register("VActivityIndicator", factory: VActivityIndicatorFactory())
        register("VSafeArea",   factory: VSafeAreaFactory())
        register("VModal",      factory: VModalFactory())
        register("VWebView",    factory: VWebViewFactory())
        register("VMap",        factory: VMapFactory())
        register("VBlur",       factory: VBlurFactory())
        register("VGradient",   factory: VGradientFactory())
        register("VKeyboardAvoiding", factory: VKeyboardAvoidingFactory())
        register("__ROOT__",    factory: VRootFactory())
    }
    
    func register(_ type: String, factory: NativeComponentFactory) {
        factories[type] = factory
    }
    
    func createView(type: String) -> UIView {
        guard let factory = factories[type] else {
            print("[Vue Native] Unknown component type: \(type), falling back to VView")
            return VViewFactory().createView()
        }
        return factory.createView()
    }
    
    func updateProp(view: UIView, key: String, value: Any?) {
        // Find the factory for this view type and delegate
        // We store the factory type on the view via objc_setAssociatedObject
        if let factory = getFactory(for: view) {
            factory.updateProp(view: view, key: key, value: value)
        }
    }
    
    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        if let factory = getFactory(for: view) {
            factory.addEventListener(view: view, event: event, handler: handler)
        }
    }
    
    private func getFactory(for view: UIView) -> NativeComponentFactory? {
        // Retrieve factory from associated object
        return objc_getAssociatedObject(view, &factoryKey) as? NativeComponentFactory
    }
}

private var factoryKey: UInt8 = 0
```

### 5.2 Example Component Factories

```swift
// Sources/VueNativeCore/Components/Factories/VTextFactory.swift

class VTextFactory: NativeComponentFactory {
    
    func createView() -> UIView {
        let label = UILabel()
        label.numberOfLines = 0
        label.yoga.isEnabled = true
        objc_setAssociatedObject(label, &factoryKey, self, .OBJC_ASSOCIATION_RETAIN)
        return label
    }
    
    func updateProp(view: UIView, key: String, value: Any?) {
        guard let label = view as? UILabel else { return }
        
        switch key {
        case "text":
            label.text = value as? String
        case "numberOfLines":
            label.numberOfLines = value as? Int ?? 0
        case "selectable":
            label.isUserInteractionEnabled = value as? Bool ?? false
        case "color":
            if let hex = value as? String {
                label.textColor = UIColor(hex: hex)
            }
        case "fontSize":
            let size = CGFloat(value as? Double ?? 16)
            label.font = label.font.withSize(size)
        case "fontWeight":
            if let weight = value as? String {
                label.font = UIFont.systemFont(
                    ofSize: label.font.pointSize,
                    weight: fontWeight(from: weight)
                )
            }
        case "textAlign":
            if let align = value as? String {
                label.textAlignment = textAlignment(from: align)
            }
        default:
            break
        }
    }
    
    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        // UILabel doesn't have many events, but we could add tap gesture
        if event == "press" {
            let tap = UITapGestureRecognizer()
            let wrapper = GestureWrapper(handler: handler)
            tap.addTarget(wrapper, action: #selector(GestureWrapper.handleGesture))
            view.addGestureRecognizer(tap)
            view.isUserInteractionEnabled = true
            // Store wrapper to prevent deallocation
            objc_setAssociatedObject(view, "\(event)_wrapper", wrapper, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    private func fontWeight(from string: String) -> UIFont.Weight {
        switch string {
        case "100", "thin": return .thin
        case "200", "ultraLight": return .ultraLight
        case "300", "light": return .light
        case "400", "normal", "regular": return .regular
        case "500", "medium": return .medium
        case "600", "semibold": return .semibold
        case "700", "bold": return .bold
        case "800", "heavy": return .heavy
        case "900", "black": return .black
        default: return .regular
        }
    }
    
    private func textAlignment(from string: String) -> NSTextAlignment {
        switch string {
        case "left": return .left
        case "center": return .center
        case "right": return .right
        case "justify": return .justified
        default: return .natural
        }
    }
}

// Sources/VueNativeCore/Components/Factories/VButtonFactory.swift

class VButtonFactory: NativeComponentFactory {
    
    func createView() -> UIView {
        let button = TouchableView()
        button.yoga.isEnabled = true
        objc_setAssociatedObject(button, &factoryKey, self, .OBJC_ASSOCIATION_RETAIN)
        return button
    }
    
    func updateProp(view: UIView, key: String, value: Any?) {
        guard let touchable = view as? TouchableView else { return }
        
        switch key {
        case "disabled":
            touchable.isUserInteractionEnabled = !(value as? Bool ?? false)
            touchable.alpha = (value as? Bool ?? false) ? 0.5 : 1.0
        case "activeOpacity":
            touchable.activeOpacity = CGFloat(value as? Double ?? 0.7)
        default:
            break
        }
    }
    
    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let touchable = view as? TouchableView else { return }
        
        switch event {
        case "press":
            touchable.onPress = { handler(nil) }
        case "longpress":
            touchable.onLongPress = { handler(nil) }
        default:
            break
        }
    }
}

/// Custom UIView that handles touch events with opacity feedback
class TouchableView: UIView {
    var activeOpacity: CGFloat = 0.7
    var onPress: (() -> Void)?
    var onLongPress: (() -> Void)?
    
    private var longPressRecognizer: UILongPressGestureRecognizer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }
    
    private func setupGestures() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        addGestureRecognizer(longPress)
        longPressRecognizer = longPress
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.1) { self.alpha = self.activeOpacity }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.1) { self.alpha = 1.0 }
        
        if let touch = touches.first, self.bounds.contains(touch.location(in: self)) {
            onPress?()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.1) { self.alpha = 1.0 }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            onLongPress?()
        }
    }
}
```

### 5.3 Complete Component Map

| Vue Native Component | Native UIKit View | Notes |
|---------------------|-------------------|-------|
| `<VView>` | `UIView` | Base container, supports all Yoga layout props |
| `<VText>` | `UILabel` | Text rendering with font/color/alignment |
| `<VButton>` | `TouchableView` (custom) | Touch feedback with opacity animation |
| `<VImage>` | `UIImageView` | Async image loading, resize modes |
| `<VInput>` | `UITextField` / `UITextView` | Single/multi-line text input, v-model support |
| `<VScroll>` | `UIScrollView` | Scrollable container |
| `<VList>` | `UITableView` / `UICollectionView` | Virtualized list with view recycling |
| `<VSwitch>` | `UISwitch` | Toggle boolean, v-model support |
| `<VSlider>` | `UISlider` | Value slider, v-model support |
| `<VActivityIndicator>` | `UIActivityIndicatorView` | Loading spinner |
| `<VSafeArea>` | `UIView` + safe area insets | Automatically avoids notch/home indicator |
| `<VModal>` | Presented `UIViewController` | Modal overlay |
| `<VWebView>` | `WKWebView` | Embedded web content |
| `<VMap>` | `MKMapView` | Apple Maps |
| `<VBlur>` | `UIVisualEffectView` | iOS blur effects |
| `<VGradient>` | `CAGradientLayer` | Linear/radial gradients |
| `<VKeyboardAvoiding>` | `UIView` + keyboard observer | Auto-adjusts for keyboard |
| `<VTabBar>` | `UITabBarController` | Bottom tab navigation |
| `<VNavigationBar>` | `UINavigationBar` | Top navigation bar |
| `<VStatusBar>` | `UIApplication.statusBarStyle` | Status bar configuration |
| `<VRefreshControl>` | `UIRefreshControl` | Pull-to-refresh |
| `<VSegmentedControl>` | `UISegmentedControl` | Segmented picker |
| `<VDatePicker>` | `UIDatePicker` | Date/time selection |
| `<VPicker>` | `UIPickerView` | Wheel picker |
| `<VProgressBar>` | `UIProgressView` | Progress indicator |
| `<VAlert>` | `UIAlertController` | System alert dialog |
| `<VActionSheet>` | `UIAlertController` (.actionSheet) | Bottom action sheet |

---

## 6. Layer 4: Layout Engine (Yoga/Flexbox)

### 6.1 Integration Strategy

We use **FlexLayout** (Swift wrapper around Facebook's Yoga C++ library) for layout calculations. This is the same layout engine that powers React Native.

**Swift Package Dependency:**
```swift
.package(url: "https://github.com/nicklockwood/FlexLayout.git", from: "2.0.0")
```

### 6.2 Style-to-Yoga Mapping

```swift
// Sources/VueNativeCore/Styling/StyleEngine.swift

import UIKit

class StyleEngine {
    
    /// Apply a single style property to a view's Yoga configuration
    static func applyStyleProp(view: UIView, prop: String, value: Any?) {
        guard let value = value else {
            // Reset to default
            resetStyleProp(view: view, prop: prop)
            return
        }
        
        let yoga = view.yoga
        
        switch prop {
            
        // --- Flex Container Props ---
        case "flexDirection":
            yoga.flexDirection = flexDirection(from: value as? String ?? "column")
        case "justifyContent":
            yoga.justifyContent = justifyContent(from: value as? String ?? "flex-start")
        case "alignItems":
            yoga.alignItems = alignItems(from: value as? String ?? "stretch")
        case "alignSelf":
            yoga.alignSelf = alignSelf(from: value as? String ?? "auto")
        case "alignContent":
            yoga.alignContent = alignContent(from: value as? String ?? "flex-start")
        case "flexWrap":
            yoga.flexWrap = (value as? String == "wrap") ? .wrap : .noWrap
        case "overflow":
            yoga.overflow = (value as? String == "hidden") ? .hidden : .visible
            view.clipsToBounds = (value as? String == "hidden")
            
        // --- Flex Item Props ---
        case "flex":
            yoga.flex = CGFloat(value as? Double ?? 0)
        case "flexGrow":
            yoga.flexGrow = CGFloat(value as? Double ?? 0)
        case "flexShrink":
            yoga.flexShrink = CGFloat(value as? Double ?? 1)
        case "flexBasis":
            yoga.flexBasis = yogaValue(value)
            
        // --- Dimensions ---
        case "width":
            yoga.width = yogaValue(value)
        case "height":
            yoga.height = yogaValue(value)
        case "minWidth":
            yoga.minWidth = yogaValue(value)
        case "minHeight":
            yoga.minHeight = yogaValue(value)
        case "maxWidth":
            yoga.maxWidth = yogaValue(value)
        case "maxHeight":
            yoga.maxHeight = yogaValue(value)
        case "aspectRatio":
            yoga.aspectRatio = CGFloat(value as? Double ?? 0)
            
        // --- Spacing (Margin) ---
        case "margin":
            let v = yogaValue(value)
            yoga.marginTop = v; yoga.marginRight = v
            yoga.marginBottom = v; yoga.marginLeft = v
        case "marginTop": yoga.marginTop = yogaValue(value)
        case "marginRight": yoga.marginRight = yogaValue(value)
        case "marginBottom": yoga.marginBottom = yogaValue(value)
        case "marginLeft": yoga.marginLeft = yogaValue(value)
        case "marginHorizontal":
            let v = yogaValue(value)
            yoga.marginLeft = v; yoga.marginRight = v
        case "marginVertical":
            let v = yogaValue(value)
            yoga.marginTop = v; yoga.marginBottom = v
            
        // --- Spacing (Padding) ---
        case "padding":
            let v = yogaValue(value)
            yoga.paddingTop = v; yoga.paddingRight = v
            yoga.paddingBottom = v; yoga.paddingLeft = v
        case "paddingTop": yoga.paddingTop = yogaValue(value)
        case "paddingRight": yoga.paddingRight = yogaValue(value)
        case "paddingBottom": yoga.paddingBottom = yogaValue(value)
        case "paddingLeft": yoga.paddingLeft = yogaValue(value)
        case "paddingHorizontal":
            let v = yogaValue(value)
            yoga.paddingLeft = v; yoga.paddingRight = v
        case "paddingVertical":
            let v = yogaValue(value)
            yoga.paddingTop = v; yoga.paddingBottom = v
            
        // --- Position ---
        case "position":
            yoga.position = (value as? String == "absolute") ? .absolute : .relative
        case "top": yoga.top = yogaValue(value)
        case "right": yoga.right = yogaValue(value)
        case "bottom": yoga.bottom = yogaValue(value)
        case "left": yoga.left = yogaValue(value)
        case "zIndex":
            view.layer.zPosition = CGFloat(value as? Double ?? 0)
            
        // --- Gap ---
        case "gap":
            let v = CGFloat(value as? Double ?? 0)
            yoga.rowGap = v; yoga.columnGap = v
        case "rowGap":
            yoga.rowGap = CGFloat(value as? Double ?? 0)
        case "columnGap":
            yoga.columnGap = CGFloat(value as? Double ?? 0)
            
        // --- Visual Props (non-Yoga, applied directly to UIView) ---
        case "backgroundColor":
            view.backgroundColor = UIColor(hex: value as? String ?? "transparent")
        case "opacity":
            view.alpha = CGFloat(value as? Double ?? 1.0)
        case "borderRadius":
            view.layer.cornerRadius = CGFloat(value as? Double ?? 0)
            view.clipsToBounds = true
        case "borderWidth":
            view.layer.borderWidth = CGFloat(value as? Double ?? 0)
        case "borderColor":
            view.layer.borderColor = UIColor(hex: value as? String ?? "#000000").cgColor
        case "shadowColor":
            view.layer.shadowColor = UIColor(hex: value as? String ?? "#000000").cgColor
        case "shadowOffset":
            if let offset = value as? [String: Double] {
                view.layer.shadowOffset = CGSize(
                    width: offset["width"] ?? 0,
                    height: offset["height"] ?? 0
                )
            }
        case "shadowOpacity":
            view.layer.shadowOpacity = Float(value as? Double ?? 0)
        case "shadowRadius":
            view.layer.shadowRadius = CGFloat(value as? Double ?? 0)
        case "transform":
            applyTransform(view: view, value: value)
            
        default:
            // Unknown style prop — may be component-specific
            break
        }
    }
    
    // --- Helper conversions ---
    
    private static func yogaValue(_ value: Any?) -> YGValue {
        if let num = value as? Double {
            return YGValue(value: Float(num), unit: .point)
        }
        if let str = value as? String {
            if str.hasSuffix("%") {
                let num = Float(str.dropLast()) ?? 0
                return YGValue(value: num, unit: .percent)
            }
            if str == "auto" {
                return YGValue(value: 0, unit: .auto)
            }
        }
        return YGValue(value: 0, unit: .undefined)
    }
    
    private static func flexDirection(from str: String) -> YGFlexDirection {
        switch str {
        case "row": return .row
        case "row-reverse": return .rowReverse
        case "column-reverse": return .columnReverse
        default: return .column
        }
    }
    
    private static func justifyContent(from str: String) -> YGJustify {
        switch str {
        case "center": return .center
        case "flex-end": return .flexEnd
        case "space-between": return .spaceBetween
        case "space-around": return .spaceAround
        case "space-evenly": return .spaceEvenly
        default: return .flexStart
        }
    }
    
    private static func alignItems(from str: String) -> YGAlign {
        switch str {
        case "center": return .center
        case "flex-start": return .flexStart
        case "flex-end": return .flexEnd
        case "baseline": return .baseline
        default: return .stretch
        }
    }
    
    private static func alignSelf(from str: String) -> YGAlign {
        switch str {
        case "center": return .center
        case "flex-start": return .flexStart
        case "flex-end": return .flexEnd
        case "stretch": return .stretch
        case "baseline": return .baseline
        default: return .auto
        }
    }
    
    private static func alignContent(from str: String) -> YGAlign {
        switch str {
        case "center": return .center
        case "flex-end": return .flexEnd
        case "stretch": return .stretch
        case "space-between": return .spaceBetween
        case "space-around": return .spaceAround
        default: return .flexStart
        }
    }
    
    private static func applyTransform(view: UIView, value: Any?) {
        guard let transforms = value as? [[String: Any]] else { return }
        
        var transform = CGAffineTransform.identity
        for t in transforms {
            if let rotate = t["rotate"] as? String {
                let radians = parseAngle(rotate)
                transform = transform.rotated(by: radians)
            }
            if let scale = t["scale"] as? Double {
                transform = transform.scaledBy(x: CGFloat(scale), y: CGFloat(scale))
            }
            if let translateX = t["translateX"] as? Double {
                transform = transform.translatedBy(x: CGFloat(translateX), y: 0)
            }
            if let translateY = t["translateY"] as? Double {
                transform = transform.translatedBy(x: 0, y: CGFloat(translateY))
            }
        }
        view.transform = transform
    }
    
    private static func parseAngle(_ str: String) -> CGFloat {
        if str.hasSuffix("deg") {
            return CGFloat(Double(str.dropLast(3)) ?? 0) * .pi / 180
        }
        if str.hasSuffix("rad") {
            return CGFloat(Double(str.dropLast(3)) ?? 0)
        }
        return CGFloat(Double(str) ?? 0)
    }
    
    private static func resetStyleProp(view: UIView, prop: String) {
        // Reset to Yoga defaults
        // Implementation mirrors applyStyleProp but sets defaults
    }
}
```

---

## 7. Layer 5: Native Module System (Composables)

### 7.1 Native Module Protocol

```swift
// Sources/VueNativeCore/Modules/NativeModule.swift

/// Protocol for all native modules
protocol NativeModule {
    /// Unique module identifier (e.g., "Camera", "Geolocation")
    static var moduleName: String { get }
    
    /// Available methods and their implementations
    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void)
    
    /// Synchronous methods (for fast reads like Dimensions, Platform info)
    func invokeSync(method: String, args: [Any]) -> Any?
}

/// Registry of all native modules
class NativeModuleRegistry {
    static let shared = NativeModuleRegistry()
    
    private var modules: [String: NativeModule] = [:]
    
    init() {
        // Register built-in modules
        register(CameraModule())
        register(GeolocationModule())
        register(HapticsModule())
        register(AsyncStorageModule())
        register(ClipboardModule())
        register(DeviceInfoModule())
        register(KeychainModule())
        register(BiometricsModule())
        register(NotificationsModule())
        register(ShareModule())
        register(LinkingModule())
        register(AppStateModule())
        register(DimensionsModule())
        register(PlatformModule())
        register(AnimationModule())
        register(NetworkModule())
    }
    
    func register(_ module: NativeModule) {
        modules[type(of: module).moduleName] = module
    }
    
    func invoke(module: String, method: String, args: String, callback: @escaping (Any?, String?) -> Void) {
        guard let mod = modules[module] else {
            callback(nil, "Module '\(module)' not found")
            return
        }
        let parsedArgs = (try? JSONSerialization.jsonObject(with: args.data(using: .utf8)!) as? [Any]) ?? []
        mod.invoke(method: method, args: parsedArgs, callback: callback)
    }
    
    func invokeSync(module: String, method: String, args: String) -> String {
        guard let mod = modules[module] else { return "{}" }
        let parsedArgs = (try? JSONSerialization.jsonObject(with: args.data(using: .utf8)!) as? [Any]) ?? []
        let result = mod.invokeSync(method: method, args: parsedArgs)
        if let result = result,
           let data = try? JSONSerialization.data(withJSONObject: result),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "null"
    }
}
```

### 7.2 JS-Side Composables

```typescript
// packages/runtime/src/composables/useCamera.ts

import { ref } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface CameraOptions {
  quality?: number       // 0-1
  allowsEditing?: boolean
  mediaTypes?: 'photo' | 'video' | 'all'
  cameraType?: 'front' | 'back'
  saveToPhotos?: boolean
}

export interface CameraResult {
  uri: string
  width: number
  height: number
  fileSize: number
  type: string
}

export function useCamera() {
  const photo = ref<CameraResult | null>(null)
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function takePhoto(options?: CameraOptions): Promise<CameraResult | null> {
    isLoading.value = true
    error.value = null
    try {
      const result = await NativeBridge.invokeNativeModule('Camera', 'takePhoto', [options || {}])
      photo.value = result
      return result
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      isLoading.value = false
    }
  }

  async function pickFromLibrary(options?: CameraOptions): Promise<CameraResult | null> {
    isLoading.value = true
    error.value = null
    try {
      const result = await NativeBridge.invokeNativeModule('Camera', 'pickFromLibrary', [options || {}])
      photo.value = result
      return result
    } catch (e: any) {
      error.value = e.message
      return null
    } finally {
      isLoading.value = false
    }
  }

  return { photo, isLoading, error, takePhoto, pickFromLibrary }
}

// packages/runtime/src/composables/useHaptics.ts

export function useHaptics() {
  function vibrate(style: 'light' | 'medium' | 'heavy' | 'success' | 'warning' | 'error' = 'medium') {
    NativeBridge.invokeNativeModuleSync('Haptics', 'vibrate', [style])
  }

  function selectionChanged() {
    NativeBridge.invokeNativeModuleSync('Haptics', 'selectionChanged', [])
  }

  return { vibrate, selectionChanged }
}

// packages/runtime/src/composables/useGeolocation.ts

import { ref, onMounted, onUnmounted } from '@vue/runtime-core'
import { NativeBridge } from '../bridge'

export interface Coordinates {
  latitude: number
  longitude: number
  altitude: number | null
  accuracy: number
  speed: number | null
  heading: number | null
  timestamp: number
}

export function useGeolocation(options?: { enableHighAccuracy?: boolean }) {
  const location = ref<Coordinates | null>(null)
  const error = ref<string | null>(null)
  const isWatching = ref(false)
  let watchId: number | null = null

  async function getCurrentPosition(): Promise<Coordinates | null> {
    try {
      const result = await NativeBridge.invokeNativeModule(
        'Geolocation', 'getCurrentPosition', [options || {}]
      )
      location.value = result
      return result
    } catch (e: any) {
      error.value = e.message
      return null
    }
  }

  function startWatching() {
    isWatching.value = true
    // Native side will call back with location updates
    NativeBridge.invokeNativeModule('Geolocation', 'watchPosition', [options || {}])
      .then(id => { watchId = id })
  }

  function stopWatching() {
    if (watchId !== null) {
      NativeBridge.invokeNativeModule('Geolocation', 'clearWatch', [watchId])
      watchId = null
    }
    isWatching.value = false
  }

  onUnmounted(() => stopWatching())

  return { location, error, isWatching, getCurrentPosition, startWatching, stopWatching }
}

// packages/runtime/src/composables/useAsyncStorage.ts

export function useAsyncStorage() {
  async function getItem(key: string): Promise<string | null> {
    return NativeBridge.invokeNativeModule('AsyncStorage', 'getItem', [key])
  }

  async function setItem(key: string, value: string): Promise<void> {
    await NativeBridge.invokeNativeModule('AsyncStorage', 'setItem', [key, value])
  }

  async function removeItem(key: string): Promise<void> {
    await NativeBridge.invokeNativeModule('AsyncStorage', 'removeItem', [key])
  }

  async function getAllKeys(): Promise<string[]> {
    return NativeBridge.invokeNativeModule('AsyncStorage', 'getAllKeys', [])
  }

  async function clear(): Promise<void> {
    await NativeBridge.invokeNativeModule('AsyncStorage', 'clear', [])
  }

  return { getItem, setItem, removeItem, getAllKeys, clear }
}

// packages/runtime/src/composables/useKeyboard.ts

import { ref, onMounted, onUnmounted } from '@vue/runtime-core'

export function useKeyboard() {
  const isVisible = ref(false)
  const height = ref(0)

  // Keyboard events are dispatched from native
  function onKeyboardShow(payload: { height: number }) {
    isVisible.value = true
    height.value = payload.height
  }

  function onKeyboardHide() {
    isVisible.value = false
    height.value = 0
  }

  onMounted(() => {
    NativeBridge.invokeNativeModule('Keyboard', 'startListening', [])
  })

  onUnmounted(() => {
    NativeBridge.invokeNativeModule('Keyboard', 'stopListening', [])
  })

  function dismiss() {
    NativeBridge.invokeNativeModuleSync('Keyboard', 'dismiss', [])
  }

  return { isVisible, height, dismiss }
}

// packages/runtime/src/composables/useAppState.ts

import { ref } from '@vue/runtime-core'

export function useAppState() {
  const state = ref<'active' | 'inactive' | 'background'>('active')

  // Native dispatches state changes
  // Listener is auto-registered when this composable is used

  return { state }
}

// packages/runtime/src/composables/useAnimation.ts

import { ref } from '@vue/runtime-core'

export function useAnimation() {
  function spring(
    target: Record<string, number>,
    options?: { damping?: number; stiffness?: number; mass?: number }
  ) {
    // Returns an animated style object that Vue Native's
    // style engine applies via UIView.animate with spring params
    return NativeBridge.invokeNativeModule('Animation', 'spring', [target, options || {}])
  }

  function timing(
    target: Record<string, number>,
    options?: { duration?: number; easing?: string; delay?: number }
  ) {
    return NativeBridge.invokeNativeModule('Animation', 'timing', [target, options || {}])
  }

  return { spring, timing }
}
```

### 7.3 Complete Composable List

| Composable | Native Module | Key Methods |
|-----------|---------------|-------------|
| `useCamera()` | Camera | `takePhoto()`, `pickFromLibrary()` |
| `useGeolocation()` | Geolocation | `getCurrentPosition()`, `startWatching()` |
| `useHaptics()` | Haptics | `vibrate()`, `selectionChanged()` |
| `useAsyncStorage()` | AsyncStorage | `getItem()`, `setItem()`, `removeItem()` |
| `useClipboard()` | Clipboard | `copy()`, `paste()`, `hasContent()` |
| `useDeviceInfo()` | DeviceInfo | `getModel()`, `getOS()`, `getScreenSize()` |
| `useKeychain()` | Keychain | `set()`, `get()`, `remove()` |
| `useBiometrics()` | Biometrics | `authenticate()`, `isAvailable()` |
| `useNotifications()` | Notifications | `requestPermission()`, `schedule()` |
| `useShare()` | Share | `share()` |
| `useLinking()` | Linking | `openURL()`, `canOpenURL()` |
| `useAppState()` | AppState | reactive `state` ref |
| `useKeyboard()` | Keyboard | `dismiss()`, reactive `isVisible`, `height` |
| `useAnimation()` | Animation | `spring()`, `timing()` |
| `useNetwork()` | Network | reactive `isConnected`, `connectionType` |
| `useOrientation()` | Orientation | reactive `orientation` |
| `usePermissions()` | Permissions | `request()`, `check()` |
| `useInAppPurchase()` | InAppPurchase | `getProducts()`, `purchase()` |
| `useHealthKit()` | HealthKit | `getSteps()`, `requestAuth()` |

---

## 8. Layer 6: Navigation System

### 8.1 Design

Navigation uses a composable-based API inspired by `vue-router` but adapted for native stack navigation patterns.

```typescript
// packages/navigation/src/index.ts

import { ref, shallowRef, provide, inject, type Component } from '@vue/runtime-core'
import { NativeBridge } from '@vue-native/runtime'

interface RouteConfig {
  name: string
  component: Component
  options?: NavigationOptions
}

interface NavigationOptions {
  title?: string
  headerShown?: boolean
  headerStyle?: object
  headerTintColor?: string
  animation?: 'push' | 'modal' | 'fade' | 'none'
  gestureEnabled?: boolean
}

export function createRouter(routes: RouteConfig[]) {
  const routeMap = new Map(routes.map(r => [r.name, r]))
  const currentRoute = shallowRef(routes[0])
  const routeStack = ref<RouteConfig[]>([routes[0]])
  const params = ref<Record<string, any>>({})

  async function navigate(name: string, routeParams?: Record<string, any>) {
    const route = routeMap.get(name)
    if (!route) throw new Error(`Route '${name}' not found`)
    
    params.value = routeParams || {}
    routeStack.value.push(route)
    currentRoute.value = route
    
    // Tell native to push a new view controller
    await NativeBridge.invokeNativeModule('Navigation', 'push', [{
      routeName: name,
      options: route.options || {},
    }])
  }

  async function goBack() {
    if (routeStack.value.length <= 1) return
    
    routeStack.value.pop()
    currentRoute.value = routeStack.value[routeStack.value.length - 1]
    
    await NativeBridge.invokeNativeModule('Navigation', 'pop', [])
  }

  async function replace(name: string, routeParams?: Record<string, any>) {
    const route = routeMap.get(name)
    if (!route) throw new Error(`Route '${name}' not found`)
    
    params.value = routeParams || {}
    routeStack.value[routeStack.value.length - 1] = route
    currentRoute.value = route
    
    await NativeBridge.invokeNativeModule('Navigation', 'replace', [{
      routeName: name,
      options: route.options || {},
    }])
  }

  async function reset(name: string, routeParams?: Record<string, any>) {
    const route = routeMap.get(name)
    if (!route) throw new Error(`Route '${name}' not found`)
    
    params.value = routeParams || {}
    routeStack.value = [route]
    currentRoute.value = route
    
    await NativeBridge.invokeNativeModule('Navigation', 'reset', [{
      routeName: name,
      options: route.options || {},
    }])
  }

  return {
    currentRoute,
    routeStack,
    params,
    navigate,
    goBack,
    replace,
    reset,
    install(app: any) {
      app.provide('router', { navigate, goBack, replace, reset, currentRoute, params })
    }
  }
}

// Composable for use in components
export function useRouter() {
  return inject('router') as ReturnType<typeof createRouter>
}

export function useRoute() {
  const router = useRouter()
  return {
    current: router.currentRoute,
    params: router.params,
  }
}
```

---

## 9. Layer 7: Styling System

### 9.1 Style Object API

Vue Native uses JavaScript style objects (like React Native), not CSS strings. This is because native views don't have a CSS engine — we must map each property to native equivalents.

```typescript
// Style objects follow React Native conventions for familiarity
const styles = {
  container: {
    flex: 1,
    flexDirection: 'column',
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f5f5f5',
    padding: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333333',
    marginBottom: 12,
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    width: '100%',
    maxWidth: 400,
  },
}
```

### 9.2 Supported Style Properties

**Layout (Yoga/Flexbox):** flex, flexDirection, flexWrap, flexGrow, flexShrink, flexBasis, justifyContent, alignItems, alignSelf, alignContent, position, top, right, bottom, left, width, height, minWidth, minHeight, maxWidth, maxHeight, margin (+ directional), padding (+ directional), gap, rowGap, columnGap, aspectRatio, overflow, display, zIndex

**Visual:** backgroundColor, opacity, borderRadius, borderWidth, borderColor, borderTopLeftRadius, borderTopRightRadius, borderBottomLeftRadius, borderBottomRightRadius

**Shadow:** shadowColor, shadowOffset, shadowOpacity, shadowRadius

**Text (VText only):** color, fontSize, fontWeight, fontFamily, fontStyle, textAlign, textDecorationLine, textDecorationColor, lineHeight, letterSpacing, textTransform

**Transform:** transform (array of { rotate, scale, translateX, translateY, scaleX, scaleY })

### 9.3 createStyleSheet Helper

```typescript
// packages/runtime/src/stylesheet.ts

export function createStyleSheet<T extends Record<string, Record<string, any>>>(styles: T): T {
  // In development: validate style properties
  // In production: pass-through (styles are just objects)
  if (__DEV__) {
    for (const [name, style] of Object.entries(styles)) {
      for (const prop of Object.keys(style)) {
        if (!isValidStyleProp(prop)) {
          console.warn(`[Vue Native] Unknown style property "${prop}" in style "${name}"`)
        }
      }
    }
  }
  // Freeze for performance (prevents accidental mutation)
  return Object.freeze(styles) as T
}
```

---

## 10. Layer 8: Developer Experience & Tooling

### 10.1 CLI Tool (`vue-native`)

```bash
# Create a new project
npx vue-native create my-app

# Run on iOS simulator
npx vue-native run ios

# Run on physical device  
npx vue-native run ios --device

# Start dev server (hot reload)
npx vue-native dev

# Build for production
npx vue-native build ios

# Generate Xcode project
npx vue-native xcode
```

### 10.2 Project Scaffold

```
my-app/
├── app/                          # Application source
│   ├── App.vue                   # Root component
│   ├── main.ts                   # Entry point
│   ├── pages/                    # Screen components
│   │   ├── Home.vue
│   │   ├── Detail.vue
│   │   └── Settings.vue
│   ├── components/               # Shared components
│   │   ├── Header.vue
│   │   └── Card.vue
│   ├── composables/              # Custom composables
│   │   └── useAuth.ts
│   ├── stores/                   # Pinia stores (works out of box)
│   │   └── user.ts
│   ├── assets/                   # Static assets
│   │   └── images/
│   └── styles/                   # Shared style objects
│       └── theme.ts
├── ios/                          # Xcode project (auto-generated)
│   ├── MyApp.xcodeproj
│   ├── MyApp/
│   │   ├── AppDelegate.swift
│   │   ├── Info.plist
│   │   └── Assets.xcassets
│   └── Podfile                   # Or Package.swift for SPM
├── native-modules/               # Custom native modules
│   └── MyCustomModule.swift
├── vue-native.config.ts          # Framework configuration
├── vite.config.ts                # Vite build configuration
├── tsconfig.json
└── package.json
```

### 10.3 Configuration File

```typescript
// vue-native.config.ts

import { defineConfig } from '@vue-native/cli'

export default defineConfig({
  // Application metadata
  app: {
    name: 'My App',
    bundleId: 'com.mycompany.myapp',
    version: '1.0.0',
    buildNumber: 1,
  },
  
  // iOS-specific configuration
  ios: {
    deploymentTarget: '16.0',
    teamId: 'XXXXXXXXXX',
    signingCertificate: 'Apple Development',
    provisioningProfile: 'Automatic',
    
    // Permissions (auto-added to Info.plist)
    permissions: {
      camera: 'We need camera access to take photos',
      photoLibrary: 'We need access to save photos',
      location: 'We need your location for nearby results',
    },
    
    // App icons and launch screen
    icons: './app/assets/icon.png',   // 1024x1024, auto-generates all sizes
    splashScreen: {
      backgroundColor: '#ffffff',
      image: './app/assets/splash.png',
    },
  },
  
  // JavaScript engine selection
  engine: 'jsc',  // 'jsc' (default) | 'hermes'
  
  // Plugin system
  plugins: [
    // Third-party native module plugins
  ],
  
  // Dev server
  devServer: {
    port: 8080,
    host: '0.0.0.0',
  },
})
```

---

## 11. Layer 9: Build System & Bundling

### 11.1 Build Pipeline

```
Developer's .vue files
        │
        ▼
   Vite + Vue Plugin          (compiles SFCs → render functions)
   + @vue-native/vite-plugin  (transforms style blocks → style objects,
        │                       strips <style> CSS, adds native shims)
        ▼
   Rollup Bundle               (tree-shakes, bundles all JS into one file)
        │
        ▼
   vue-native-bundle.js        (single JS file containing app + runtime)
        │
        ├──→ (Dev) Served via dev server for hot reload
        │
        └──→ (Prod) Embedded in Xcode project as resource
                     │
                     ▼
              Xcode Build → .ipa
              (includes Swift native code + JS bundle)
```

### 11.2 Vite Plugin

```typescript
// packages/vite-plugin/src/index.ts

import type { Plugin } from 'vite'

export function vueNative(): Plugin {
  return {
    name: 'vue-native',
    
    config(config) {
      return {
        define: {
          __DEV__: config.mode !== 'production',
          __PLATFORM__: JSON.stringify('ios'),
        },
        resolve: {
          alias: {
            // Redirect vue imports to vue-native runtime
            'vue': '@vue-native/runtime',
          },
          extensions: ['.vue', '.ts', '.tsx', '.js', '.jsx', '.json'],
        },
        build: {
          target: 'es2020',
          lib: {
            entry: 'app/main.ts',
            formats: ['iife'],
            name: 'VueNativeApp',
            fileName: 'vue-native-bundle',
          },
          rollupOptions: {
            output: {
              inlineDynamicImports: true,
            },
          },
        },
      }
    },
    
    transform(code, id) {
      // Transform .vue <style> blocks to JS style objects
      if (id.endsWith('.vue') && code.includes('<style')) {
        return transformNativeStyles(code)
      }
      return null
    },
  }
}

function transformNativeStyles(code: string): string {
  // Extract <style native> blocks and convert CSS-like syntax
  // to JavaScript style objects
  // Example: background-color: red; → backgroundColor: 'red'
  // This is a simplified transform — full implementation would parse CSS
  return code
}
```

---

## 12. Layer 10: Hot Reload / Dev Server

### 12.1 Architecture

```
┌─────────────────┐   WebSocket    ┌──────────────────┐
│  Dev Machine     │◄──────────────►│  iOS Simulator    │
│                  │                │  or Device        │
│  Vite Dev Server │   File change  │                   │
│  (port 8080)     │ ──────────────►│  JS Runtime       │
│                  │   HMR update   │  re-evaluates     │
│  Watches .vue    │                │  changed modules  │
│  files for edits │                │                   │
└─────────────────┘                └──────────────────┘
```

### 12.2 Dev Mode Bundle Loading

In development, instead of loading an embedded bundle, the app connects to the Vite dev server:

```swift
// In development mode:
func loadBundle() {
    let devServerURL = "http://localhost:8080/vue-native-bundle.js"
    
    if let url = URL(string: devServerURL),
       let bundleCode = try? String(contentsOf: url, encoding: .utf8) {
        jsContext.evaluateScript(bundleCode)
        startWebSocketConnection()  // For HMR updates
    } else {
        // Fall back to embedded bundle
        loadEmbeddedBundle()
    }
}
```

---

## 13. Project Structure & Monorepo

```
vue-native/
├── packages/
│   ├── runtime/                  # @vue-native/runtime
│   │   ├── src/
│   │   │   ├── renderer.ts       # Vue 3 custom renderer
│   │   │   ├── bridge.ts         # JS-side bridge
│   │   │   ├── components/       # Built-in component definitions
│   │   │   ├── composables/      # Built-in composables (useCamera, etc.)
│   │   │   └── stylesheet.ts     # Style helpers
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   ├── navigation/               # @vue-native/navigation
│   │   ├── src/
│   │   │   └── index.ts          # Router + navigation composables
│   │   └── package.json
│   │
│   ├── vite-plugin/              # @vue-native/vite-plugin
│   │   ├── src/
│   │   │   └── index.ts          # Vite plugin for build pipeline
│   │   └── package.json
│   │
│   ├── cli/                      # @vue-native/cli (vue-native command)
│   │   ├── src/
│   │   │   ├── commands/
│   │   │   │   ├── create.ts     # Project scaffolding
│   │   │   │   ├── run.ts        # Build + run on device/sim
│   │   │   │   ├── dev.ts        # Start dev server
│   │   │   │   └── build.ts      # Production build
│   │   │   └── index.ts
│   │   └── package.json
│   │
│   └── devtools/                 # @vue-native/devtools
│       ├── src/
│       │   └── index.ts          # Vue DevTools integration
│       └── package.json
│
├── native/                       # Swift native code
│   ├── Sources/VueNativeCore/
│   │   ├── Bridge/
│   │   │   ├── NativeBridge.swift
│   │   │   └── JSPolyfills.swift
│   │   ├── Components/
│   │   │   ├── ComponentRegistry.swift
│   │   │   └── Factories/
│   │   │       ├── VViewFactory.swift
│   │   │       ├── VTextFactory.swift
│   │   │       ├── VButtonFactory.swift
│   │   │       ├── VImageFactory.swift
│   │   │       ├── VInputFactory.swift
│   │   │       ├── VListFactory.swift
│   │   │       └── ... (all component factories)
│   │   ├── Modules/
│   │   │   ├── NativeModule.swift
│   │   │   ├── NativeModuleRegistry.swift
│   │   │   ├── CameraModule.swift
│   │   │   ├── GeolocationModule.swift
│   │   │   ├── HapticsModule.swift
│   │   │   ├── AsyncStorageModule.swift
│   │   │   └── ... (all native modules)
│   │   ├── Styling/
│   │   │   └── StyleEngine.swift
│   │   ├── Navigation/
│   │   │   └── NavigationController.swift
│   │   └── Helpers/
│   │       ├── UIColor+Hex.swift
│   │       └── GestureWrapper.swift
│   ├── Package.swift
│   └── Tests/
│
├── template/                     # Project template for `vue-native create`
│   ├── app/
│   ├── ios/
│   └── package.json
│
├── examples/                     # Example apps
│   ├── hello-world/
│   ├── todo-app/
│   └── photo-gallery/
│
├── docs/                         # Documentation (VitePress)
│
├── package.json                  # Root workspace
├── pnpm-workspace.yaml
└── turbo.json                    # Turborepo config
```

---

## 14. Implementation Roadmap

### Phase 1: Proof of Concept (2-3 weeks)

**Goal:** Render a Vue component as native UIKit views on iOS with user interaction.

**Deliverables:**
- [ ] Swift iOS app with embedded JavaScriptCore
- [ ] JSPolyfills (setTimeout, console, queueMicrotask, requestAnimationFrame)
- [ ] NativeBridge (Swift side) with operation processing
- [ ] NativeBridge (JS side) with batching
- [ ] Vue 3 custom renderer with createElement, patchProp, insert, remove
- [ ] 5 basic components: VView, VText, VButton, VInput, VImage
- [ ] Yoga/FlexLayout integration for Flexbox layout
- [ ] StyleEngine with basic properties (flex, padding, margin, backgroundColor, fontSize)
- [ ] Event handling: onPress, onChangeText
- [ ] Demo: Counter app + text input + styled layout

**Success Criteria:** A Vue SFC renders a counter with a button, text input, and styled layout using native UIKit views. Tapping the button increments the counter. Typing in the input updates text reactively.

### Phase 2: Make It Real (2-3 months)

**Deliverables:**
- [ ] Complete component set (25+ components)
- [ ] Full StyleEngine (all Yoga props, shadows, transforms, border radius)
- [ ] Navigation system (stack, tab, modal)
- [ ] 10+ native module composables (Camera, Geolocation, Storage, etc.)
- [ ] VList with view recycling (UITableView/UICollectionView)
- [ ] VImage with async loading and caching
- [ ] Animation system (spring, timing, gesture-driven)
- [ ] Vite build pipeline with @vue-native/vite-plugin
- [ ] Hot reload via WebSocket dev server
- [ ] CLI tool (create, run, dev, build)
- [ ] Error overlay in dev mode
- [ ] Pinia integration (works automatically since it's pure JS)
- [ ] TypeScript support with full component type definitions

### Phase 3: Production Ready (3-6 months)

**Deliverables:**
- [ ] Performance profiling and optimization
- [ ] Hermes engine support (optional, switchable)
- [ ] Binary MessagePack bridge protocol
- [ ] App Store deployment toolchain (code signing, provisioning)
- [ ] Xcode project generation
- [ ] Plugin system for third-party native modules
- [ ] Vue DevTools integration
- [ ] Accessibility support (VoiceOver, Dynamic Type)
- [ ] Dark mode support
- [ ] Gesture system (pan, pinch, rotation)
- [ ] Comprehensive test suite
- [ ] Documentation site (VitePress)
- [ ] 3 example apps (Todo, Photo Gallery, Chat)

### Phase 4: Android + Ecosystem (6-12 months)

**Deliverables:**
- [ ] Kotlin native side mirroring Swift component registry
- [ ] Android build tooling
- [ ] Platform-conditional code (.ios.vue / .android.vue)
- [ ] Shared code strategy documentation
- [ ] npm package ecosystem for community native modules
- [ ] VS Code extension (snippets, debugging)
- [ ] Expo-like managed workflow (optional)

---

## 15. Component API Reference

Detailed in Section 3.2 and Section 5.3 above. Each component follows this pattern:

```vue
<ComponentName
  :style="styleObject"
  :prop1="value1"
  @event1="handler1"
>
  <!-- children -->
</ComponentName>
```

All components support: `style`, `testID`, `accessibilityLabel`, `accessibilityHint`, `accessibilityRole`.

---

## 16. Native Module API Reference

Detailed in Section 7.2 and 7.3 above. Each module is accessed via a composable:

```typescript
import { useCamera, useHaptics, useGeolocation } from 'vue-native'

const { takePhoto } = useCamera()
const { vibrate } = useHaptics()
const { getCurrentPosition } = useGeolocation()
```

Third-party modules follow the same pattern by implementing the `NativeModule` Swift protocol and exposing a JS composable.

---

## 17. Developer-Facing API (What Users Write)

### 17.1 Entry Point

```typescript
// app/main.ts
import { createApp } from 'vue-native'
import { createRouter } from '@vue-native/navigation'
import { createPinia } from 'pinia'
import App from './App.vue'
import Home from './pages/Home.vue'
import Detail from './pages/Detail.vue'

const router = createRouter([
  { name: 'Home', component: Home, options: { title: 'Home' } },
  { name: 'Detail', component: Detail, options: { title: 'Detail' } },
])

const pinia = createPinia()

const app = createApp(App)
app.use(router)
app.use(pinia)
app.start()
```

### 17.2 Complete App Example

```vue
<!-- app/App.vue -->
<template>
  <VSafeArea :style="{ flex: 1, backgroundColor: '#f8f9fa' }">
    <router-view />
  </VSafeArea>
</template>

<!-- app/pages/Home.vue -->
<template>
  <VScroll :style="styles.container">
    <VView :style="styles.header">
      <VText :style="styles.title">{{ greeting }}</VText>
      <VText :style="styles.subtitle">Welcome to Vue Native</VText>
    </VView>

    <VView :style="styles.inputRow">
      <VInput
        v-model="name"
        placeholder="Enter your name"
        :style="styles.input"
        @submit="handleSubmit"
      />
    </VView>

    <VButton :style="styles.button" @press="takePicture">
      <VText :style="styles.buttonText">📸 Take Photo</VText>
    </VButton>

    <VImage
      v-if="photo"
      :source="photo.uri"
      :style="styles.photo"
      resizeMode="cover"
    />

    <VText :style="styles.counter">Count: {{ count }}</VText>

    <VView :style="styles.buttonRow">
      <VButton :style="styles.smallButton" @press="count++">
        <VText :style="styles.buttonText">+</VText>
      </VButton>
      <VButton :style="styles.smallButton" @press="count--">
        <VText :style="styles.buttonText">-</VText>
      </VButton>
    </VView>

    <VList
      :data="items"
      :keyExtractor="item => item.id"
      :style="styles.list"
    >
      <template #item="{ item }">
        <VButton
          :style="styles.listItem"
          @press="navigateToDetail(item)"
        >
          <VText :style="styles.listItemText">{{ item.title }}</VText>
        </VButton>
      </template>
    </VList>
  </VScroll>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useCamera, useHaptics, createStyleSheet } from 'vue-native'
import { useRouter } from '@vue-native/navigation'

const { navigate } = useRouter()
const { takePhoto: snap, photo } = useCamera()
const { vibrate } = useHaptics()

const name = ref('')
const count = ref(0)
const items = ref([
  { id: '1', title: 'Learn Vue Native' },
  { id: '2', title: 'Build an App' },
  { id: '3', title: 'Ship to App Store' },
])

const greeting = computed(() =>
  name.value ? `Hello, ${name.value}!` : 'Hello, World!'
)

async function takePicture() {
  vibrate('medium')
  await snap({ quality: 0.8 })
}

function handleSubmit() {
  vibrate('light')
}

function navigateToDetail(item: any) {
  navigate('Detail', { id: item.id, title: item.title })
}

const styles = createStyleSheet({
  container: {
    flex: 1,
    padding: 16,
  },
  header: {
    marginBottom: 24,
    alignItems: 'center',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1a1a2e',
  },
  subtitle: {
    fontSize: 16,
    color: '#666666',
    marginTop: 4,
  },
  inputRow: {
    marginBottom: 16,
  },
  input: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    padding: 14,
    fontSize: 16,
    borderWidth: 1,
    borderColor: '#e0e0e0',
  },
  button: {
    backgroundColor: '#4361ee',
    borderRadius: 12,
    padding: 16,
    alignItems: 'center',
    marginBottom: 16,
  },
  smallButton: {
    backgroundColor: '#4361ee',
    borderRadius: 8,
    padding: 12,
    width: 60,
    alignItems: 'center',
  },
  buttonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
    justifyContent: 'center',
    marginBottom: 16,
  },
  counter: {
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 12,
    color: '#1a1a2e',
  },
  photo: {
    width: '100%',
    height: 200,
    borderRadius: 12,
    marginBottom: 16,
  },
  list: {
    flex: 1,
  },
  listItem: {
    backgroundColor: '#ffffff',
    borderRadius: 8,
    padding: 16,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: '#f0f0f0',
  },
  listItemText: {
    fontSize: 16,
    color: '#333333',
  },
})
</script>
```

---

## 18. Performance Targets & Benchmarks

| Metric | Target | React Native Reference |
|--------|--------|----------------------|
| Cold start time | < 400ms | ~500ms |
| JS bundle parse time | < 100ms | ~150ms (Hermes bytecode) |
| First meaningful paint | < 600ms | ~700ms |
| 60 FPS scroll (VList, 1000 items) | Sustained | Sustained |
| Memory (idle, simple app) | < 40MB | ~50MB |
| JS → Native round trip | < 1ms | < 1ms (JSI) |
| Bridge batch processing (100 ops) | < 5ms | ~3ms (Fabric) |
| App binary size overhead | < 3MB | ~7MB (Hermes) |

Vue Native should be competitive because:
- JSC is already on the device (0MB engine overhead)
- Fine-grained reactivity means fewer bridge calls than React's reconciler
- Operation batching via microtask queue matches React Native's Fabric approach
- Yoga is the same layout engine React Native uses

---

## 19. Testing Strategy

### Unit Tests (JS)
- Vue custom renderer operations (create, patch, insert, remove)
- Bridge serialization/batching
- Composable behavior
- Navigation router state

### Unit Tests (Swift)
- Component factory prop updates
- StyleEngine property mapping
- NativeModule invocations
- Bridge operation processing

### Integration Tests
- Full render cycle: Vue component → bridge → native view hierarchy
- Event cycle: native touch → bridge → JS handler → state update → re-render
- Navigation transitions

### E2E Tests
- XCTest UI tests on simulator
- Detox-style automated UI testing

---

## 20. Future: Android/Kotlin Port

The architecture is designed for cross-platform from day one:

1. **JS Layer is shared** — the renderer, bridge (JS side), composables, and all app code are platform-agnostic.
2. **Native Layer is per-platform** — only the Swift code needs a Kotlin mirror:
   - `ComponentRegistry.swift` → `ComponentRegistry.kt`
   - `NativeBridge.swift` → `NativeBridge.kt` (using J2V8 or Hermes Android)
   - `StyleEngine.swift` → `StyleEngine.kt` (Yoga has native Android bindings)
   - Each `*Factory.swift` → `*Factory.kt` (mapping to Android Views)

| Vue Native Component | iOS (UIKit) | Android (planned) |
|---------------------|-------------|-------------------|
| `<VView>` | UIView | android.view.View |
| `<VText>` | UILabel | android.widget.TextView |
| `<VButton>` | TouchableView | android.widget.Button |
| `<VImage>` | UIImageView | android.widget.ImageView |
| `<VInput>` | UITextField | android.widget.EditText |
| `<VScroll>` | UIScrollView | android.widget.ScrollView |
| `<VList>` | UITableView | androidx.recyclerview.widget.RecyclerView |
| `<VSwitch>` | UISwitch | android.widget.Switch |

---

## Appendix A: React Native Architecture Comparison

| Aspect | React Native (New Arch) | Vue Native |
|--------|------------------------|------------|
| JS Engine | Hermes (default) | JSC (default), Hermes (optional) |
| JS → Native | JSI (C++ direct memory refs) | JSContext function calls (Phase 1), JSI-style (Phase 2+) |
| Renderer | Fabric (C++ shadow tree) | Vue custom renderer → NativeBridge |
| Layout | Yoga (C++) | Yoga (via FlexLayout Swift wrapper) |
| Native Modules | TurboModules (JSI) | NativeModule protocol + composables |
| State Updates | React reconciler diffs vDOM | Vue reactivity tracks exact dependencies |
| Batching | Fabric batches renders | Microtask queue batches bridge ops |
| Code Generation | Codegen for type safety | TypeScript interfaces |
| Threading | JS, Shadow, UI threads | JS, Layout, Main threads |

---

## Appendix B: JavaScript Engine Decision Matrix

| Engine | App Size Impact | Cold Start | Runtime Perf | iOS Support | Complexity |
|--------|----------------|------------|--------------|-------------|------------|
| **JavaScriptCore** (built-in) | **0 MB** | Medium | High (JIT) | ✅ Native | **Low** |
| **Hermes** (Facebook) | ~3 MB | **Fast** (AOT bytecode) | Medium (no JIT) | ✅ | Medium |
| **QuickJS** | ~200 KB | Fast | Low | ✅ (C, embeddable) | Low |
| **V8** | ~7 MB | Medium | **Highest** (JIT) | ⚠️ No JIT on iOS | High |

**Recommendation:** Start with JSC (Phase 1-2) because it's free, fast, and zero-overhead. Add Hermes support in Phase 3 for AOT bytecode benefits (faster cold start, smaller JS bundles). Let developers choose via config.

---

## Appendix C: Full RendererOptions Interface

From Vue 3 source (`@vue/runtime-core`):

```typescript
interface RendererOptions<HostNode, HostElement> {
  patchProp(
    el: HostElement,
    key: string,
    prevValue: any,
    nextValue: any,
    namespace?: ElementNamespace,
    parentComponent?: ComponentInternalInstance | null
  ): void
  
  insert(el: HostNode, parent: HostElement, anchor?: HostNode | null): void
  remove(el: HostNode): void
  
  createElement(
    type: string,
    namespace?: ElementNamespace,
    isCustomizedBuiltIn?: string,
    vnodeProps?: (VNodeProps & { [key: string]: any }) | null
  ): HostElement
  
  createText(text: string): HostNode
  createComment(text: string): HostNode
  
  setText(node: HostNode, text: string): void
  setElementText(node: HostElement, text: string): void
  
  parentNode(node: HostNode): HostElement | null
  nextSibling(node: HostNode): HostNode | null
  
  // Optional
  querySelector?(selector: string): HostElement | null
  setScopeId?(el: HostElement, id: string): void
  cloneNode?(node: HostNode): HostNode
  insertStaticContent?(
    content: string,
    parent: HostElement,
    anchor: HostNode | null,
    namespace: ElementNamespace,
    start?: HostNode | null,
    end?: HostNode | null
  ): [HostNode, HostNode]
}
```

All required methods are implemented in our custom renderer (Section 3.1). Optional methods (`querySelector`, `cloneNode`, `insertStaticContent`) are not needed for native rendering.

---

## End of Specification

**Next Step:** Open a Claude Code session and use this spec as the foundation document. Begin with Phase 1 — the proof of concept.