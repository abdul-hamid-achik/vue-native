import AppKit
import VueNativeShared

/// Native module providing haptic feedback via Force Touch trackpad.
///
/// Methods:
///   - vibrate(style: String) -- trigger haptic feedback ("light"|"medium"|"heavy")
///   - notificationFeedback(type: String) -- generic haptic (macOS has no distinct types)
///   - selectionChanged() -- alignment feedback
final class HapticsModule: NativeModule {
    let moduleName = "Haptics"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            switch method {
            case "vibrate":
                let style = args.first as? String ?? "medium"
                let pattern: NSHapticFeedbackManager.FeedbackPattern
                switch style {
                case "light": pattern = .alignment
                case "medium": pattern = .levelChange
                case "heavy": pattern = .generic
                default: pattern = .generic
                }
                NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
                callback(nil, nil)

            case "notificationFeedback":
                // macOS doesn't have distinct notification haptics — use generic
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                callback(nil, nil)

            case "selectionChanged":
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                callback(nil, nil)

            default:
                callback(nil, "HapticsModule: Unknown method '\(method)'")
            }
        }
    }
}
