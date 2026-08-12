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
    /// Returns the key window from the first foreground-active window scene,
    /// falling back to the first key window from any connected scene (e.g.
    /// during scene transitions where none is yet `.foregroundActive`).
    var vn_keyWindow: UIWindow? {
        let candidates = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .map { (activationState: $0.activationState, keyWindow: $0.keyWindow) }
        return UIApplication.vn_selectKeyWindow(from: candidates)
    }

    /// Pure selection logic behind ``vn_keyWindow``, factored out so it can be
    /// unit tested without real `UIWindowScene` instances (a scene's
    /// `activationState` can't be set from test code). Prefers the key window
    /// of the first foreground-active scene; falls back to the first key
    /// window from any scene so a window is still returned during scene
    /// transitions where none is yet `.foregroundActive`.
    static func vn_selectKeyWindow(
        from scenes: [(activationState: UIScene.ActivationState, keyWindow: UIWindow?)]
    ) -> UIWindow? {
        if let activeWindow = scenes.first(where: { $0.activationState == .foregroundActive })?.keyWindow {
            return activeWindow
        }
        return scenes.compactMap { $0.keyWindow }.first
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
