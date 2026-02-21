#if canImport(UIKit)
import UIKit

/// Factory for VStatusBar — a zero-size, hidden placeholder view that controls
/// the system status bar appearance by posting notifications to the root
/// view controller, which must observe them to update its `preferredStatusBarStyle`
/// and `prefersStatusBarHidden` overrides.
@MainActor
final class VStatusBarFactory: NativeComponentFactory {

    func createView() -> UIView {
        let v = UIView()
        v.isHidden = true
        return v
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        switch key {
        case "barStyle":
            guard let style = value as? String else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("VueNativeStatusBarStyleChange"),
                    object: nil,
                    userInfo: ["style": style]
                )
            }
        case "hidden":
            let hidden = (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Notification.Name("VueNativeStatusBarHiddenChange"),
                    object: nil,
                    userInfo: ["hidden": hidden]
                )
            }
        default:
            break
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        // VStatusBar emits no events
    }

    func removeEventListener(view: UIView, event: String) {
        // VStatusBar emits no events
    }
}
#endif
