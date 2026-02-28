import AppKit
import VueNativeShared

/// Native module for opening URLs and deep links on macOS.
///
/// Methods:
///   - openURL(url: String) -> Bool
///   - canOpenURL(url: String) -> Bool
///   - getInitialURL() -> String?
final class LinkingModule: NativeModule {
    var moduleName: String { "Linking" }

    /// The URL that launched the app. Set by the host app before the JS bundle loads.
    static var initialURL: String?

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "openURL":
            guard let urlString = args.first as? String,
                  let url = URL(string: urlString) else {
                callback(nil, "Invalid URL")
                return
            }
            DispatchQueue.main.async {
                let success = NSWorkspace.shared.open(url)
                callback(success, success ? nil : "Failed to open URL")
            }

        case "canOpenURL":
            guard let urlString = args.first as? String,
                  let url = URL(string: urlString) else {
                callback(false, nil)
                return
            }
            DispatchQueue.main.async {
                let canOpen = NSWorkspace.shared.urlForApplication(toOpen: url) != nil
                callback(canOpen, nil)
            }

        case "getInitialURL":
            callback(LinkingModule.initialURL, nil)

        default:
            callback(nil, "LinkingModule: Unknown method '\(method)'")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
