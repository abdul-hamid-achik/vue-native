#if canImport(UIKit)
import UIKit
import FlexLayout

/// Factory for VSafeArea — a container that automatically applies safe area insets as padding.
/// Maps content insets to Yoga padding so children avoid the notch/home indicator.
final class VSafeAreaFactory: NativeComponentFactory {

    func createView() -> UIView {
        let view = SafeAreaView()
        _ = view.flex
        return view
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        StyleEngine.apply(key: key, value: value, to: view)
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {}
    func removeEventListener(view: UIView, event: String) {}
}

/// UIView subclass that applies safeAreaInsets as Yoga padding on every layout pass.
final class SafeAreaView: UIView {

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        applyInsets()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyInsets()
    }

    private func applyInsets() {
        let insets = safeAreaInsets
        flex.paddingTop(insets.top)
        flex.paddingBottom(insets.bottom)
        flex.paddingLeft(insets.left)
        flex.paddingRight(insets.right)
        // Trigger layout recalculation
        if let root = findFlexRoot() {
            root.flex.layout(mode: .fitContainer)
        }
    }

    private func findFlexRoot() -> UIView? {
        var v: UIView? = self
        while let parent = v?.superview {
            v = parent
        }
        return v
    }
}
#endif
