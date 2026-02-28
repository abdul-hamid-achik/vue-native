import AppKit
import VueNativeShared

/// Native module providing keyboard management for macOS.
///
/// Methods:
///   - dismiss() -- resign first responder (dismiss any focused input)
///   - getHeight() -> { height: 0, isVisible: false } (macOS has no virtual keyboard)
final class KeyboardModule: NativeModule {
    let moduleName = "Keyboard"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            switch method {
            case "dismiss":
                NSApp.mainWindow?.makeFirstResponder(nil)
                callback(nil, nil)

            case "getHeight":
                // macOS has no virtual keyboard
                callback(["height": 0.0, "isVisible": false], nil)

            default:
                callback(nil, "KeyboardModule: Unknown method '\(method)'")
            }
        }
    }
}
