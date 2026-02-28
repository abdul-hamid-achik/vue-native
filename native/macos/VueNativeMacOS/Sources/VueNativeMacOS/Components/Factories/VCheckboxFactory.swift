import AppKit
import ObjectiveC

/// Factory for VCheckbox — a checkbox toggle control.
/// Maps to NSButton with .checkbox style.
final class VCheckboxFactory: NativeComponentFactory {

    private static var changeHandlerKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let button = NSButton()
        button.setButtonType(.switch) // .switch is the checkbox type in AppKit
        button.title = ""
        button.state = .off
        button.wantsLayer = true
        button.ensureLayoutNode()
        return button
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let button = view as? NSButton else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "checked", "value":
            let checked: Bool
            if let val = value as? Bool {
                checked = val
            } else if let val = value as? Int {
                checked = val != 0
            } else {
                checked = false
            }
            let newState: NSControl.StateValue = checked ? .on : .off
            if button.state != newState {
                button.state = newState
            }

        case "label", "title":
            if let text = value as? String {
                button.title = text
            } else {
                button.title = ""
            }

        case "disabled":
            if let disabled = value as? Bool {
                button.isEnabled = !disabled
            } else if let disabled = value as? Int {
                button.isEnabled = disabled == 0
            } else {
                button.isEnabled = true
            }

        case "tintColor":
            if let colorStr = value as? String {
                button.contentTintColor = NSColor.fromHex(colorStr)
            } else {
                button.contentTintColor = nil
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let button = view as? NSButton, event == "change" else { return }

        let proxy = CheckboxActionProxy(handler: handler)
        button.target = proxy
        button.action = #selector(CheckboxActionProxy.toggled(_:))
        objc_setAssociatedObject(
            button,
            &VCheckboxFactory.changeHandlerKey,
            proxy,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    func removeEventListener(view: NSView, event: String) {
        guard let button = view as? NSButton, event == "change" else { return }

        button.target = nil
        button.action = nil
        objc_setAssociatedObject(button, &VCheckboxFactory.changeHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - CheckboxActionProxy

/// Target-action proxy that routes NSButton checkbox state changes to a closure handler.
final class CheckboxActionProxy: NSObject {

    let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
    }

    @objc func toggled(_ sender: NSButton) {
        handler(["checked": sender.state == .on])
    }
}
