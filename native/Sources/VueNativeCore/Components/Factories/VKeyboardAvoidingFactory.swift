#if canImport(UIKit)
import UIKit
import FlexLayout

/// Factory for VKeyboardAvoiding — a container that adjusts its bottom padding
/// to avoid the system keyboard.
///
/// Listens to UIResponder.keyboardWillShowNotification / keyboardWillHideNotification
/// and updates FlexLayout bottom padding accordingly.
final class VKeyboardAvoidingFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var observerKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let view = KeyboardAvoidingView()
        _ = view.flex
        return view
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        StyleEngine.apply(key: key, value: value, to: view)
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        // No events exposed for keyboard avoiding view
    }
}

// MARK: - KeyboardAvoidingView

/// UIView subclass that automatically adjusts its Yoga bottom padding
/// based on keyboard visibility.
private final class KeyboardAvoidingView: UIView {

    private var showObserver: NSObjectProtocol?
    private var hideObserver: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupKeyboardObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupKeyboardObservers()
    }

    deinit {
        if let obs = showObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = hideObserver { NotificationCenter.default.removeObserver(obs) }
    }

    private func setupKeyboardObservers() {
        showObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleKeyboardShow(notification)
        }

        hideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleKeyboardHide()
        }
    }

    private func handleKeyboardShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboardHeight = keyboardFrame.height
        flex.paddingBottom(keyboardHeight)
        triggerLayout()
    }

    private func handleKeyboardHide() {
        flex.paddingBottom(0)
        triggerLayout()
    }

    private func triggerLayout() {
        // Walk up to find the root flex view and trigger layout
        var view: UIView? = self
        while let v = view?.superview {
            view = v
        }
        view?.flex.layout()
    }
}
#endif
