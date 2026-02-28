# AGENTS.md — VueNativeShared

Guidelines for AI agents working on the shared Swift package.

---

## What this package is

VueNativeShared is a cross-platform Swift package containing code shared between iOS (`VueNativeCore`) and macOS (`VueNativeMacOS`). It provides the JS engine interface, infrastructure protocols, and platform-agnostic native modules.

**Platforms:** iOS 16+, macOS 13+
**Swift:** 5.9+, no SwiftUI

---

## Package structure

```
Sources/VueNativeShared/
  JSRuntime.swift              JSContext wrapper on serial DispatchQueue
  SharedJSPolyfills.swift      JSON encoding helpers for polyfill strings
  EventThrottle.swift          Throttle events to ~60fps (DispatchSourceTimer)
  HotReloadManager.swift       WebSocket-based hot reload (URLSessionWebSocketTask)
  CertificatePinning.swift     TLS certificate pinning (URLSession + Security)
  NativeModule.swift           Protocol — all native modules conform to this
  NativeModuleRegistry.swift   Singleton registry mapping module names → instances
  NativeEventDispatcher.swift  Protocol for cross-platform event dispatch
  Modules/
    AsyncStorageModule.swift   UserDefaults key-value storage
    NetworkModule.swift        NWPathMonitor network connectivity
    FileSystemModule.swift     FileManager file operations
    SecureStorageModule.swift   Keychain secure storage
    AudioModule.swift          AVAudioPlayer audio playback
    GeolocationModule.swift    CLLocationManager location services
    DatabaseModule.swift       SQLite database operations
    WebSocketModule.swift      URLSession WebSocket client
    PerformanceModule.swift    ProcessInfo performance metrics
Tests/VueNativeSharedTests/
  VueNativeSharedTests.swift   XCTest suite (6 tests)
```

---

## Build & test

```bash
swift build    # Must compile without errors
swift test     # All tests must pass (currently 6)
```

Or from the monorepo root:
```bash
bun run test:shared
```

---

## Architecture rules

### NativeModule protocol
- All native modules conform to `public protocol NativeModule: AnyObject`
- Required: `var moduleName: String` and `func invoke(method:args:callback:)`
- Optional: `func invokeSync(method:args:) -> Any?` (default returns nil)
- Modules are registered in `NativeModuleRegistry.shared`
- **Do NOT redefine this protocol in platform packages** — import VueNativeShared instead

### JSRuntime
- JSContext runs on a dedicated serial `DispatchQueue` (`jsQueue`)
- **Never pass JSValue across threads** — extract primitives first
- Always use `[weak self]` in closures registered with JSContext
- JSC has native Promise support (iOS 13+ / macOS 10.15+)

### EventThrottle
- Uses `CACurrentMediaTime()` for high-precision timing
- `DispatchSourceTimer` for deferred firing — NOT `Timer` or `RunLoop`
- Thread-safe: can be created and fired from any queue

### Thread safety
- `NativeModuleRegistry` is **not** thread-safe — access from main thread only
- `CertificatePinning` uses a serial queue internally
- `HotReloadManager` runs WebSocket on a background queue, dispatches UI updates to main

---

## Coding conventions

- All public API types must be marked `public`
- Use `guard let` / `if let` — no force-unwraps (`!`) in production code
- Modules should handle errors gracefully: call `callback(nil, errorMessage)` on failure
- Keep modules platform-agnostic — use only Foundation, Security, CoreLocation, and similar frameworks available on both iOS and macOS
- Do NOT import UIKit or AppKit in this package

---

## How to add a shared module

1. Create `Sources/VueNativeShared/Modules/<Name>Module.swift`
2. Conform to `NativeModule` protocol
3. Implement `moduleName`, `invoke(method:args:callback:)`, and optionally `invokeSync`
4. Register in both platform packages' `NativeModuleRegistry.registerDefaults()`
5. Add tests in `Tests/VueNativeSharedTests/`
6. Only use frameworks available on both iOS 16+ and macOS 13+

---

## Common pitfalls

| Mistake | Why it breaks | Fix |
|---------|---------------|-----|
| Importing UIKit or AppKit | Package must be platform-agnostic | Use Foundation, CoreLocation, etc. |
| Force-unwrapping module args | Crashes if JS passes unexpected types | Use `as?` with guard/if-let |
| Accessing JSValue off jsQueue | JSContext is not thread-safe | Extract primitives on jsQueue first |
| Redefining NativeModule in platform package | Creates shadowing, type mismatches | Import VueNativeShared instead |
| Forgetting to register module | Module exists but is unreachable from JS | Add to registerDefaults() in both platforms |

---

## Key file locations

| What | Path |
|------|------|
| NativeModule protocol | `Sources/VueNativeShared/NativeModule.swift` |
| Module registry | `Sources/VueNativeShared/NativeModuleRegistry.swift` |
| JS runtime | `Sources/VueNativeShared/JSRuntime.swift` |
| Event throttle | `Sources/VueNativeShared/EventThrottle.swift` |
| Hot reload | `Sources/VueNativeShared/HotReloadManager.swift` |
| Certificate pinning | `Sources/VueNativeShared/CertificatePinning.swift` |
| Tests | `Tests/VueNativeSharedTests/VueNativeSharedTests.swift` |
| Package manifest | `Package.swift` |
