import AppKit

/// Factory for VActivityIndicator — a spinning progress indicator.
/// Maps to NSProgressIndicator with spinning style.
final class VActivityIndicatorFactory: NativeComponentFactory {

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.isIndeterminate = true
        indicator.isDisplayedWhenStopped = false
        indicator.wantsLayer = true
        indicator.ensureLayoutNode()
        indicator.startAnimation(nil)
        return indicator
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let indicator = view as? NSProgressIndicator else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "animating":
            let animating: Bool
            if let val = value as? Bool {
                animating = val
            } else if let val = value as? Int {
                animating = val != 0
            } else {
                animating = true
            }
            if animating {
                indicator.startAnimation(nil)
            } else {
                indicator.stopAnimation(nil)
            }

        case "color":
            if let colorStr = value as? String {
                indicator.appearance = nil // Reset to allow tinting
                indicator.contentFilters = [CIFilter(name: "CIFalseColor",
                    parameters: [
                        "inputColor0": CIColor(color: NSColor.fromHex(colorStr))!,
                        "inputColor1": CIColor(color: NSColor.fromHex(colorStr))!
                    ])!]
            } else {
                indicator.contentFilters = []
            }

        case "hidesWhenStopped":
            let hides: Bool
            if let val = value as? Bool {
                hides = val
            } else if let val = value as? Int {
                hides = val != 0
            } else {
                hides = true
            }
            indicator.isDisplayedWhenStopped = !hides

        case "size":
            if let sizeStr = value as? String {
                switch sizeStr {
                case "small":
                    indicator.controlSize = .small
                case "large":
                    indicator.controlSize = .large
                default:
                    indicator.controlSize = .regular
                }
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        // No events for activity indicator
    }
}
