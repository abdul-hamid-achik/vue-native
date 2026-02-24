#if canImport(UIKit)
import UIKit
import FlexLayout
import ObjectiveC

private var dropdownOnChangeKey: UInt8 = 0
private var dropdownOptionsKey: UInt8 = 1

/// Factory for VDropdown — a dropdown selection component.
/// Uses UIButton with UIMenu (iOS 14+) for a native dropdown experience.
final class VDropdownFactory: NativeComponentFactory {

    func createView() -> UIView {
        let button: UIButton
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.baseForegroundColor = .label
            button = UIButton(configuration: config)
        } else {
            button = UIButton(type: .system)
            button.setTitleColor(.label, for: .normal)
        }
        button.contentHorizontalAlignment = .leading
        _ = button.flex
        return button
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let button = view as? UIButton else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "options":
            guard let items = value as? [[String: Any]] else { return }
            let options = items.compactMap { dict -> (label: String, value: String)? in
                guard let label = dict["label"] as? String,
                      let val = dict["value"] as? String else { return nil }
                return (label, val)
            }
            objc_setAssociatedObject(view, &dropdownOptionsKey, options, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            rebuildMenu(button: button, view: view)

        case "selectedValue":
            let selected = value as? String
            // Find matching label and update button title
            let options = objc_getAssociatedObject(view, &dropdownOptionsKey) as? [(label: String, value: String)] ?? []
            if let selected = selected, let match = options.first(where: { $0.value == selected }) {
                button.setTitle(match.label, for: .normal)
            }
            rebuildMenu(button: button, view: view)

        case "placeholder":
            // Only set if no selectedValue
            let options = objc_getAssociatedObject(view, &dropdownOptionsKey) as? [(label: String, value: String)] ?? []
            let currentTitle = button.title(for: .normal)
            let isPlaceholder = currentTitle == nil || !options.contains(where: { $0.label == currentTitle })
            if isPlaceholder {
                button.setTitle(value as? String ?? "Select...", for: .normal)
                button.setTitleColor(.placeholderText, for: .normal)
            }

        case "disabled":
            let disabled = (value as? Bool) ?? false
            button.isEnabled = !disabled

        case "tintColor":
            if let colorStr = value as? String {
                button.tintColor = UIColor.fromHex(colorStr)
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard event == "change" else { return }
        objc_setAssociatedObject(view, &dropdownOnChangeKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if let button = view as? UIButton {
            rebuildMenu(button: button, view: view)
        }
    }

    func removeEventListener(view: UIView, event: String) {
        if event == "change" {
            objc_setAssociatedObject(view, &dropdownOnChangeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Menu building

    private func rebuildMenu(button: UIButton, view: UIView) {
        guard #available(iOS 14.0, *) else { return }

        let options = objc_getAssociatedObject(view, &dropdownOptionsKey) as? [(label: String, value: String)] ?? []
        let handler = objc_getAssociatedObject(view, &dropdownOnChangeKey) as? ((Any?) -> Void)

        let actions: [UIMenuElement] = options.map { option in
            UIAction(title: option.label) { _ in
                button.setTitle(option.label, for: .normal)
                button.setTitleColor(.label, for: .normal)
                handler?(["value": option.value, "label": option.label])
            }
        }

        button.menu = UIMenu(children: actions)
        button.showsMenuAsPrimaryAction = true
    }
}
#endif
