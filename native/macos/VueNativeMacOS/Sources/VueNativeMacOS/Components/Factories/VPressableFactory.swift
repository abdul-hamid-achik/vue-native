import AppKit
import ObjectiveC

/// Factory for VPressable — custom mouse-tracking view for pressable interactions.
/// Maps to a PressableView (ClickableView subclass) with press, longPress,
/// pressIn (mouseDown), and pressOut (mouseUp) events.
final class VPressableFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var pressInHandlerKey: UInt8 = 0
    private static var pressOutHandlerKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let pressable = PressableView()
        pressable.ensureLayoutNode()
        return pressable
    }

    func updateProp(view: NSView, key: String, value: Any?) {
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

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let pressable = view as? PressableView else { return }

        switch event {
        case "press":
            pressable.onPress = {
                handler(nil)
            }

        case "longPress":
            pressable.onLongPress = {
                handler(nil)
            }

        case "pressIn":
            pressable.onPressIn = {
                handler(nil)
            }

        case "pressOut":
            pressable.onPressOut = {
                handler(nil)
            }

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        guard let pressable = view as? PressableView else { return }

        switch event {
        case "press":
            pressable.onPress = nil
        case "longPress":
            pressable.onLongPress = nil
        case "pressIn":
            pressable.onPressIn = nil
        case "pressOut":
            pressable.onPressOut = nil
        default:
            break
        }
    }
}

// MARK: - PressableView

/// ClickableView subclass that adds pressIn (mouseDown) and pressOut (mouseUp) callbacks.
/// Provides the full set of press interaction events for the VPressable component.
final class PressableView: ClickableView {

    /// Called immediately when the mouse button goes down.
    var onPressIn: (() -> Void)?

    /// Called when the mouse button is released (regardless of position).
    var onPressOut: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onPressIn?()
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        onPressOut?()
        super.mouseUp(with: event)
    }
}
