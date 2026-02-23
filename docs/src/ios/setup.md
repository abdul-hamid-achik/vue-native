# iOS Setup

## New project

```bash
npx @thelacanians/cli create my-app
cd my-app
bun install
```

Open `ios/` in Xcode and run on a simulator.

## Add to existing Xcode project

### 1. Add the Swift package

In Xcode: **File → Add Package Dependencies** → **Add Local** → select `native/ios/VueNativeCore`.

Or with XcodeGen (`project.yml`):

```yaml
packages:
  VueNativeCore:
    path: ../path/to/native/ios/VueNativeCore

targets:
  MyApp:
    dependencies:
      - package: VueNativeCore
        product: VueNativeCore
```

### 2. Copy the JS bundle at build time

Add a **Run Script** build phase:

```bash
cp "${SRCROOT}/../dist/vue-native-bundle.js" \
   "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/vue-native-bundle.js"
```

### 3. Configure your view controller

```swift
// MyAppViewController.swift
import VueNativeCore

class MyAppViewController: VueNativeViewController {
    override var bundleName: String { "vue-native-bundle" }
}
```

### 4. Set your window's root VC

```swift
// SceneDelegate.swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = MyAppViewController()
    window.makeKeyAndVisible()
    self.window = window
}
```

## Info.plist

No special keys are required for basic usage. For native modules:

| Module | Info.plist key |
|--------|---------------|
| Camera | `NSCameraUsageDescription` |
| Photo library | `NSPhotoLibraryUsageDescription` |
| Microphone | `NSMicrophoneUsageDescription` |
| Location | `NSLocationWhenInUseUsageDescription` |
| Face ID | `NSFaceIDUsageDescription` |
