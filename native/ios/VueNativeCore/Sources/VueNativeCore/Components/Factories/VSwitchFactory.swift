#if canImport(UIKit)
import UIKit
import ObjectiveC
import FlexLayout

/// Factory for VSwitch — the boolean toggle switch component.
/// Maps to UISwitch with FlexLayout enabled.
/// Supports v-model via the `value` prop and `change` event.
final class VSwitchFactory: NativeComponentFactory {

    private static var changeHandlerKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let sw = UISwitch()
        _ = sw.flex
        return sw
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let sw = view as? UISwitch else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "value":
            let newValue: Bool
            if let val = value as? Bool {
                newValue = val
            } else if let val = value as? Int {
                newValue = val != 0
            } else {
                newValue = false
            }
            if sw.isOn != newValue {
                sw.setOn(newValue, animated: true)
            }

        case "disabled":
            if let disabled = value as? Bool {
                sw.isEnabled = !disabled
            } else if let disabled = value as? Int {
                sw.isEnabled = disabled == 0
            } else {
                sw.isEnabled = true
            }

        case "onTintColor":
            if let colorStr = value as? String {
                sw.onTintColor = UIColor.fromHex(colorStr)
            } else {
                sw.onTintColor = nil
            }

        case "thumbTintColor":
            if let colorStr = value as? String {
                sw.thumbTintColor = UIColor.fromHex(colorStr)
            } else {
                sw.thumbTintColor = nil
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let sw = view as? UISwitch, event == "change" else { return }

        let proxy = SwitchActionProxy(handler: handler)
        sw.addTarget(proxy, action: #selector(SwitchActionProxy.valueChanged(_:)), for: .valueChanged)
        objc_setAssociatedObject(
            sw,
            &VSwitchFactory.changeHandlerKey,
            proxy,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    func removeEventListener(view: UIView, event: String) {
        guard let sw = view as? UISwitch, event == "change" else { return }

        if let proxy = objc_getAssociatedObject(sw, &VSwitchFactory.changeHandlerKey) as? SwitchActionProxy {
            sw.removeTarget(proxy, action: #selector(SwitchActionProxy.valueChanged(_:)), for: .valueChanged)
        }
        objc_setAssociatedObject(sw, &VSwitchFactory.changeHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - SwitchActionProxy

/// Target-action proxy that routes UISwitch.valueChanged to a closure handler.
/// Stored as an associated object on the UISwitch.
final class SwitchActionProxy: NSObject {

    let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
    }

    @objc func valueChanged(_ sender: UISwitch) {
        handler(sender.isOn)
    }
}
#endif
