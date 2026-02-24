#if canImport(UIKit)
import UIKit
import FlexLayout
import ObjectiveC

private var radioOnChangeKey: UInt8 = 0
private var radioOptionsKey: UInt8 = 1
private var radioSelectedKey: UInt8 = 2

/// Factory for VRadio — a radio button group.
/// Uses a vertical UIStackView with rows of custom radio circles and labels.
final class VRadioFactory: NativeComponentFactory {

    func createView() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        _ = stack.flex
        return stack
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let stack = view as? UIStackView else {
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
            objc_setAssociatedObject(view, &radioOptionsKey, options.map { $0.value }, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            // Rebuild radio buttons
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for (index, option) in options.enumerated() {
                let row = createRadioRow(label: option.label, index: index, in: view)
                stack.addArrangedSubview(row)
            }

            // Re-apply selection
            if let selected = objc_getAssociatedObject(view, &radioSelectedKey) as? String {
                applySelection(stack, selectedValue: selected)
            }

        case "selectedValue":
            let selected = value as? String ?? ""
            objc_setAssociatedObject(view, &radioSelectedKey, selected, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            applySelection(stack, selectedValue: selected)

        case "disabled":
            let disabled = (value as? Bool) ?? false
            stack.isUserInteractionEnabled = !disabled
            stack.alpha = disabled ? 0.4 : 1.0

        case "tintColor":
            if let colorStr = value as? String {
                let color = UIColor.fromHex(colorStr)
                for subview in stack.arrangedSubviews {
                    if let circle = subview.viewWithTag(2001) as? UIImageView {
                        circle.tintColor = color
                    }
                }
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard event == "change" else { return }
        objc_setAssociatedObject(view, &radioOnChangeKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func removeEventListener(view: UIView, event: String) {
        if event == "change" {
            objc_setAssociatedObject(view, &radioOnChangeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Helpers

    private func createRadioRow(label: String, index: Int, in container: UIView) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center

        let circle = UIImageView()
        circle.contentMode = .scaleAspectFit
        circle.tag = 2001
        circle.tintColor = .systemBlue
        circle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 22),
            circle.heightAnchor.constraint(equalToConstant: 22),
        ])
        updateRadioImage(circle, selected: false)

        let textLabel = UILabel()
        textLabel.text = label
        textLabel.font = UIFont.systemFont(ofSize: 16)
        textLabel.tag = 2002

        row.addArrangedSubview(circle)
        row.addArrangedSubview(textLabel)

        row.tag = 3000 + index
        row.isUserInteractionEnabled = true
        let tap = RadioTapGesture(target: self, action: #selector(handleRadioTap(_:)))
        tap.radioIndex = index
        tap.containerView = container
        row.addGestureRecognizer(tap)

        return row
    }

    @objc private func handleRadioTap(_ sender: RadioTapGesture) {
        guard let container = sender.containerView else { return }
        let values = objc_getAssociatedObject(container, &radioOptionsKey) as? [String] ?? []
        guard sender.radioIndex < values.count else { return }
        let value = values[sender.radioIndex]

        if let handler = objc_getAssociatedObject(container, &radioOnChangeKey) as? ((Any?) -> Void) {
            handler(["value": value])
        }
    }

    private func applySelection(_ stack: UIStackView, selectedValue: String) {
        let values = objc_getAssociatedObject(stack, &radioOptionsKey) as? [String] ?? []
        for (index, subview) in stack.arrangedSubviews.enumerated() {
            if let circle = subview.viewWithTag(2001) as? UIImageView {
                let isSelected = index < values.count && values[index] == selectedValue
                updateRadioImage(circle, selected: isSelected)
            }
        }
    }

    private func updateRadioImage(_ imageView: UIImageView, selected: Bool) {
        let symbolName = selected ? "circle.inset.filled" : "circle"
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        imageView.image = UIImage(systemName: symbolName, withConfiguration: config)
    }
}

/// Custom UITapGestureRecognizer that carries the radio index and parent view.
private final class RadioTapGesture: UITapGestureRecognizer {
    var radioIndex: Int = 0
    weak var containerView: UIView?
}
#endif
