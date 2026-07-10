#if canImport(UIKit)
import UIKit
import FlexLayout

/// Factory for VModal — a window-level overlay component.
/// The VModal view itself is a zero-size placeholder in the native view tree.
/// Its children are rendered in a full-screen overlay view added to the key window.
final class VModalFactory: NativeComponentFactory {

    private static var overlayKey: UInt8 = 0
    private static var visibleKey: UInt8 = 1
    private static var dismissTargetKey: UInt8 = 2
    private static var dismissGestureKey: UInt8 = 3

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
            // VModal's public style belongs to the visible overlay, not the
            // zero-size placeholder retained in the logical view tree.
            let overlay = getOrCreateOverlay(for: view)
            StyleEngine.apply(key: key, value: value, to: overlay)
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

        let overlay = getOrCreateOverlay(for: placeholder)

        overlay.frame = window.bounds
        window.addSubview(overlay)

        if let dismissTarget = objc_getAssociatedObject(
            placeholder,
            &VModalFactory.dismissTargetKey
        ) as? ModalDismissTarget {
            installDismissGesture(on: overlay, target: dismissTarget)
        }

        // Run Yoga on overlay children
        overlay.flex.layout(mode: .fitContainer)
    }

    private func hideOverlay(for placeholder: UIView) {
        if let overlay = objc_getAssociatedObject(placeholder, &VModalFactory.overlayKey) as? UIView {
            overlay.removeFromSuperview()
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard event == "dismiss" else { return }

        let target = ModalDismissTarget(handler: handler)
        objc_setAssociatedObject(
            view,
            &VModalFactory.dismissTargetKey,
            target,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        if let overlay = objc_getAssociatedObject(view, &VModalFactory.overlayKey) as? UIView {
            installDismissGesture(on: overlay, target: target)
        }
    }

    func removeEventListener(view: UIView, event: String) {
        guard event == "dismiss" else { return }

        objc_setAssociatedObject(view, &VModalFactory.dismissTargetKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if let overlay = objc_getAssociatedObject(view, &VModalFactory.overlayKey) as? UIView,
           let gesture = objc_getAssociatedObject(
               overlay,
               &VModalFactory.dismissGestureKey
           ) as? UITapGestureRecognizer {
            overlay.removeGestureRecognizer(gesture)
            objc_setAssociatedObject(overlay, &VModalFactory.dismissGestureKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // Custom child management: route children to the overlay view
    func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?) {
        let overlay = getOrCreateOverlay(for: parent)

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

    private func getOrCreateOverlay(for placeholder: UIView) -> UIView {
        if let existing = objc_getAssociatedObject(placeholder, &VModalFactory.overlayKey) as? UIView {
            return existing
        }

        let overlay = UIView()
        overlay.backgroundColor = UIColor(white: 0, alpha: 0.5)
        overlay.isUserInteractionEnabled = true
        _ = overlay.flex.grow(1)
        objc_setAssociatedObject(
            placeholder,
            &VModalFactory.overlayKey,
            overlay,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return overlay
    }

    private func installDismissGesture(on overlay: UIView, target: ModalDismissTarget) {
        if let existing = objc_getAssociatedObject(
            overlay,
            &VModalFactory.dismissGestureKey
        ) as? UITapGestureRecognizer {
            overlay.removeGestureRecognizer(existing)
        }

        target.overlay = overlay
        let gesture = UITapGestureRecognizer(target: target, action: #selector(ModalDismissTarget.handleTap(_:)))
        gesture.delegate = target
        gesture.cancelsTouchesInView = false
        overlay.addGestureRecognizer(gesture)
        objc_setAssociatedObject(
            overlay,
            &VModalFactory.dismissGestureKey,
            gesture,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

/// Delivers a dismiss event only when the user taps the backdrop itself. A
/// gesture attached to the full-screen overlay must not turn presses inside
/// modal content into accidental dismissals.
private final class ModalDismissTarget: NSObject, UIGestureRecognizerDelegate {
    weak var overlay: UIView?
    private let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
    }

    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        handler(nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.view === overlay
    }
}
#endif
