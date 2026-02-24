#if canImport(UIKit)
import UIKit
import FlexLayout
import ObjectiveC

private var checkboxOnChangeKey: UInt8 = 0
private var checkboxValueKey: UInt8 = 1

/// Factory for VCheckbox — a boolean checkbox with optional label.
/// Uses a horizontal UIStackView containing a custom checkbox image and a UILabel.
final class VCheckboxFactory: NativeComponentFactory {

    func createView() -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 8
        container.alignment = .center
        _ = container.flex

        let checkbox = UIImageView()
        checkbox.contentMode = .scaleAspectFit
        checkbox.isUserInteractionEnabled = true
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            checkbox.widthAnchor.constraint(equalToConstant: 24),
            checkbox.heightAnchor.constraint(equalToConstant: 24),
        ])
        checkbox.tag = 1001

        let label = UILabel()
        label.tag = 1002
        label.font = UIFont.systemFont(ofSize: 16)

        container.addArrangedSubview(checkbox)
        container.addArrangedSubview(label)

        updateCheckboxImage(checkbox, checked: false, tintColor: nil)

        return container
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let stack = view as? UIStackView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }
        let checkbox = stack.viewWithTag(1001) as? UIImageView
        let label = stack.viewWithTag(1002) as? UILabel

        switch key {
        case "value":
            let checked = (value as? Bool) ?? ((value as? Int) != 0 && value != nil)
            objc_setAssociatedObject(view, &checkboxValueKey, checked, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if let cb = checkbox {
                let tintColor = cb.tintColor
                updateCheckboxImage(cb, checked: checked, tintColor: tintColor)
            }
        case "label":
            label?.text = value as? String
            label?.isHidden = (value as? String)?.isEmpty ?? true
        case "disabled":
            let disabled = (value as? Bool) ?? false
            stack.isUserInteractionEnabled = !disabled
            stack.alpha = disabled ? 0.4 : 1.0
        case "checkColor", "tintColor":
            if let colorStr = value as? String, let cb = checkbox {
                let color = UIColor.fromHex(colorStr)
                cb.tintColor = color
                let checked = (objc_getAssociatedObject(view, &checkboxValueKey) as? Bool) ?? false
                updateCheckboxImage(cb, checked: checked, tintColor: color)
            }
        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard event == "change" else { return }
        objc_setAssociatedObject(view, &checkboxOnChangeKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)
        view.isUserInteractionEnabled = true
    }

    func removeEventListener(view: UIView, event: String) {
        if event == "change" {
            objc_setAssociatedObject(view, &checkboxOnChangeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            // Remove tap gesture recognizers to prevent accumulation on re-add
            view.gestureRecognizers?.forEach { recognizer in
                if recognizer is UITapGestureRecognizer {
                    view.removeGestureRecognizer(recognizer)
                }
            }
        }
    }

    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        guard let view = sender.view else { return }
        let currentValue = (objc_getAssociatedObject(view, &checkboxValueKey) as? Bool) ?? false
        let newValue = !currentValue
        if let handler = objc_getAssociatedObject(view, &checkboxOnChangeKey) as? ((Any?) -> Void) {
            handler(["value": newValue])
        }
    }

    private func updateCheckboxImage(_ imageView: UIImageView, checked: Bool, tintColor: UIColor?) {
        let symbolName = checked ? "checkmark.square.fill" : "square"
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let image = UIImage(systemName: symbolName, withConfiguration: config)
        imageView.image = image
        imageView.tintColor = tintColor ?? .systemBlue
    }
}
#endif
