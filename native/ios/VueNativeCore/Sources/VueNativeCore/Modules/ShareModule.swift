#if canImport(UIKit)
import UIKit

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
                let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
                if let rootVC = UIApplication.shared.vn_keyWindow?.rootViewController {
                    // iPad popover support
                    if let popover = vc.popoverPresentationController {
                        popover.sourceView = rootVC.view
                        popover.sourceRect = CGRect(
                            x: rootVC.view.bounds.midX,
                            y: rootVC.view.bounds.midY,
                            width: 0,
                            height: 0
                        )
                        popover.permittedArrowDirections = []
                    }
                    rootVC.present(vc, animated: true)
                    vc.completionWithItemsHandler = { _, completed, _, _ in
                        callback(["shared": completed], nil)
                    }
                } else {
                    callback(nil, "No root view controller")
                }
            }
        default:
            callback(nil, "Unknown method: \(method)")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
#endif
