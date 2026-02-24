#if canImport(UIKit)
import UIKit
import FlexLayout

/// Factory for VModal — a window-level overlay component.
/// The VModal view itself is a zero-size placeholder in the native view tree.
/// Its children are rendered in a full-screen overlay view added to the key window.
final class VModalFactory: NativeComponentFactory {

    private static var overlayKey: UInt8 = 0
    private static var visibleKey: UInt8 = 1

    func createView() -> UIView {
        // Zero-size placeholder in the tree
        let placeholder = UIView()
        placeholder.isHidden = true
        _ = placeholder.flex.width(0).height(0)
        return placeholder
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        switch key {
        case "visible":
            let visible = (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
            updateVisibility(view: view, visible: visible)
        case "onDismiss":
            break // handled via event
        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    private func updateVisibility(view: UIView, visible: Bool) {
        if visible {
            showOverlay(for: view)
        } else {
            hideOverlay(for: view)
        }
    }

    private func showOverlay(for placeholder: UIView) {
        guard let window = UIApplication.shared.vn_keyWindow else { return }

        // Get or create overlay
        let overlay: UIView
        if let existing = objc_getAssociatedObject(placeholder, &VModalFactory.overlayKey) as? UIView {
            overlay = existing
        } else {
            overlay = UIView()
            overlay.backgroundColor = UIColor(white: 0, alpha: 0.5)
            objc_setAssociatedObject(
                placeholder,
                &VModalFactory.overlayKey,
                overlay,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }

        overlay.frame = window.bounds
        window.addSubview(overlay)

        // Run Yoga on overlay children
        overlay.flex.layout(mode: .fitContainer)
    }

    private func hideOverlay(for placeholder: UIView) {
        if let overlay = objc_getAssociatedObject(placeholder, &VModalFactory.overlayKey) as? UIView {
            overlay.removeFromSuperview()
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        // dismiss event from tapping backdrop — no-op for now
    }

    func removeEventListener(view: UIView, event: String) {}

    // Custom child management: route children to the overlay view
    func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?) {
        let overlay: UIView
        if let existing = objc_getAssociatedObject(parent, &VModalFactory.overlayKey) as? UIView {
            overlay = existing
        } else {
            // Create overlay early so children have somewhere to go
            let newOverlay = UIView()
            newOverlay.backgroundColor = UIColor(white: 0, alpha: 0.5)
            _ = newOverlay.flex.grow(1)
            objc_setAssociatedObject(
                parent,
                &VModalFactory.overlayKey,
                newOverlay,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            overlay = newOverlay
        }

        if let anchor = anchor, let idx = overlay.subviews.firstIndex(of: anchor) {
            overlay.insertSubview(child, at: idx)
        } else {
            overlay.addSubview(child)
        }
        _ = child.flex
    }

    func removeChild(_ child: UIView, from parent: UIView) {
        child.removeFromSuperview()
    }
}
#endif
