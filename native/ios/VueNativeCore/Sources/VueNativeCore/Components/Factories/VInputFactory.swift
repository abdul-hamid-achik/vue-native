#if canImport(UIKit)
import UIKit
import ObjectiveC
import FlexLayout

/// Container view registered in the bridge's view registry for a VInput node.
///
/// The bridge keys views by `nodeId` and never allows the registered view's
/// identity to change at prop time. To support both single-line and multiline
/// editing without breaking that invariant, the *registered* view is this
/// stable container; the actual editing control (a `UITextField` for
/// single-line, a `UITextView` for multiline) lives inside it as a subview and
/// can be swapped in place when the `multiline` prop changes. Text, traits and
/// event handlers survive the swap.
final class VInputContainerView: UIView {

    // MARK: - State

    /// The editing control currently shown inside the container.
    private(set) var innerControl: UIView

    /// Whether multiline editing was requested via props.
    private(set) var isMultiline = false

    /// Whether secure entry was requested via props. `UITextView` has no secure
    /// mode, so a secure multiline input falls back to a single-line field.
    var isSecure = false {
        didSet {
            if let field = textField {
                field.isSecureTextEntry = isSecure
            }
            rebuildControlIfNeeded()
        }
    }

    /// Maximum number of characters enforced by the delegate proxy.
    var maxLength: Int?

    /// Placeholder string. Rendered natively on `UITextField`; rendered via an
    /// overlay label on `UITextView` (which has no placeholder of its own).
    var placeholderText: String? {
        didSet { applyPlaceholder() }
    }

    var placeholderColor: UIColor = .placeholderText {
        didSet { applyPlaceholder() }
    }

    /// Invoked by the factory owner whenever the inner control is swapped so it
    /// can re-wire delegates and event targets to the new control.
    var onControlChanged: (() -> Void)?

    private let placeholderLabel = UILabel()

    // MARK: - Convenience accessors

    var textField: UITextField? { innerControl as? UITextField }
    var textView: UITextView? { innerControl as? UITextView }

    var currentText: String {
        if let field = textField { return field.text ?? "" }
        if let tv = textView { return tv.text ?? "" }
        return ""
    }

    // MARK: - Init

    init() {
        let field = UITextField()
        field.borderStyle = .none
        innerControl = field
        super.init(frame: .zero)
        addSubview(field)
        setupPlaceholderLabel()
        // Accessing .flex enables Yoga layout. Give the container a sensible
        // default height so a single-line input is not collapsed.
        flex.height(44)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported for VInputContainerView")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        innerControl.frame = bounds
        layoutPlaceholderLabel()
    }

    // MARK: - Text

    func setText(_ text: String?) {
        if let field = textField {
            // Only update when different to avoid cursor jumps.
            if field.text != text { field.text = text }
        } else if let tv = textView {
            if tv.text != text { tv.text = text }
        }
        refreshPlaceholder()
    }

    // MARK: - Multiline

    func setMultiline(_ multiline: Bool) {
        guard multiline != isMultiline else { return }
        isMultiline = multiline
        if multiline && isSecure {
            #if DEBUG
            NSLog("[VueNative VInput] Warning: 'multiline' + 'secureTextEntry' is not supported; UITextView has no secure mode, keeping a single-line secure field")
            #endif
        }
        rebuildControlIfNeeded()
    }

    // MARK: - Placeholder

    func refreshPlaceholder() {
        // The single-line field renders its own placeholder; the overlay label
        // is only used for the multiline text view.
        guard textView != nil else {
            placeholderLabel.isHidden = true
            return
        }
        placeholderLabel.isHidden = !currentText.isEmpty
    }

    private func applyPlaceholder() {
        if let field = textField {
            if let placeholder = placeholderText {
                field.attributedPlaceholder = NSAttributedString(
                    string: placeholder,
                    attributes: [.foregroundColor: placeholderColor]
                )
            } else {
                field.attributedPlaceholder = nil
                field.placeholder = nil
            }
        }
        placeholderLabel.text = placeholderText
        placeholderLabel.textColor = placeholderColor
        refreshPlaceholder()
    }

    private func setupPlaceholderLabel() {
        placeholderLabel.numberOfLines = 0
        placeholderLabel.textColor = placeholderColor
        placeholderLabel.isHidden = true
        addSubview(placeholderLabel)
    }

