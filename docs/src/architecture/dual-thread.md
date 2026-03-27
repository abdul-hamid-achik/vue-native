# Dual-Thread Architecture Research

## Executive Summary

This document outlines research into implementing a dual-thread architecture for Vue Native, inspired by LynxJS's approach. The current Vue Native implementation is single-threaded (JS runs on the main thread), while LynxJS runs Vue on a background thread with native rendering on the main thread.

## Current Architecture (Vue Native)

```
┌─────────────────────────────────────────────────────────────────┐
│                        Main Thread                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │   JSRuntime  │◀──▶│ NativeBridge │◀──▶│  Native Views   │  │
│  │  (JSContext) │    │  (operations) │    │  (UIKit/Views)  │  │
│  └──────────────┘    └──────────────┘    └──────────────────┘  │
│        │                    │                     │              │
│        ▼                    ▼                     ▼              │
│   Vue Renderer         Batch queue           Layout engine     │
│   Reactivity           ─────────────▶         (Yoga/Flexbox)   │
│   Components           JSON bridge             ───────────▶    │
└─────────────────────────────────────────────────────────────────┘

All JS execution happens on MAIN THREAD via:
- iOS: JSContext (JavaScriptCore)
- Android: V8 (J2V8)  
- macOS: JSContext (JavaScriptCore)

Critical constraint: JS execution blocks UI responsiveness
```

### Current Bridge Protocol

```typescript
// All operations batched and flushed via queueMicrotask
class NativeBridgeImpl {
  private pendingOps: BridgeOperation[] = []
  
  enqueue(op: string, args: unknown[]) {
    this.pendingOps.push({ op, args })
    if (!this.flushScheduled) {
      this.flushScheduled = true
      queueMicrotask(() => this.flush())
    }
  }
  
  flush() {
    const json = JSON.stringify(this.pendingOps)
    globalThis.__VN_flushOperations?.(json)
    this.pendingOps = []
    this.flushScheduled = false
  }
}
```

## LynxJS Architecture (Target)

```
┌─────────────────────────────────────────────────────────────────┐
│                      Background Thread                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    JS Runtime                              │  │
│  │  ┌────────────┐  ┌────────────┐  ┌────────────────────┐  │  │
│  │  │    Vue     │  │ Reactivity │  │   Component Tree   │  │  │
│  │  │  Renderer  │  │   System   │  │   (Virtual DOM)    │  │  │
│  │  └────────────┘  └────────────┘  └────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Serialized operations ( protobuf / binary)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Main Thread                               │
│  ┌──────────────────┐    ┌──────────────────────────────────┐  │
│  │  Native Bridge    │    │         Native Views            │  │
│  │  (decode ops)    │────▶│   UIKit / FlexboxLayout         │  │
│  └──────────────────┘    └──────────────────────────────────┘  │
│                                │                                │
│                                ▼                                │
│                         Layout Engine                           │
│                         (Yoga/Flexbox)                          │
└─────────────────────────────────────────────────────────────────┘
```

### Key Benefits

1. **Non-blocking UI**: JS can run heavy computations without freezing the UI
2. **Smoother animations**: Layout happens on main thread, uninterrupted by JS
3. **Better scroll performance**: List scrolling doesn't compete with JS
4. **Time-sliced rendering**: Can yield to UI thread during heavy renders

### Key Challenges

1. **Thread safety**: JS objects (JSValue/V8Object) cannot cross thread boundaries
2. **Event handling**: Touch events must be serialized from main to JS thread
3. **State synchronization**: Updates from native must be safely propagated
4. **Debugging**: Two threads complicate the debugging experience

## Implementation Strategy

### Phase 1: Thread-Isolated Operations (Non-breaking)

1. **Identify thread-safe operations**
   - Operations that don't return JSValues (void, primitives)
   - Operations that can be serialized to JSON

2. **Create operation serializer**
   ```typescript
   // New: ThreadPoolBridge
   interface SerializedOperation {
     op: string
     args: JSONValue[]  // No functions, no JSValues
     callbackId?: number
   }
   
   class ThreadPoolBridge {
     private workerQueue: DispatchQueue  // iOS / macOS
     private mainHandler: Handler         // Android
     
     enqueue(op: string, args: JSONValue[]) {
       const serialized = JSON.stringify({ op, args })
       // Post to background worker
       this.workerQueue.async {
         // Execute JS on background thread
         jsRuntime.execute(serialized)
         // Post result back to main
         DispatchQueue.main.async {
           nativeBridge.processResult(...)
         }
       }
     }
   }
   ```

3. **Batch by priority**
   - High priority: user input, touch events
   - Normal priority: property updates, style changes
   - Low priority: non-urgent state updates

### Phase 2: Background JS Runtime (Breaking Changes Required)

#### iOS/macOS Architecture

```swift
// Current: JSContext on main thread (via JSQueue)
class JSRuntime {
    private let context: JSContext
    private let jsQueue = DispatchQueue(label: "VueNative-JS")
    // ... runs on jsQueue, but blocks main thread during flush
}

// Proposed: Separate render thread from JS thread
class ThreadedJSRuntime {
    private let context: JSContext
    private let jsQueue = DispatchQueue(label: "VueNative-JS-Background")
    private let renderQueue = DispatchQueue.main  // Main thread for native
    
    func execute(_ script: String) {
        jsQueue.async {
            let result = self.context.evaluateScript(script)
            // Queue render operations for main thread
            self.renderQueue.async {
                self.processOperations(result)
            }
        }
    }
}
```

