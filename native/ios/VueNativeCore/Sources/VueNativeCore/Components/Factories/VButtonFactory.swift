#if canImport(UIKit)
import UIKit
import ObjectiveC
import FlexLayout

/// Factory for VButton — the touchable/pressable component.
/// Maps to a TouchableView (custom UIView subclass) with FlexLayout enabled.
/// Supports press and long press events with configurable active opacity.
final class VButtonFactory: NativeComponentFactory {

    // MARK: - Associated object keys for event handlers

    private static var pressHandlerKey: UInt8 = 0
    private static var longPressHandlerKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let touchable = TouchableView()
        // Accessing .flex automatically enables Yoga layout
        _ = touchable.flex
        return touchable
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let touchable = view as? TouchableView else {
            // Fallback to StyleEngine for non-TouchableView
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "disabled":
            if let disabled = value as? Bool {
                touchable.isDisabled = disabled
            } else if let disabled = value as? Int {
                touchable.isDisabled = disabled != 0
            } else {
                touchable.isDisabled = false
            }

        case "activeOpacity":
            if let opacity = value as? Double {
                touchable.activeOpacity = CGFloat(opacity)
            } else if let opacity = value as? Int {
                touchable.activeOpacity = CGFloat(opacity)
            } else {
                touchable.activeOpacity = 0.7
            }

        default:
            // Delegate to StyleEngine for layout/visual styling
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let touchable = view as? TouchableView else { return }

        switch event {
        case "press":
            // Capture handler weakly via the closure to avoid retain cycles.
            // TouchableView.onPress holds the only strong reference to the closure.
            touchable.onPress = {
                handler(nil)
            }

        case "longpress":
            touchable.onLongPress = {
                handler(nil)
            }

        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        guard let touchable = view as? TouchableView else { return }

        switch event {
        case "press":
            touchable.onPress = nil

        case "longpress":
            touchable.onLongPress = nil

        default:
            break
        }
    }
}
#endif
