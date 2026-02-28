import AppKit
import ObjectiveC

/// Factory for VButton — the clickable/pressable component.
/// Maps to a ClickableView (custom NSView subclass) with a LayoutNode.
/// Supports press and long press events with configurable active opacity.
final class VButtonFactory: NativeComponentFactory {

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let clickable = ClickableView()
        // Ensure layout node is attached
        clickable.ensureLayoutNode()
        return clickable
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let clickable = view as? ClickableView else {
            // Fallback to StyleEngine for non-ClickableView
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "disabled":
            if let disabled = value as? Bool {
                clickable.isDisabled = disabled
            } else if let disabled = value as? Int {
                clickable.isDisabled = disabled != 0
            } else {
                clickable.isDisabled = false
            }

        case "activeOpacity":
            if let opacity = value as? Double {
                clickable.activeOpacity = CGFloat(opacity)
            } else if let opacity = value as? Int {
                clickable.activeOpacity = CGFloat(opacity)
            } else {
                clickable.activeOpacity = 0.7
            }

        default:
            // Delegate to StyleEngine for layout/visual styling
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let clickable = view as? ClickableView else { return }

        switch event {
        case "press":
            clickable.onPress = {
                handler(nil)
            }

        case "longpress":
            clickable.onLongPress = {
                handler(nil)
            }

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        guard let clickable = view as? ClickableView else { return }

        switch event {
        case "press":
            clickable.onPress = nil

        case "longpress":
            clickable.onLongPress = nil

        default:
            break
        }
    }
}