#### Android Architecture

```kotlin
// Current: V8 on HandlerThread, but operations still block
class JSRuntime(private val handlerThread: HandlerThread) {
    // ... operations still synchronously block UI
}

// Proposed: Fully asynchronous bridge
class ThreadedJSRuntime {
    private val jsHandler = Handler(jsThread.looper)
    private val mainHandler = Handler(Looper.getMainLooper())
    
    fun execute(script: String) {
        jsHandler.post {
            val result = v8.executeObjectScript(script)
            val operations = result.toSerializedOperations()
            mainHandler.post {
                nativeBridge.process(operations)
            }
        }
    }
}
```

### Phase 3: Event Threading

Touch and gesture events must be posted from main thread to JS thread:

```swift
// iOS: Touch events
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    let serializedTouches = touches.map { serializeTouch($0) }
    jsQueue.async {
        self.dispatchEvent("touchstart", serializedTouches)
    }
}
```

```kotlin
// Android: Touch events
override fun onTouchEvent(event: MotionEvent): Boolean {
    val serializedEvent = serializeMotionEvent(event)
    jsHandler.post {
        dispatchEvent("touchstart", serializedEvent)
    }
    return true
}
```

### Phase 4: State Synchronization

For native component state (e.g., scroll position, text input value):

```typescript
// New: SyncedState wrapper
class SyncedState<T> {
  private value: T
  private listeners: Set<(T) => void> = new Set()
  
  // Main thread writes
  writeMainThread(newValue: T) {
    this.value = newValue
    this.postToJSThread({ type: 'sync', value: newValue })
  }
  
  // JS thread reads
  readJSThread(): T {
    return this.value
  }
  
  // JS thread writes
  writeJSThread(newValue: T) {
    this.value = newValue
    this.postToMainThread({ type: 'sync', value: newValue })
  }
}
```

## Migration Path

### Backward Compatibility

1. **Feature flag**: `VUENATIVE_THREADED=true` to opt-in to dual-thread
2. **Fallback mode**: Automatic fallback to single-thread if threading fails
3. **Hybrid mode**: Run only non-interactive views on background thread

### API Changes Required

```typescript
// Current: Direct sync operations
NativeBridge.createNode(1, 'VView')  // Blocks until complete

// Proposed: Async-by-default
await NativeBridge.createNode(1, 'VView')  // Returns promise
// Or fire-and-forget with callback
NativeBridge.createNode(1, 'VView', (nodeId) => { ... })
```

## Performance Targets

| Metric | Current (single-thread) | Target (dual-thread) |
|--------|------------------------|---------------------|
| JS execution | Blocks UI | Non-blocking |
| Touch response latency | < 16ms (ideal) | < 16ms (guaranteed) |
| 60fps scroll maintain | Degraded with JS load | Stable |
| Large list render (1000 items) | ~100ms frame drop | < 50ms, no frame drop |
| Animation smoothness with JS | Degraded | Native-level |

## Estimated Effort

| Phase | Scope | Effort | Risk |
|-------|-------|--------|------|
| Phase 1 | Thread-safe ops identification | 2 weeks | Low |
| Phase 2 | Background JS runtime | 4-6 weeks | Medium |
| Phase 3 | Event threading | 2-3 weeks | Medium |
| Phase 4 | State synchronization | 2 weeks | Low |
| Testing & Debugging | Full regression testing | 3-4 weeks | Medium |
| **Total** | | **13-17 weeks** | **Medium** |

## Recommendation

1. **Start with Phase 1** in the next minor version
   - Identify thread-safe operations
   - Create serialization layer
   - No breaking changes

2. **Phase 2-4** as a major version (v2.0)
   - Full dual-thread architecture
   - Breaking API changes (async operations)
   - New debugging tooling

3. **Provide migration guide**
   - Document async patterns
   - Provide codemods for common sync operations
   - Compatibility layer for gradual migration

## References

- LynxJS Architecture: https://github.com/lynx-family/lynx-stack
- React Native Bridge: https://reactnative.dev/docs/bridge
- Flutter Engine Threading: https://docs.flutter.dev/resources/architectural-overview
- Dart Isolates: https://dart.dev/language/concurrency

---

# Summary for Implementation

## Quick Wins (Can Do Now)

1. **Operation batching improvements**
   - Separate high/low priority operation queues
   - Already partially implemented

2. **Time-sliced rendering**
   - Break large updates into smaller chunks
   - Yield to browser/native between chunks

3. **Memoization at bridge level**
   - Batch style updates within a frame
   - Deduplicate property updates

## Medium-Term (v1.x)

1. **Background thread for non-UI operations**
   - Network requests
   - Data processing
   - Storage operations

2. **Native animation driver**
   - Run animations entirely on native thread
   - No JS bridge during animation

## Long-Term (v2.0)

1. **Full dual-thread architecture**
   - JS on background thread
   - Native on main thread
   - Async bridge protocol

2. **New debugging tools**
   - Thread-aware DevTools
   - Performance profiler
   - Bridge inspector