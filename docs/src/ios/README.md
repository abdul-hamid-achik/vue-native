# iOS Guide

Vue Native targets **iOS 16+** using UIKit, JavaScriptCore, and Yoga layout.

## Requirements

- iOS 16.0+
- Xcode 15+
- Swift 5.9+

## Native package

The iOS native code lives in `native/ios/VueNativeCore/` — a Swift Package Manager package.

```
native/ios/VueNativeCore/
├── Package.swift
├── Sources/VueNativeCore/
│   ├── Bridge/
│   │   ├── JSRuntime.swift          # JSContext lifecycle, polyfills
│   │   ├── NativeBridge.swift       # Receives batched JS ops → UIKit
│   │   ├── VueNativeViewController.swift  # Base VC for your app
│   │   └── HotReloadManager.swift   # WebSocket hot reload
│   ├── Components/
│   │   └── Factories/               # One factory per component
│   ├── Modules/                     # Native module implementations
│   └── Styling/
│       └── StyleEngine.swift        # Style prop → UIKit/Yoga mapping
└── Tests/
```

## Integration

Add the package to your Xcode project via `project.yml`:

```yaml
packages:
  VueNativeCore:
    path: ../../../native/ios/VueNativeCore
```

## VueNativeViewController

The simplest integration is to subclass `VueNativeViewController`:

```swift
import VueNativeCore

class MyAppViewController: VueNativeViewController {
    override var bundleName: String { "vue-native-bundle" }

    #if DEBUG
    override var devServerURL: URL? {
        URL(string: "ws://localhost:8174")
    }
    #endif
}
```

See the [VueNativeViewController reference](./VueNativeViewController.md) for full details.
