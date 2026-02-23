#if canImport(UIKit)
import UIKit

final class LinkingModule: NativeModule {
    var moduleName: String { "Linking" }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "openURL":
            guard let urlString = args.first as? String,
                  let url = URL(string: urlString) else {
                callback(nil, "Invalid URL")
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:]) { success in
                    callback(success, success ? nil : "Failed to open URL")
                }
            }
        case "canOpenURL":
            guard let urlString = args.first as? String,
                  let url = URL(string: urlString) else {
                callback(false, nil)
                return
            }
            DispatchQueue.main.async {
                callback(UIApplication.shared.canOpenURL(url), nil)
            }
        default:
            callback(nil, "Unknown method: \(method)")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
#endif
