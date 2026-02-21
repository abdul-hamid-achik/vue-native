#if canImport(UIKit)
import UIKit

/// Native module providing clipboard access via UIPasteboard.
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
                UIPasteboard.general.string = text
                callback(nil, nil)

            case "paste":
                let text = UIPasteboard.general.string
                callback(text, nil)

            default:
                callback(nil, "ClipboardModule: Unknown method '\(method)'")
            }
        }
    }
}
#endif
