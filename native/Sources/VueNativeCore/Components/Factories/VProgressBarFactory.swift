#if canImport(UIKit)
import UIKit
import FlexLayout

/// Factory for VProgressBar — maps to UIProgressView.
final class VProgressBarFactory: NativeComponentFactory {

    func createView() -> UIView {
        let bar = UIProgressView(progressViewStyle: .default)
        bar.progress = 0
        _ = bar.flex
        return bar
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let bar = view as? UIProgressView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }
        switch key {
        case "progress":
            let p = (value as? Double) ?? (value as? NSNumber)?.doubleValue ?? 0
            bar.setProgress(Float(max(0, min(1, p))), animated: false)
        case "progressTintColor":
            if let str = value as? String { bar.progressTintColor = UIColor.fromHex(str) }
        case "trackTintColor":
            if let str = value as? String { bar.trackTintColor = UIColor.fromHex(str) }
        case "animated":
            // stored for use in future progress updates — no-op here
            break
        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {}
    func removeEventListener(view: UIView, event: String) {}
}
#endif
