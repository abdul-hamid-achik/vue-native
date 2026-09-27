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

    func destroyView(view: UIView) {
        (view as? KeyboardAvoidingView)?.removeKeyboardObservers()
    }

    // MARK: - Keyboard geometry

    /// How much of `view`'s height the keyboard actually covers.
    ///
    /// The raw `keyboardFrameEndUserInfoKey` height is the keyboard's full height in
    /// screen coordinates and says nothing about where this view sits. Using it
    /// verbatim over-pads any container that does not reach the bottom of the screen
    /// (a view inset by a tab bar, a nested container, a partially covered split
    /// layout). Pure and static so it can be unit-tested without a window.
    ///
    /// - Parameters:
    ///   - viewBottom: The view's bottom edge, in the same coordinate space as
    ///     `keyboardTop`.
    ///   - keyboardTop: The keyboard's top edge in that space.
    ///   - keyboardHeight: The keyboard's own height, used to clamp the result so a
    ///     keyboard entirely above the view cannot pad by more than it is tall.
    static func keyboardOverlapHeight(
        viewBottom: CGFloat,
        keyboardTop: CGFloat,
        keyboardHeight: CGFloat
    ) -> CGFloat {
        guard keyboardHeight > 0 else { return 0 }
        return min(max(0, viewBottom - keyboardTop), keyboardHeight)
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
        removeKeyboardObservers()
    }

    fileprivate func removeKeyboardObservers() {
        if let showObserver {
            NotificationCenter.default.removeObserver(showObserver)
            self.showObserver = nil
        }
        if let hideObserver {
            NotificationCenter.default.removeObserver(hideObserver)
            self.hideObserver = nil
        }
    }

    private func setupKeyboardObservers() {
        showObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleKeyboardShow(notification)
            }
        }

        hideObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleKeyboardHide()
            }
        }
    }

    private func handleKeyboardShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        guard keyboardFrame.height > 0 else { return }

        // The notification reports the frame in screen coordinates; convert it into
        // this view's space so the overlap reflects where the view actually ends.
        // Without a window there is nothing to convert against, so fall back to the
        // raw height rather than dropping the inset entirely.
        let padding: CGFloat
        if window != nil {
            let inView = convert(keyboardFrame, from: nil)
            padding = VKeyboardAvoidingFactory.keyboardOverlapHeight(
                viewBottom: bounds.maxY,
                keyboardTop: inView.minY,
                keyboardHeight: keyboardFrame.height
            )
        } else {
            padding = keyboardFrame.height
        }

        flex.paddingBottom(padding)
        triggerLayout()
    }

    private func handleKeyboardHide() {
        flex.paddingBottom(0)
        triggerLayout()
    }

    /// Ask the bridge for a full layout pass.
    ///
    /// This used to walk to the root superview and call `flex.layout()` on it
    /// directly. That bypassed `NativeBridge.triggerLayout()`, so
    /// `updateScrollViewContentSizes()` and `reportFlatListItemHeights()` never
    /// re-ran and nested scroll views kept a stale `contentSize` after the keyboard
    /// moved; it also wrote `frame` on the AutoLayout-pinned root view, fighting the
    /// constraints the bridge installed.
    private func triggerLayout() {
        NativeBridge.shared.requestLayout()
    }
}
#endif
