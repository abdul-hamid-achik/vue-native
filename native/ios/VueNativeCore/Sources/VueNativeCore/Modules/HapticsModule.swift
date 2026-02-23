#if canImport(UIKit)
import UIKit

/// Native module providing haptic feedback.
///
/// Methods:
///   - vibrate(style: String) -- trigger impact feedback ("light"|"medium"|"heavy"|"rigid"|"soft")
///   - notificationFeedback(type: String) -- "success"|"warning"|"error"
///   - selectionChanged() -- selection change feedback
final class HapticsModule: NativeModule {
    let moduleName = "Haptics"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            switch method {
            case "vibrate":
                let style = args.first as? String ?? "medium"
                let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
                switch style {
                case "light": feedbackStyle = .light
                case "heavy": feedbackStyle = .heavy
                case "rigid": feedbackStyle = .rigid
                case "soft": feedbackStyle = .soft
                default: feedbackStyle = .medium
                }
                UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
                callback(nil, nil)

            case "notificationFeedback":
                let type = args.first as? String ?? "success"
                let feedbackType: UINotificationFeedbackGenerator.FeedbackType
                switch type {
                case "warning": feedbackType = .warning
                case "error": feedbackType = .error
                default: feedbackType = .success
                }
                UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
                callback(nil, nil)

            case "selectionChanged":
                UISelectionFeedbackGenerator().selectionChanged()
                callback(nil, nil)

            default:
                callback(nil, "HapticsModule: Unknown method '\(method)'")
            }
        }
    }
}
#endif
