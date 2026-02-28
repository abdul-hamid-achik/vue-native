import AppKit
import VueNativeShared

/// Native module providing clipboard access via NSPasteboard.
///
/// Methods:
///   - copy(text: String)
///   - paste() -> String?
final class ClipboardModule: NativeModule {
    let moduleName = "Clipboard"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            switch method {
            case "copy":
                guard let text = args.first as? String else {
                    callback(nil, "copy: missing text")
                    return
                }
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                callback(nil, nil)

            case "paste":
                let text = NSPasteboard.general.string(forType: .string)
                callback(text, nil)

            default:
                callback(nil, "ClipboardModule: Unknown method '\(method)'")
            }
        }
    }
}
