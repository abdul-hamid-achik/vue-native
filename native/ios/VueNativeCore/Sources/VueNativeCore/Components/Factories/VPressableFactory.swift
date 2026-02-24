#if canImport(UIKit)
import UIKit
import ObjectiveC
import FlexLayout

/// Factory for VPressable — a generic pressable container component.
///
/// Like VButton but without built-in text/label support. Provides press,
/// long press, pressIn, and pressOut events. Uses PressableView, a subclass
/// of TouchableView that adds pressIn/pressOut callbacks.
final class VPressableFactory: NativeComponentFactory {

    // MARK: - Associated object keys for event handlers

    private static var pressHandlerKey: UInt8 = 0
    private static var longPressHandlerKey: UInt8 = 1
    private static var pressInHandlerKey: UInt8 = 2
    private static var pressOutHandlerKey: UInt8 = 3

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let pressable = PressableView()
        // Accessing .flex automatically enables Yoga layout
        _ = pressable.flex
        return pressable
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let pressable = view as? PressableView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "disabled":
            if let disabled = value as? Bool {
                pressable.isDisabled = disabled
            } else if let disabled = value as? Int {
                pressable.isDisabled = disabled != 0
            } else {
                pressable.isDisabled = false
            }

        case "activeOpacity":
            if let opacity = value as? Double {
                pressable.activeOpacity = CGFloat(opacity)
            } else if let opacity = value as? Int {
                pressable.activeOpacity = CGFloat(opacity)
            } else {
                pressable.activeOpacity = 0.7
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let pressable = view as? PressableView else { return }

        switch event {
        case "press":
            pressable.onPress = {
                handler(nil)
            }
            objc_setAssociatedObject(
                view,
                &VPressableFactory.pressHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "longpress":
            pressable.onLongPress = {
                handler(nil)
            }
            objc_setAssociatedObject(
                view,
                &VPressableFactory.longPressHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "pressIn", "pressin":
            pressable.onPressIn = {
                handler(nil)
            }
            objc_setAssociatedObject(
                view,
                &VPressableFactory.pressInHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "pressOut", "pressout":
            pressable.onPressOut = {
                handler(nil)
            }
            objc_setAssociatedObject(
                view,
                &VPressableFactory.pressOutHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        guard let pressable = view as? PressableView else { return }

        switch event {
        case "press":
            pressable.onPress = nil
            objc_setAssociatedObject(view, &VPressableFactory.pressHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        case "longpress":
            pressable.onLongPress = nil
            objc_setAssociatedObject(view, &VPressableFactory.longPressHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        case "pressIn", "pressin":
            pressable.onPressIn = nil
            objc_setAssociatedObject(view, &VPressableFactory.pressInHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        case "pressOut", "pressout":
            pressable.onPressOut = nil
            objc_setAssociatedObject(view, &VPressableFactory.pressOutHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        default:
            break
        }
    }
}

// MARK: - PressableView

/// Extension of TouchableView that adds pressIn and pressOut callbacks.
/// Fires pressIn when a touch begins and pressOut when the touch ends or is cancelled.
final class PressableView: TouchableView {

    /// Called when a touch begins inside the view bounds.
    var onPressIn: (() -> Void)?

    /// Called when a touch ends or is cancelled.
    var onPressOut: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard !isDisabled else { return }
        onPressIn?()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard !isDisabled else { return }
        onPressOut?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard !isDisabled else { return }
        onPressOut?()
    }
}
#endif
