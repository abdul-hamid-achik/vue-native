#if canImport(UIKit)
import UIKit

/// Keeps `layer.cornerRadius` at or below half of a view's shortest side.
///
/// JS styles commonly ask for a pill with an oversized radius (`borderRadius: 999`). With
/// `clipsToBounds` on, recent UIKit/Core Animation releases do not clamp such a radius: the
/// layer renders nothing, so the background and every child disappear (VN-15). The requested
/// radius is remembered per view and re-applied, clamped, after every layout pass, since a
/// style can arrive before Yoga has given the view a size.
enum CornerRadiusClamp {
    private static var requestedKey: UInt8 = 0
    private static let views = NSHashTable<UIView>.weakObjects()

    /// Record the radius the style asked for and apply it as far as the current bounds allow.
    /// `nil` forgets the view (radius removed).
    static func request(_ radius: CGFloat?, on view: UIView) {
        guard let radius else {
            objc_setAssociatedObject(view, &requestedKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            views.remove(view)
            return
        }
        objc_setAssociatedObject(
            view, &requestedKey, NSNumber(value: Double(radius)), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        views.add(view)
        apply(to: view)
    }

    static func requested(for view: UIView) -> CGFloat? {
        (objc_getAssociatedObject(view, &requestedKey) as? NSNumber).map { CGFloat($0.doubleValue) }
    }

    /// The radius to draw: the requested one, capped at half the shortest side once laid out.
    static func effective(_ requested: CGFloat, bounds: CGRect) -> CGFloat {
        let half = min(bounds.width, bounds.height) / 2
        return half > 0 ? min(requested, half) : requested
    }

    static func apply(to view: UIView) {
        guard let requested = requested(for: view) else { return }
        let radius = effective(requested, bounds: view.bounds)
        if view.layer.cornerRadius != radius { view.layer.cornerRadius = radius }
    }

    /// Re-clamp every view with a requested radius (called after each layout pass).
    static func applyAll() {
        for view in views.allObjects { apply(to: view) }
    }
}
#endif
