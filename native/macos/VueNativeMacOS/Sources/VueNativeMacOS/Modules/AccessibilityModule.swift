import AppKit
import VueNativeShared

/// Native module exposing screen-reader (VoiceOver) announcements and
/// accessibility focus management to the `useAccessibility` composable.
///
/// Methods:
///   - announce(message: String) -- ask VoiceOver to speak a message without moving focus
///   - setFocus(nodeId: Int) -- move accessibility focus to the view with the given node id
///
/// Both methods are best-effort: they never crash and report failures through
/// the async callback so the JS side can log a warning.
final class AccessibilityModule: NativeModule {

    let moduleName = "Accessibility"
    private let viewLookup: (Int) -> NSView?

    init(viewLookup: @escaping (Int) -> NSView?) {
        self.viewLookup = viewLookup
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "announce":
            handleAnnounce(args: args, callback: callback)
        case "setFocus":
            handleSetFocus(args: args, callback: callback)
        default:
            callback(nil, "AccessibilityModule: Unknown method '\(method)'")
        }
    }

    // MARK: - announce(message)

    private func handleAnnounce(args: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let message = args.first as? String else {
            callback(nil, "announce: missing message")
            return
        }

        DispatchQueue.main.async {
            // AppKit expects announcement requests to be posted against the
            // application element. The priority key is required for VoiceOver to
            // decide whether to speak immediately or after the current utterance.
            NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested, userInfo: [
                NSAccessibility.NotificationUserInfoKey.announcement: message,
                NSAccessibility.NotificationUserInfoKey.priority: NSAccessibilityPriorityLevel.high.rawValue,
            ])
            callback(nil, nil)
        }
    }

    // MARK: - setFocus(nodeId)

    private func handleSetFocus(args: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let nodeId = Self.coerceInt(args.first) else {
            callback(nil, "setFocus: invalid node id")
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let view = self?.viewLookup(nodeId) else {
                callback(nil, "setFocus: view \(nodeId) not found")
                return
            }

            // Best-effort: tell assistive apps that focus moved to this element.
            // The notification automatically checks NSApp for registered observers.
            NSAccessibility.post(element: view, notification: .focusedUIElementChanged, userInfo: nil)
            callback(nil, nil)
        }
    }

    // MARK: - Helpers

    /// JS numbers arrive as Int or Double (JavaScriptCore); accept both.
    private static func coerceInt(_ value: Any?) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        return nil
    }
}
