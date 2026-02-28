import AppKit
import ObjectiveC

/// Factory for VInput — the text input component.
/// Maps to an NSTextField (editable) with a LayoutNode.
/// Supports v-model via text prop and changetext event.
/// For secure text entry, swaps to an NSSecureTextField.
final class VInputFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var delegateKey: UInt8 = 0
    private static var changeTextHandlerKey: UInt8 = 0
    private static var focusHandlerKey: UInt8 = 0
    private static var blurHandlerKey: UInt8 = 0
    private static var submitHandlerKey: UInt8 = 0
    private static var maxLengthKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let textField = NSTextField()
        textField.isBordered = true
        textField.isEditable = true
        textField.isSelectable = true
        textField.wantsLayer = true
        // Set a sensible default height so the text field is not collapsed
        let node = textField.ensureLayoutNode()
        node.height = .points(28)
        return textField
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let textField = view as? NSTextField else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "text", "value":
            if let text = value as? String {
                // Only update if different to avoid cursor jump
                if textField.stringValue != text {
                    textField.stringValue = text
                }
            } else {
                textField.stringValue = ""
            }

        case "placeholder":
            if let placeholder = value as? String {
                textField.placeholderString = placeholder
            } else {
                textField.placeholderString = nil
            }

        case "placeholderColor", "placeholderTextColor":
            if let colorStr = value as? String, let placeholder = textField.placeholderString {
                textField.placeholderAttributedString = NSAttributedString(
                    string: placeholder,
                    attributes: [.foregroundColor: NSColor.fromHex(colorStr)]
                )
            }

        case "secureTextEntry":
            // Note: NSSecureTextField is a subclass, not a property toggle.
            // Full secure text entry requires view replacement at the bridge level.
            // Here we just store the prop for reference.
            let secure: Bool
            if let val = value as? Bool {
                secure = val
            } else if let val = value as? Int {
                secure = val != 0
            } else {
                secure = false
            }
            StyleEngine.setInternalPropDirect("__secureTextEntry", value: secure, on: view)

        case "editable":
            if let editable = value as? Bool {
                textField.isEditable = editable
            } else {
                textField.isEditable = true
            }

        case "maxLength":
            if let maxLen = value as? Int {
                storeMaxLength(maxLen, on: textField)
            } else if let maxLen = value as? Double {
                storeMaxLength(Int(maxLen), on: textField)
            }

        case "color":
            if let colorStr = value as? String {
                textField.textColor = NSColor.fromHex(colorStr)
            } else {
                textField.textColor = .labelColor
            }

        case "fontSize":
            if let size = value as? Double {
                textField.font = NSFont.systemFont(ofSize: CGFloat(size))
            } else if let size = value as? Int {
                textField.font = NSFont.systemFont(ofSize: CGFloat(size))
            }

        case "textAlign":
            if let alignStr = value as? String {
                switch alignStr {
                case "left": textField.alignment = .left
                case "center": textField.alignment = .center
                case "right": textField.alignment = .right
                default: textField.alignment = .natural
                }
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let textField = view as? NSTextField else { return }

        // Ensure we have a delegate proxy set up
        let delegate = ensureDelegate(for: textField)

        switch event {
        case "changetext":
            delegate.onChangeText = handler
            objc_setAssociatedObject(
                view,
                &VInputFactory.changeTextHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "focus":
            delegate.onFocus = handler
            objc_setAssociatedObject(
                view,
                &VInputFactory.focusHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "blur":
            delegate.onBlur = handler
            objc_setAssociatedObject(
                view,
                &VInputFactory.blurHandlerKey,
                handler as AnyObject,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "submit":
            delegate.onSubmit = handler
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

    func removeEventListener(view: NSView, event: String) {
        guard let textField = view as? NSTextField else { return }
        guard let delegate = objc_getAssociatedObject(textField, &VInputFactory.delegateKey) as? InputDelegateProxy else { return }

        switch event {
        case "changetext":
            delegate.onChangeText = nil
        case "focus":
            delegate.onFocus = nil
        case "blur":
            delegate.onBlur = nil
        case "submit":
            delegate.onSubmit = nil
        default:
            break
        }
    }

    // MARK: - Private helpers

    private func ensureDelegate(for textField: NSTextField) -> InputDelegateProxy {
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

    private func storeMaxLength(_ length: Int, on view: NSView) {
        objc_setAssociatedObject(view, &VInputFactory.maxLengthKey, length, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func storedMaxLength(on view: NSView) -> Int? {
        return objc_getAssociatedObject(view, &VInputFactory.maxLengthKey) as? Int
    }
}

// MARK: - InputDelegateProxy

/// NSTextFieldDelegate proxy that routes text field events to closure-based handlers.
/// Stored as an associated object on the NSTextField.
final class InputDelegateProxy: NSObject, NSTextFieldDelegate {

    var onChangeText: ((Any?) -> Void)?
    var onFocus: ((Any?) -> Void)?
    var onBlur: ((Any?) -> Void)?
    var onSubmit: ((Any?) -> Void)?
    var maxLengthProvider: (() -> Int?)?

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        // Enforce max length
        if let maxLength = maxLengthProvider?(), textField.stringValue.count > maxLength {
            textField.stringValue = String(textField.stringValue.prefix(maxLength))
        }
        onChangeText?(textField.stringValue)
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        onFocus?(nil)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        onBlur?(nil)
        // Check if editing ended due to Return key
        if let textField = obj.object as? NSTextField,
           let movement = obj.userInfo?["NSTextMovement"] as? Int,
           movement == NSReturnTextMovement {
            onSubmit?(textField.stringValue)
        }
    }
}