    private func layoutPlaceholderLabel() {
        guard let tv = textView else { return }
        let inset = tv.textContainerInset
        let padding = tv.textContainer.lineFragmentPadding
        let originX = inset.left + padding
        let originY = inset.top
        let width = max(0, bounds.width - inset.left - inset.right - 2 * padding)
        let height = max(0, bounds.height - inset.top - inset.bottom)
        placeholderLabel.frame = CGRect(x: originX, y: originY, width: width, height: height)
        placeholderLabel.font = tv.font
    }

    // MARK: - Control swapping

    private func rebuildControlIfNeeded() {
        let useTextView = isMultiline && !isSecure
        if useTextView && textView != nil { return }
        if !useTextView && textField != nil { return }

        let preservedText = currentText
        let traits = Self.captureTraits(from: innerControl)
        let oldControl = innerControl

        let newControl: UIView
        if useTextView {
            let tv = UITextView()
            tv.backgroundColor = .clear
            tv.isScrollEnabled = true
            tv.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
            newControl = tv
        } else {
            let field = UITextField()
            field.borderStyle = .none
            field.isSecureTextEntry = isSecure
            newControl = field
        }

        Self.applyTraits(traits, to: newControl)
        if let field = newControl as? UITextField {
            field.text = preservedText
        } else if let tv = newControl as? UITextView {
            tv.text = preservedText
        }

        oldControl.removeFromSuperview()
        innerControl = newControl
        // Insert below the placeholder overlay so it stays on top.
        insertSubview(newControl, at: 0)
        newControl.frame = bounds

        onControlChanged?()
        applyPlaceholder()
        refreshPlaceholder()
        setNeedsLayout()
    }

    // MARK: - Trait preservation across swaps

    private struct ControlTraits {
        var keyboardType: UIKeyboardType = .default
        var returnKeyType: UIReturnKeyType = .default
        var autocapitalizationType: UITextAutocapitalizationType = .sentences
        var autocorrectionType: UITextAutocorrectionType = .default
        var textColor: UIColor? = .label
        var font: UIFont?
        var textAlignment: NSTextAlignment = .natural
        var isEditable: Bool = true
    }

    private static func captureTraits(from view: UIView) -> ControlTraits {
        var traits = ControlTraits()
        if let field = view as? UITextField {
            traits.keyboardType = field.keyboardType
            traits.returnKeyType = field.returnKeyType
            traits.autocapitalizationType = field.autocapitalizationType
            traits.autocorrectionType = field.autocorrectionType
            traits.textColor = field.textColor
            traits.font = field.font
            traits.textAlignment = field.textAlignment
            traits.isEditable = field.isEnabled
        } else if let tv = view as? UITextView {
            traits.keyboardType = tv.keyboardType
            traits.returnKeyType = tv.returnKeyType
            traits.autocapitalizationType = tv.autocapitalizationType
            traits.autocorrectionType = tv.autocorrectionType
            traits.textColor = tv.textColor
            traits.font = tv.font
            traits.textAlignment = tv.textAlignment
            traits.isEditable = tv.isEditable
        }
        return traits
    }

    private static func applyTraits(_ traits: ControlTraits, to view: UIView) {
        if let field = view as? UITextField {
            field.keyboardType = traits.keyboardType
            field.returnKeyType = traits.returnKeyType
            field.autocapitalizationType = traits.autocapitalizationType
            field.autocorrectionType = traits.autocorrectionType
            field.textColor = traits.textColor
            field.font = traits.font
            field.textAlignment = traits.textAlignment
            field.isEnabled = traits.isEditable
        } else if let tv = view as? UITextView {
            tv.keyboardType = traits.keyboardType
            tv.returnKeyType = traits.returnKeyType
            tv.autocapitalizationType = traits.autocapitalizationType
            tv.autocorrectionType = traits.autocorrectionType
            tv.textColor = traits.textColor
            tv.font = traits.font
            tv.textAlignment = traits.textAlignment
            tv.isEditable = traits.isEditable
        }
    }
}

