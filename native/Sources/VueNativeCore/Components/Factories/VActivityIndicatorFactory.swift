#if canImport(UIKit)
import UIKit
import FlexLayout

/// Factory for VActivityIndicator — the loading spinner component.
/// Maps to UIActivityIndicatorView with FlexLayout enabled.
/// Starts/stops animating based on the `animating` prop.
final class VActivityIndicatorFactory: NativeComponentFactory {

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.startAnimating()
        _ = indicator.flex
        return indicator
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let indicator = view as? UIActivityIndicatorView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "animating":
            let shouldAnimate: Bool
            if let anim = value as? Bool {
                shouldAnimate = anim
            } else if let anim = value as? Int {
                shouldAnimate = anim != 0
            } else {
                shouldAnimate = true
            }
            if shouldAnimate {
                indicator.startAnimating()
            } else {
                indicator.stopAnimating()
            }

        case "color":
            if let colorStr = value as? String {
                indicator.color = UIColor.fromHex(colorStr)
            } else {
                indicator.color = .systemGray
            }

        case "size":
            if let sizeStr = value as? String {
                switch sizeStr {
                case "large":
                    indicator.style = .large
                default:
                    indicator.style = .medium
                }
                indicator.flex.markDirty()
            }

        case "hidesWhenStopped":
            if let hides = value as? Bool {
                indicator.hidesWhenStopped = hides
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        // VActivityIndicator has no events
    }
}
#endif
