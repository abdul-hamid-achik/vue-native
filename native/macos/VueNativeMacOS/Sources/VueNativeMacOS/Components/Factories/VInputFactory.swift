import AppKit
import ObjectiveC

/// Factory for VInput — the text input component.
/// Maps to an NSTextField (editable) with a LayoutNode.
/// Supports v-model via text prop and changetext event.
/// For secure text entry, swaps the field's cell to an NSSecureTextFieldCell so
/// input is masked without replacing the view instance the bridge references.
/// For multiline, configures the field for word-wrapping, vertical growth.
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
            if let colorStr = value as? String,
               let color = NSColor.fromHex(colorStr),
               let placeholder = textField.placeholderString {
                textField.placeholderAttributedString = NSAttributedString(
                    string: placeholder,
                    attributes: [.foregroundColor: color]
                )
            }

        case "secureTextEntry":
            let secure: Bool
            if let val = value as? Bool {
                secure = val
            } else if let val = value as? Int {
                secure = val != 0
            } else {
                secure = false
            }
            applySecureTextEntry(secure, to: textField)
            StyleEngine.setInternalPropDirect("__secureTextEntry", value: secure, on: view)

        case "multiline":
            let multiline: Bool
            if let val = value as? Bool {
                multiline = val
            } else if let val = value as? Int {
                multiline = val != 0
            } else {
                multiline = false
            }
            applyMultiline(multiline, to: textField)
            StyleEngine.setInternalPropDirect("__multiline", value: multiline, on: view)

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
                if let color = NSColor.fromHex(colorStr) {
                    textField.textColor = color
                }
            } else {
                textField.textColor = .labelColor
            }

        case "fontSize":
            if let size = value as? Double {
                textField.font = NSFont.systemFont(ofSize: StyleEngine.scaledFontSize(CGFloat(size)))
            } else if let size = value as? Int {
                textField.font = NSFont.systemFont(ofSize: StyleEngine.scaledFontSize(CGFloat(size)))
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

    // MARK: - Secure text entry

    /// Toggle secure (password) entry by swapping the field's cell.
    ///
    /// `NSSecureTextField` is a subclass of `NSTextField`, so secure entry cannot
    /// be toggled with a plain property. The bridge keeps a stable reference to
    /// this view instance (keyed by node id), so the view cannot be replaced
    /// either. Instead we swap the underlying cell: `NSSecureTextFieldCell` is
    /// exactly what `NSSecureTextField` uses internally to mask input, and it can
    /// be installed on an existing `NSTextField` without changing its identity.
    /// Text, placeholder, delegate, and editing configuration are preserved.
    private func applySecureTextEntry(_ secure: Bool, to textField: NSTextField) {
        let isSecure = textField.cell is NSSecureTextFieldCell
        guard isSecure != secure else { return }

        // Capture state that lives on the cell and would otherwise be lost.
        let currentCell = textField.cell as? NSTextFieldCell
        let text = textField.stringValue
        let placeholder = textField.placeholderString
        let isEditable = textField.isEditable
        let isSelectable = textField.isSelectable
        let isBordered = textField.isBordered
        let drawsBackground = textField.drawsBackground
        let font = textField.font
        let textColor = textField.textColor
        let alignment = textField.alignment
        let wraps = currentCell?.wraps ?? false
        let isScrollable = currentCell?.isScrollable ?? true
        let usesSingleLineMode = currentCell?.usesSingleLineMode ?? true

        textField.cell = secure ? NSSecureTextFieldCell() : NSTextFieldCell()

        let newCell = textField.cell as? NSTextFieldCell
        textField.stringValue = text
        textField.placeholderString = placeholder
        textField.isEditable = isEditable
        textField.isSelectable = isSelectable
        textField.isBordered = isBordered
        textField.drawsBackground = drawsBackground
        textField.font = font
        textField.textColor = textColor
        textField.alignment = alignment
        newCell?.wraps = wraps
        newCell?.isScrollable = isScrollable
        newCell?.usesSingleLineMode = usesSingleLineMode
    }

    // MARK: - Multiline

    /// Toggle multiline wrapping on the existing text field.
    ///
    /// A wrapping, non-scrolling `NSTextField` provides multiline editing without
    /// replacing the view (which the bridge references by node id). When multiline
    /// is enabled the field wraps words and grows vertically; otherwise it behaves
    /// as a single-line, horizontally-scrolling field.
    private func applyMultiline(_ multiline: Bool, to textField: NSTextField) {
        let cell = textField.cell as? NSTextFieldCell
        if multiline {
            cell?.wraps = true
            cell?.isScrollable = false
            cell?.usesSingleLineMode = false
            textField.maximumNumberOfLines = 0 // unlimited
            textField.lineBreakMode = .byWordWrapping
        } else {
            cell?.wraps = false
            cell?.isScrollable = true
            cell?.usesSingleLineMode = true
            textField.maximumNumberOfLines = 1
        }
        textField.layoutNode?.markDirty()
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
