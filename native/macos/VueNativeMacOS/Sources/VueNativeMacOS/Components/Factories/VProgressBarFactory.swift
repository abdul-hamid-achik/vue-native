import AppKit

/// Factory for VProgressBar — a determinate/indeterminate progress indicator.
/// Maps to NSProgressIndicator with bar style.
final class VProgressBarFactory: NativeComponentFactory {

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let indicator = NSProgressIndicator()
        indicator.style = .bar
        indicator.isIndeterminate = false
        indicator.minValue = 0
        indicator.maxValue = 1
        indicator.doubleValue = 0
        indicator.wantsLayer = true
        indicator.ensureLayoutNode()
        return indicator
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let indicator = view as? NSProgressIndicator else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "progress", "value":
            if let val = value as? Double {
                indicator.isIndeterminate = false
                indicator.doubleValue = val
            } else if let val = value as? Int {
                indicator.isIndeterminate = false
                indicator.doubleValue = Double(val)
            }

        case "progressTintColor":
            if let colorStr = value as? String {
                indicator.wantsLayer = true
                indicator.layer?.backgroundColor = NSColor.fromHex(colorStr).cgColor
            }

        case "trackTintColor":
            // No direct API; would require custom drawing
            break

        case "animated", "indeterminate":
            let indeterminate: Bool
            if let val = value as? Bool {
                indeterminate = val
            } else if let val = value as? Int {
                indeterminate = val != 0
            } else {
                indeterminate = false
            }
            indicator.isIndeterminate = indeterminate
            if indeterminate {
                indicator.startAnimation(nil)
            } else {
                indicator.stopAnimation(nil)
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        // No events for progress bar
    }
}
