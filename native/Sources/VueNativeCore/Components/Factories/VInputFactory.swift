#if canImport(UIKit)
import UIKit
import ObjectiveC
import FlexLayout

/// Factory for VInput — the text input component.
/// Maps to a UITextField with FlexLayout enabled.
/// Supports v-model via text prop and changetext event.
final class VInputFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var delegateKey: UInt8 = 0
    private static var changeTextHandlerKey: UInt8 = 0
    private static var focusHandlerKey: UInt8 = 0
    private static var blurHandlerKey: UInt8 = 0
    private static var submitHandlerKey: UInt8 = 0

    // MARK: - Keyboard type mapping

    static let keyboardTypeMap: [String: UIKeyboardType] = [
        "default": .default,
        "numeric": .numberPad,
        "number-pad": .numberPad,
        "decimal-pad": .decimalPad,
        "email": .emailAddress,
        "email-address": .emailAddress,
        "phone": .phonePad,
        "phone-pad": .phonePad,
        "url": .URL,
        "web-search": .webSearch,
        "ascii": .asciiCapable,
    ]

    // MARK: - Return key mapping

    static let returnKeyMap: [String: UIReturnKeyType] = [
        "default": .default,
        "done": .done,
        "go": .go,
        "next": .next,
        "search": .search,
        "send": .send,
        "join": .join,
        "route": .route,
    ]

    // MARK: - Auto-capitalize mapping

    static let autoCapitalizeMap: [String: UITextAutocapitalizationType] = [
        "none": .none,
        "words": .words,
        "sentences": .sentences,
        "characters": .allCharacters,
    ]

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let textField = UITextField()
        textField.borderStyle = .none
        // Accessing .flex automatically enables Yoga layout.
        // Set a sensible default height so the text field is not collapsed.
        textField.flex.height(44)
        return textField
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let textField = view as? UITextField else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "text", "value":
            if let text = value as? String {
                // Only update if different to avoid cursor jump
                if textField.text != text {
                    textField.text = text
                }
            } else {
                textField.text = nil
            }

        case "placeholder":
            if let placeholder = value as? String {
                textField.placeholder = placeholder
            } else {
                textField.placeholder = nil
            }

        case "placeholderColor", "placeholderTextColor":
            if let colorStr = value as? String, let placeholder = textField.placeholder {
                textField.attributedPlaceholder = NSAttributedString(
                    string: placeholder,
                    attributes: [.foregroundColor: UIColor.fromHex(colorStr)]
                )
            }

        case "secureTextEntry":
            if let secure = value as? Bool {
                textField.isSecureTextEntry = secure
            } else if let secure = value as? Int {
                textField.isSecureTextEntry = secure != 0
            } else {
                textField.isSecureTextEntry = false
            }

        case "keyboardType":
            if let typeStr = value as? String {
                textField.keyboardType = VInputFactory.keyboardTypeMap[typeStr] ?? .default
            } else {
                textField.keyboardType = .default
            }

        case "returnKeyType":
            if let typeStr = value as? String {
                textField.returnKeyType = VInputFactory.returnKeyMap[typeStr] ?? .default
            } else {
                textField.returnKeyType = .default
            }

        case "autoCapitalize", "autocapitalize":
            if let capStr = value as? String {
                textField.autocapitalizationType = VInputFactory.autoCapitalizeMap[capStr] ?? .sentences
            } else {
                textField.autocapitalizationType = .sentences
            }

        case "autoCorrect", "autocorrect":
            if let correct = value as? Bool {
                textField.autocorrectionType = correct ? .yes : .no
            } else {
                textField.autocorrectionType = .default
            }

        case "editable":
            if let editable = value as? Bool {
                textField.isEnabled = editable
            } else {
                textField.isEnabled = true
            }

        case "maxLength":
            // Store max length for use in delegate
            if let maxLen = value as? Int {
                storeMaxLength(maxLen, on: textField)
            } else if let maxLen = value as? Double {
                storeMaxLength(Int(maxLen), on: textField)
            }

        case "color":
            if let colorStr = value as? String {
                textField.textColor = UIColor.fromHex(colorStr)
            } else {
                textField.textColor = .label
            }

        case "fontSize":
            if let size = value as? Double {
                textField.font = UIFont.systemFont(ofSize: CGFloat(size))
            } else if let size = value as? Int {
                textField.font = UIFont.systemFont(ofSize: CGFloat(size))
            }

        case "textAlign":
            if let alignStr = value as? String {
                switch alignStr {
                case "left": textField.textAlignment = .left
                case "center": textField.textAlignment = .center
                case "right": textField.textAlignment = .right
                default: textField.textAlignment = .natural
                }
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let textField = view as? UITextField else { return }

        // Ensure we have a delegate proxy set up
        let delegate = ensureDelegate(for: textField)

        switch event {
        case "changetext":
            delegate.onChangeText = handler
            // Add editingChanged target
            textField.addTarget(
                delegate,
                action: #selector(InputDelegateProxy.textFieldEditingChanged(_:)),
                for: .editingChanged
            )
            objc_setAssociatedObject(
                view,
                &VInputFactory.changeTextHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "focus":
            delegate.onFocus = handler
            textField.addTarget(
                delegate,
                action: #selector(InputDelegateProxy.textFieldDidBeginEditing(_:)),
                for: .editingDidBegin
            )
            objc_setAssociatedObject(
                view,
                &VInputFactory.focusHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "blur":
            delegate.onBlur = handler
            textField.addTarget(
                delegate,
                action: #selector(InputDelegateProxy.textFieldDidEndEditing(_:)),
                for: .editingDidEnd
            )
            objc_setAssociatedObject(
                view,
                &VInputFactory.blurHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "submit":
            delegate.onSubmit = handler
            textField.addTarget(
                delegate,
                action: #selector(InputDelegateProxy.textFieldDidReturn(_:)),
                for: .editingDidEndOnExit
            )
            objc_setAssociatedObject(
                view,
                &VInputFactory.submitHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        guard let textField = view as? UITextField else { return }
        guard let delegate = objc_getAssociatedObject(textField, &VInputFactory.delegateKey) as? InputDelegateProxy else { return }

        switch event {
        case "changetext":
            delegate.onChangeText = nil
            textField.removeTarget(delegate, action: #selector(InputDelegateProxy.textFieldEditingChanged(_:)), for: .editingChanged)
        case "focus":
            delegate.onFocus = nil
            textField.removeTarget(delegate, action: #selector(InputDelegateProxy.textFieldDidBeginEditing(_:)), for: .editingDidBegin)
        case "blur":
            delegate.onBlur = nil
            textField.removeTarget(delegate, action: #selector(InputDelegateProxy.textFieldDidEndEditing(_:)), for: .editingDidEnd)
        case "submit":
            delegate.onSubmit = nil
            textField.removeTarget(delegate, action: #selector(InputDelegateProxy.textFieldDidReturn(_:)), for: .editingDidEndOnExit)
        default:
            break
        }
    }

    // MARK: - Private helpers

    private func ensureDelegate(for textField: UITextField) -> InputDelegateProxy {
        if let existing = objc_getAssociatedObject(textField, &VInputFactory.delegateKey) as? InputDelegateProxy {
            return existing
        }

        let delegate = InputDelegateProxy()
        delegate.maxLengthProvider = { [weak textField] in
            guard let tf = textField else { return nil }
            return self.storedMaxLength(on: tf)
        }
        textField.delegate = delegate
        objc_setAssociatedObject(
            textField,
            &VInputFactory.delegateKey,
            delegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return delegate
    }

    // MARK: - Max length storage

    private static var maxLengthKey: UInt8 = 0

    private func storeMaxLength(_ length: Int, on view: UIView) {
        objc_setAssociatedObject(view, &VInputFactory.maxLengthKey, length, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func storedMaxLength(on view: UIView) -> Int? {
        return objc_getAssociatedObject(view, &VInputFactory.maxLengthKey) as? Int
    }
}

// MARK: - InputDelegateProxy

/// UITextFieldDelegate proxy that routes text field events to closure-based handlers.
/// Stored as an associated object on the UITextField.
final class InputDelegateProxy: NSObject, UITextFieldDelegate {

    var onChangeText: ((Any?) -> Void)?
    var onFocus: ((Any?) -> Void)?
    var onBlur: ((Any?) -> Void)?
    var onSubmit: ((Any?) -> Void)?
    var maxLengthProvider: (() -> Int?)?

    @objc func textFieldEditingChanged(_ textField: UITextField) {
        onChangeText?(textField.text ?? "")
    }

    @objc func textFieldDidBeginEditing(_ textField: UITextField) {
        onFocus?(nil)
    }

    @objc func textFieldDidEndEditing(_ textField: UITextField) {
        onBlur?(nil)
    }

    @objc func textFieldDidReturn(_ textField: UITextField) {
        onSubmit?(textField.text ?? "")
    }

    // MARK: - UITextFieldDelegate

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        // Enforce max length if set
        if let maxLength = maxLengthProvider?() {
            let currentText = textField.text ?? ""
            let newLength = currentText.count + string.count - range.length
            return newLength <= maxLength
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Allow return key to trigger editingDidEndOnExit
        textField.resignFirstResponder()
        return true
    }
}
#endif
