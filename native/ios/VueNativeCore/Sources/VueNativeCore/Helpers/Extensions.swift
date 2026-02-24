#if canImport(UIKit)
import UIKit

// MARK: - Safe array subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Key window helper (avoids deprecated UIWindowScene.windows)

extension UIApplication {
    /// Returns the key window from the first foreground-active window scene.
    var vn_keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .compactMap { $0.keyWindow }
            .first
    }

    /// Returns the topmost presented view controller.
    var vn_topViewController: UIViewController? {
        guard let root = vn_keyWindow?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
#endif