/// Factory for VInput — the text input component.
///
/// Registers a stable ``VInputContainerView`` in the bridge and drives either a
/// single-line `UITextField` or a multiline `UITextView` inside it. Supports
/// v-model via the text prop and the `changetext` event.
final class VInputFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var delegateKey: UInt8 = 0

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
        let container = VInputContainerView()
        container.onControlChanged = { [weak self, weak container] in
            guard let self, let container else { return }
            self.wireCurrentControl(in: container)
        }
        return container
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let container = view as? VInputContainerView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "text", "value":
            container.setText(value as? String)

        case "placeholder":
            container.placeholderText = value as? String

        case "placeholderColor", "placeholderTextColor":
            if let colorStr = value as? String, let color = UIColor.fromHex(colorStr) {
                container.placeholderColor = color
            }

        case "secureTextEntry":
            container.isSecure = Self.boolValue(value)

        case "keyboardType":
            let keyboardType = (value as? String).flatMap { VInputFactory.keyboardTypeMap[$0] } ?? .default
            applyToControl(in: container, field: { $0.keyboardType = keyboardType }, textView: { $0.keyboardType = keyboardType })

        case "returnKeyType":
            let returnKeyType = (value as? String).flatMap { VInputFactory.returnKeyMap[$0] } ?? .default
            applyToControl(in: container, field: { $0.returnKeyType = returnKeyType }, textView: { $0.returnKeyType = returnKeyType })

        case "autoCapitalize", "autocapitalize":
            let capitalization = (value as? String).flatMap { VInputFactory.autoCapitalizeMap[$0] } ?? .sentences
            applyToControl(in: container, field: { $0.autocapitalizationType = capitalization }, textView: { $0.autocapitalizationType = capitalization })

        case "autoCorrect", "autocorrect":
            let autocorrection: UITextAutocorrectionType = Self.boolValue(value) ? .yes : .no
            applyToControl(in: container, field: { $0.autocorrectionType = autocorrection }, textView: { $0.autocorrectionType = autocorrection })

        case "editable":
            let editable = value == nil ? true : Self.boolValue(value)
            applyToControl(in: container, field: { $0.isEnabled = editable }, textView: { $0.isEditable = editable })

        case "maxLength":
            if let maxLen = value as? Int {
                container.maxLength = maxLen
            } else if let maxLen = value as? Double {
                container.maxLength = Int(maxLen)
            } else {
                container.maxLength = nil
            }

        case "color":
            if let colorStr = value as? String, let color = UIColor.fromHex(colorStr) {
                applyToControl(in: container, field: { $0.textColor = color }, textView: { $0.textColor = color })
            } else {
                applyToControl(in: container, field: { $0.textColor = .label }, textView: { $0.textColor = .label })
            }

        case "fontSize":
            if let size = Self.cgFloatValue(value) {
                let scaled = UIFontMetrics.default.scaledValue(for: size)
                let font = UIFont.systemFont(ofSize: scaled)
                applyToControl(in: container, field: { $0.font = font }, textView: { $0.font = font })
            }

        case "textAlign":
            let alignment: NSTextAlignment
            switch value as? String {
            case "left": alignment = .left
            case "center": alignment = .center
            case "right": alignment = .right
            default: alignment = .natural
            }
            applyToControl(in: container, field: { $0.textAlignment = alignment }, textView: { $0.textAlignment = alignment })

        case "multiline":
            container.setMultiline(Self.boolValue(value))

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let container = view as? VInputContainerView else { return }
        let delegate = ensureDelegate(for: container)

        switch event {
        case "changetext":
            delegate.onChangeText = handler
        case "compositionstart":
            delegate.onCompositionStart = handler
        case "compositionend":
            delegate.onCompositionEnd = handler
        case "focus":
            delegate.onFocus = handler
        case "blur":
            delegate.onBlur = handler
        case "submit":
            delegate.onSubmit = handler
        default:
            break
        }

        wireCurrentControl(in: container)
    }

    func removeEventListener(view: UIView, event: String) {
        guard let container = view as? VInputContainerView else { return }
        guard let delegate = objc_getAssociatedObject(container, &VInputFactory.delegateKey) as? InputDelegateProxy else { return }

        switch event {
        case "changetext":
            delegate.onChangeText = nil
        case "compositionstart":
            delegate.onCompositionStart = nil
        case "compositionend":
            delegate.onCompositionEnd = nil
        case "focus":
            delegate.onFocus = nil
        case "blur":
            delegate.onBlur = nil
        case "submit":
            delegate.onSubmit = nil
        default:
            break
        }

        wireCurrentControl(in: container)
    }

    // MARK: - Private helpers

    private func ensureDelegate(for container: VInputContainerView) -> InputDelegateProxy {
        if let existing = objc_getAssociatedObject(container, &VInputFactory.delegateKey) as? InputDelegateProxy {
            return existing
        }

        let delegate = InputDelegateProxy()
        delegate.container = container
        objc_setAssociatedObject(
            container,
            &VInputFactory.delegateKey,
            delegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return delegate
    }

    /// (Re)attach the shared delegate proxy to whichever editing control is
    /// currently inside the container. Idempotent — safe to call after every
    /// listener change and after every single-line ↔ multiline swap.
    private func wireCurrentControl(in container: VInputContainerView) {
        let delegate = ensureDelegate(for: container)

        if let field = container.textField {
            field.delegate = delegate
            field.removeTarget(delegate, action: nil, for: .allEvents)
            if delegate.onChangeText != nil {
                field.addTarget(delegate, action: #selector(InputDelegateProxy.textFieldEditingChanged(_:)), for: .editingChanged)
            }
            if delegate.onFocus != nil {
                field.addTarget(delegate, action: #selector(InputDelegateProxy.textFieldDidBeginEditing(_:)), for: .editingDidBegin)
            }
            if delegate.onBlur != nil {
                field.addTarget(delegate, action: #selector(InputDelegateProxy.textFieldDidEndEditing(_:)), for: .editingDidEnd)
            }
            if delegate.onSubmit != nil {
                field.addTarget(delegate, action: #selector(InputDelegateProxy.textFieldDidReturn(_:)), for: .editingDidEndOnExit)
            }
        } else if let textView = container.textView {
            textView.delegate = delegate
        }
    }

    private func applyToControl(
        in container: VInputContainerView,
        field: (UITextField) -> Void,
        textView: (UITextView) -> Void
    ) {
        if let textField = container.textField {
            field(textField)
        } else if let textViewModel = container.textView {
            textView(textViewModel)
        }
    }

    private static func boolValue(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let int = value as? Int { return int != 0 }
        return false
    }

    private static func cgFloatValue(_ value: Any?) -> CGFloat? {
        if let double = value as? Double { return CGFloat(double) }
        if let int = value as? Int { return CGFloat(int) }
        return nil
    }
}

// MARK: - InputDelegateProxy

/// Delegate proxy that routes both `UITextField` and `UITextView` events to
/// closure-based handlers. A single proxy instance is stored on the container
/// and re-attached to whichever editing control is active, so handlers survive
/// single-line ↔ multiline swaps.
final class InputDelegateProxy: NSObject, UITextFieldDelegate, UITextViewDelegate {

    weak var container: VInputContainerView?

    var onChangeText: ((Any?) -> Void)?
    var onCompositionStart: ((Any?) -> Void)?
    var onCompositionEnd: ((Any?) -> Void)?
    var onFocus: ((Any?) -> Void)?
    var onBlur: ((Any?) -> Void)?
    var onSubmit: ((Any?) -> Void)?

    /// Whether an IME composition session is currently active. Tracked via the
    /// control's `markedTextRange`: a non-nil range means uncommitted marked
    /// text is present (composition in progress).
    private var isComposing = false

    // MARK: - IME composition tracking

    /// Emit `compositionstart`/`compositionend` around IME composition sessions
    /// (e.g. CJK input). `markedTextRange` is non-nil while the IME holds
    /// uncommitted marked text; it becomes nil when the text is committed (or
    /// the session is cancelled). Transitioning into/out of that state is the
    /// reliable, documented signal for composition boundaries.
    ///
    /// Internal (rather than private) so the transition logic can be unit-tested
    /// without driving a real IME, which cannot be synthesized on a simulator.
    func updateCompositionState(hasMarkedText: Bool, committedText: String) {
        if hasMarkedText {
            if !isComposing {
                isComposing = true
                onCompositionStart?(nil)
            }
        } else if isComposing {
            isComposing = false
            onCompositionEnd?(committedText)
        }
    }

    // MARK: - UITextField target actions

    @objc func textFieldEditingChanged(_ textField: UITextField) {
        onChangeText?(textField.text ?? "")
        container?.refreshPlaceholder()
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
        return isWithinMaxLength(currentText: textField.text ?? "", range: range, replacement: string)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Allow return key to trigger editingDidEndOnExit.
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        // Fires on every selection/marked-text change, including each IME
        // keystroke, so it reliably brackets composition sessions.
        updateCompositionState(hasMarkedText: textField.markedTextRange != nil, committedText: textField.text ?? "")
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        onChangeText?(textView.text ?? "")
        container?.refreshPlaceholder()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        onFocus?(nil)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        onBlur?(nil)
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        return isWithinMaxLength(currentText: textView.text ?? "", range: range, replacement: text)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        updateCompositionState(hasMarkedText: textView.markedTextRange != nil, committedText: textView.text ?? "")
    }

    // MARK: - Max length

    private func isWithinMaxLength(currentText: String, range: NSRange, replacement: String) -> Bool {
        guard let maxLength = container?.maxLength else { return true }
        let newLength = currentText.count + replacement.count - range.length
        return newLength <= maxLength
    }
}
#endif
