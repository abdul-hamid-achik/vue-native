import AppKit
import ObjectiveC

/// Factory for VPicker — a popup button for selecting from a list of items.
/// Maps to NSPopUpButton.
final class VPickerFactory: NativeComponentFactory {

    private static var changeHandlerKey: UInt8 = 0
    nonisolated(unsafe) static var itemsKey: UInt8 = 0

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
        case "items":
            popup.removeAllItems()
            var storedItems: [[String: Any]] = []

            if let strings = value as? [String] {
                popup.addItems(withTitles: strings)
                storedItems = strings.map { ["label": $0, "value": $0] }
            } else if let items = value as? [[String: Any]] {
                for item in items {
                    let label = item["label"] as? String ?? item["value"] as? String ?? ""
                    popup.addItem(withTitle: label)
                    storedItems.append(item)
                }
            }
            objc_setAssociatedObject(popup, &VPickerFactory.itemsKey, storedItems, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        case "selectedIndex":
            if let idx = value as? Int {
                if idx >= 0 && idx < popup.numberOfItems {
                    popup.selectItem(at: idx)
                }
            } else if let idx = value as? Double {
                let i = Int(idx)
                if i >= 0 && i < popup.numberOfItems {
                    popup.selectItem(at: i)
                }
            }

        case "selectedValue":
            if let val = value as? String,
               let items = objc_getAssociatedObject(popup, &VPickerFactory.itemsKey) as? [[String: Any]] {
                if let idx = items.firstIndex(where: { ($0["value"] as? String) == val }) {
                    popup.selectItem(at: idx)
                }
            }

        case "enabled":
            if let enabled = value as? Bool {
                popup.isEnabled = enabled
            } else {
                popup.isEnabled = true
            }

        case "disabled":
            if let disabled = value as? Bool {
                popup.isEnabled = !disabled
            } else if let disabled = value as? Int {
                popup.isEnabled = disabled == 0
            } else {
                popup.isEnabled = true
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let popup = view as? NSPopUpButton, event == "change" else { return }

        let proxy = PickerActionProxy(popup: popup, handler: handler)
        popup.target = proxy
        popup.action = #selector(PickerActionProxy.selectionChanged(_:))
        objc_setAssociatedObject(
            popup,
            &VPickerFactory.changeHandlerKey,
            proxy,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    func removeEventListener(view: NSView, event: String) {
        guard let popup = view as? NSPopUpButton, event == "change" else { return }

        popup.target = nil
        popup.action = nil
        objc_setAssociatedObject(popup, &VPickerFactory.changeHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - PickerActionProxy

/// Target-action proxy that routes NSPopUpButton selection changes to a closure handler.
final class PickerActionProxy: NSObject {

    private weak var popup: NSPopUpButton?
    private let handler: (Any?) -> Void

    init(popup: NSPopUpButton, handler: @escaping (Any?) -> Void) {
        self.popup = popup
        self.handler = handler
    }

    @objc func selectionChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        let items = objc_getAssociatedObject(sender, &VPickerFactory.itemsKey) as? [[String: Any]]
        let item = items?[safe: index]
        let label = sender.titleOfSelectedItem ?? ""
        let value = item?["value"] as? String ?? label

        handler([
            "selectedIndex": index,
            "value": value,
            "label": label
        ])
    }
}
