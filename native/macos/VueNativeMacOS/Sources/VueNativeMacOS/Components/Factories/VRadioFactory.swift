import AppKit
import ObjectiveC

/// Factory for VRadio — a radio button group for mutually exclusive selection.
/// Maps to an NSStackView containing multiple NSButton radio items.
final class VRadioFactory: NativeComponentFactory {

    private static var changeHandlerKey: UInt8 = 0
    nonisolated(unsafe) static var optionsKey: UInt8 = 0
    nonisolated(unsafe) static var selectedValueKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.wantsLayer = true
        stack.ensureLayoutNode()
        return stack
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let stack = view as? NSStackView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "options":
            guard let options = value as? [[String: Any]] else { return }
            rebuildRadioButtons(in: stack, options: options)
            objc_setAssociatedObject(stack, &VRadioFactory.optionsKey, options, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        case "selectedValue":
            if let val = value as? String {
                objc_setAssociatedObject(stack, &VRadioFactory.selectedValueKey, val, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                selectValue(val, in: stack)
            }

        case "disabled":
            let disabled: Bool
            if let val = value as? Bool {
                disabled = val
            } else if let val = value as? Int {
                disabled = val != 0
            } else {
                disabled = false
            }
            for case let button as NSButton in stack.arrangedSubviews {
                button.isEnabled = !disabled
            }

        case "tintColor":
            if let colorStr = value as? String {
                let color = NSColor.fromHex(colorStr)
                for case let button as NSButton in stack.arrangedSubviews {
                    button.contentTintColor = color
                }
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard event == "change" else { return }

        let proxy = RadioGroupActionProxy(stack: view as? NSStackView, handler: handler)
        objc_setAssociatedObject(
            view,
            &VRadioFactory.changeHandlerKey,
            proxy,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        // Wire existing buttons to this proxy
        if let stack = view as? NSStackView {
            wireButtons(in: stack, to: proxy)
        }
    }

    func removeEventListener(view: NSView, event: String) {
        guard event == "change" else { return }

        if let stack = view as? NSStackView {
            for case let button as NSButton in stack.arrangedSubviews {
                button.target = nil
                button.action = nil
            }
        }
        objc_setAssociatedObject(view, &VRadioFactory.changeHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // Override insertChild/removeChild: radio group manages its own children
    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?) {
        // No-op: radio buttons are internally managed
    }

    func removeChild(_ child: NSView, from parent: NSView) {
        // No-op: radio buttons are internally managed
    }

    // MARK: - Private

    private func rebuildRadioButtons(in stack: NSStackView, options: [[String: Any]]) {
        // Remove existing buttons
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let selectedValue = objc_getAssociatedObject(stack, &VRadioFactory.selectedValueKey) as? String
        let proxy = objc_getAssociatedObject(stack, &VRadioFactory.changeHandlerKey) as? RadioGroupActionProxy

        for (index, option) in options.enumerated() {
            let label = option["label"] as? String ?? option["value"] as? String ?? ""
            let value = option["value"] as? String ?? label

            let button = NSButton()
            button.setButtonType(.radio)
            button.title = label
            button.tag = index
            button.wantsLayer = true

            if value == selectedValue {
                button.state = .on
            } else {
                button.state = .off
            }

            if let proxy = proxy {
                button.target = proxy
                button.action = #selector(RadioGroupActionProxy.radioSelected(_:))
            }

            stack.addArrangedSubview(button)
        }
    }

    private func selectValue(_ value: String, in stack: NSStackView) {
        let options = objc_getAssociatedObject(stack, &VRadioFactory.optionsKey) as? [[String: Any]] ?? []
        for (index, option) in options.enumerated() {
            let optionValue = option["value"] as? String ?? option["label"] as? String ?? ""
            if let button = stack.arrangedSubviews[safe: index] as? NSButton {
                button.state = optionValue == value ? .on : .off
            }
        }
    }

    private func wireButtons(in stack: NSStackView, to proxy: RadioGroupActionProxy) {
        for case let button as NSButton in stack.arrangedSubviews {
            button.target = proxy
            button.action = #selector(RadioGroupActionProxy.radioSelected(_:))
        }
    }
}

// MARK: - RadioGroupActionProxy

/// Target-action proxy that routes radio button selections to a closure handler.
final class RadioGroupActionProxy: NSObject {

    private weak var stack: NSStackView?
    private let handler: (Any?) -> Void

    init(stack: NSStackView?, handler: @escaping (Any?) -> Void) {
        self.stack = stack
        self.handler = handler
    }

    @objc func radioSelected(_ sender: NSButton) {
        guard let stack = stack else { return }

        // Deselect all other buttons (enforce mutual exclusivity)
        for case let button as NSButton in stack.arrangedSubviews where button !== sender {
            button.state = .off
        }
        sender.state = .on

        let options = objc_getAssociatedObject(stack, &VRadioFactory.optionsKey) as? [[String: Any]] ?? []
        let index = sender.tag
        let option = options[safe: index]
        let value = option?["value"] as? String ?? sender.title

        // Update stored selected value
        objc_setAssociatedObject(stack, &VRadioFactory.selectedValueKey, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        handler(["value": value])
    }
}
