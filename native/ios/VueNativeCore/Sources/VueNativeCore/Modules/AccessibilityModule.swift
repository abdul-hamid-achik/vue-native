#if canImport(UIKit)
import UIKit

/// Native module providing screen-reader (VoiceOver) accessibility helpers.
///
/// Methods:
///   - announce(message: String) -- announce a message via VoiceOver without moving focus
///   - setFocus(nodeId: Int) -- move VoiceOver accessibility focus to the view for nodeId
///
/// Backs the `useAccessibility()` composable on the JS side. All UIKit and
/// view-registry access happens on the main thread; failures are reported
/// best-effort through the callback rather than crashing.
final class AccessibilityModule: NativeModule {
    let moduleName = "Accessibility"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "announce":
            guard let message = args.first as? String else {
                callback(nil, "announce: missing message")
                return
            }
            DispatchQueue.main.async {
                UIAccessibility.post(notification: .announcement, argument: message)
                callback(nil, nil)
            }

        case "setFocus":
            // JS numbers frequently cross the bridge as Double, so accept either.
            guard let nodeId = args.first.flatMap({ $0 as? Int ?? ($0 as? Double).map(Int.init) }) else {
                callback(nil, "setFocus: missing nodeId")
                return
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let view = NativeBridge.shared.view(forId: nodeId) else {
                        callback(nil, "setFocus: view \(nodeId) not found")
                        return
                    }
                    UIAccessibility.post(notification: .screenChanged, argument: view)
                    callback(nil, nil)
                }
            }

        default:
            callback(nil, "AccessibilityModule: Unknown method '\(method)'")
        }
    }
}
#endif
