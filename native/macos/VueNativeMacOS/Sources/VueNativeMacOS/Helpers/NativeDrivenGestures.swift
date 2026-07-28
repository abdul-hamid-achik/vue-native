import AppKit
import ObjectiveC

/// Storage for the `nativeDrivenGestures` prop.
///
/// The runtime (`useGesture({ pan: { nativeDrive: true } })`) pushes the set of
/// native-driven gesture names to the view via the `nativeDrivenGestures` prop
/// (an array of strings, e.g. `["pan"]`). When a gesture name is present in this
/// set, the corresponding native gesture handler applies its visual effect directly
/// to the view on the UI thread instead of waiting for a JS round-trip per frame.
///
/// Backed by an associated object so it works for any `NSView` without subclassing,
/// mirroring the pattern used by `GestureStorage`.
enum NativeDrivenGestureStorage {
    private static var storageKey: UInt8 = 0

    static func set(_ gestures: Set<String>, for view: NSView) {
        objc_setAssociatedObject(view, &storageKey, gestures, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func get(for view: NSView) -> Set<String> {
        return objc_getAssociatedObject(view, &storageKey) as? Set<String> ?? []
    }

    /// Whether the given gesture (e.g. `"pan"`) is marked native-driven for the view.
    static func isNativeDriven(_ gesture: String, for view: NSView) -> Bool {
        return get(for: view).contains(gesture)
    }
}

extension NSView {
    /// The set of gesture names that are native-driven for this view.
    ///
    /// Read at gesture-fire time (not at listener-registration time) so the prop and
    /// the `addEventListener` call can arrive in either order.
    var nativeDrivenGestures: Set<String> {
        get { NativeDrivenGestureStorage.get(for: self) }
        set { NativeDrivenGestureStorage.set(newValue, for: self) }
    }
}
