import AppKit
import VueNativeShared

/// Native module for sharing content on macOS via NSSharingServicePicker.
///
/// Methods:
///   - share({ message?: String, url?: String }) -> { action: String }
final class ShareModule: NativeModule {
    var moduleName: String { "Share" }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "share":
            guard let content = args.first as? [String: Any] else {
                callback(nil, "Invalid content")
                return
            }
            var items: [Any] = []
            if let message = content["message"] as? String { items.append(message) }
            if let urlStr = content["url"] as? String, let u = URL(string: urlStr) { items.append(u) }
            if items.isEmpty { callback(nil, "No shareable content"); return }

            DispatchQueue.main.async {
                let picker = NSSharingServicePicker(items: items)
                if let window = NSApp.mainWindow, let view = window.contentView {
                    picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
                }
                callback(["action": "shared"], nil)
            }

        default:
            callback(nil, "ShareModule: Unknown method '\(method)'")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
