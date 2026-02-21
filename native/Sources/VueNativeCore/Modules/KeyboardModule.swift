#if canImport(UIKit)
import UIKit

/// Native module providing keyboard management.
///
/// Methods:
///   - dismiss() -- dismiss the keyboard
///   - getHeight() -> { height: CGFloat, isVisible: Bool }
final class KeyboardModule: NativeModule {
    let moduleName = "Keyboard"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            switch method {
            case "dismiss":
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                callback(nil, nil)

            case "getHeight":
                callback(["height": 0.0, "isVisible": false], nil)

            default:
                callback(nil, "KeyboardModule: Unknown method '\(method)'")
            }
        }
    }
}
#endif
