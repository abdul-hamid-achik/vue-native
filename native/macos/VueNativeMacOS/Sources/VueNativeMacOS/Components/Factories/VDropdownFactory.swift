import AppKit
import ObjectiveC

/// Factory for VDropdown — a dropdown selection control.
/// Maps to NSPopUpButton configured for dropdown selection.
final class VDropdownFactory: NativeComponentFactory {

    private static var changeHandlerKey: UInt8 = 0
    nonisolated(unsafe) static var optionsKey: UInt8 = 0
    nonisolated(unsafe) static var placeholderKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let popup = NSPopUpButton()
        popup.pullsDown = false
        popup.wantsLayer = true
        popup.ensureLayoutNode()
        return popup
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let popup = view as? NSPopUpButton else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "options":
            popup.removeAllItems()
            var storedOptions: [[String: Any]] = []

            // Add placeholder as first disabled item if set
            let placeholder = objc_getAssociatedObject(popup, &VDropdownFactory.placeholderKey) as? String

            if let options = value as? [[String: Any]] {
                if let placeholder = placeholder {
                    popup.addItem(withTitle: placeholder)
                    popup.item(at: 0)?.isEnabled = false
                }
                for option in options {
                    let label = option["label"] as? String ?? option["value"] as? String ?? ""
                    popup.addItem(withTitle: label)
                    storedOptions.append(option)
                }
            } else if let strings = value as? [String] {
                if let placeholder = placeholder {
                    popup.addItem(withTitle: placeholder)
                    popup.item(at: 0)?.isEnabled = false
                }
                for str in strings {
                    popup.addItem(withTitle: str)
                    storedOptions.append(["label": str, "value": str])
                }
            }
            objc_setAssociatedObject(popup, &VDropdownFactory.optionsKey, storedOptions, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        case "selectedValue":
            if let val = value as? String,
               let options = objc_getAssociatedObject(popup, &VDropdownFactory.optionsKey) as? [[String: Any]] {
                let offset = hasPlaceholder(popup) ? 1 : 0
                if let idx = options.firstIndex(where: { ($0["value"] as? String) == val }) {
                    popup.selectItem(at: idx + offset)
                }
            }

        case "placeholder":
            objc_setAssociatedObject(popup, &VDropdownFactory.placeholderKey, value as? String, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            // Rebuild items if options are already set
            if let options = objc_getAssociatedObject(popup, &VDropdownFactory.optionsKey) as? [[String: Any]], !options.isEmpty {
                updateProp(view: view, key: "options", value: options)
            }

        case "disabled":
            if let disabled = value as? Bool {
                popup.isEnabled = !disabled
            } else if let disabled = value as? Int {
                popup.isEnabled = disabled == 0
            } else {
                popup.isEnabled = true
            }

        case "tintColor":
            if let colorStr = value as? String {
                popup.contentTintColor = NSColor.fromHex(colorStr)
            } else {
                popup.contentTintColor = nil
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let popup = view as? NSPopUpButton, event == "change" else { return }

        let proxy = DropdownActionProxy(popup: popup, handler: handler)
        popup.target = proxy
        popup.action = #selector(DropdownActionProxy.selectionChanged(_:))
        objc_setAssociatedObject(
            popup,
            &VDropdownFactory.changeHandlerKey,
            proxy,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    func removeEventListener(view: NSView, event: String) {
        guard let popup = view as? NSPopUpButton, event == "change" else { return }

        popup.target = nil
        popup.action = nil
        objc_setAssociatedObject(popup, &VDropdownFactory.changeHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Private

    private func hasPlaceholder(_ popup: NSPopUpButton) -> Bool {
        return objc_getAssociatedObject(popup, &VDropdownFactory.placeholderKey) as? String != nil
    }
}

// MARK: - DropdownActionProxy

/// Target-action proxy that routes NSPopUpButton selection changes to a closure handler.
final class DropdownActionProxy: NSObject {

    private weak var popup: NSPopUpButton?
    private let handler: (Any?) -> Void

    init(popup: NSPopUpButton, handler: @escaping (Any?) -> Void) {
        self.popup = popup
        self.handler = handler
    }

    @objc func selectionChanged(_ sender: NSPopUpButton) {
        let options = objc_getAssociatedObject(sender, &VDropdownFactory.optionsKey) as? [[String: Any]] ?? []
        let hasPlaceholder = objc_getAssociatedObject(sender, &VDropdownFactory.placeholderKey) as? String != nil
        let rawIndex = sender.indexOfSelectedItem
        let offset = hasPlaceholder ? 1 : 0
        let optionIndex = rawIndex - offset

        guard optionIndex >= 0 && optionIndex < options.count else { return }

        let option = options[optionIndex]
        let label = option["label"] as? String ?? sender.titleOfSelectedItem ?? ""
        let value = option["value"] as? String ?? label

        handler([
            "value": value,
            "label": label
        ])
    }
}
