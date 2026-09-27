import AppKit

/// Factory for VRefreshControl — stub on macOS.
/// Pull-to-refresh is a touch gesture that does not exist on desktop: `NSScrollView`
/// has no rubber-band overscroll to hang a trigger on. This factory exists for API
/// compatibility so that cross-platform code using VRefreshControl does not break
/// on macOS.
///
/// Every prop and listener is refused with a DEBUG warning rather than dropped
/// silently, so an app that expects `refresh` to fire finds out at build-run time
/// instead of shipping a spinner that never resolves. The macOS-side workaround is
/// an explicit refresh affordance (a toolbar item or a `VButton`).
final class VRefreshControlFactory: NativeComponentFactory {

    /// Warned once per key so a list of items does not spam the console.
    private static var warnedKeys = Set<String>()

    func createView() -> NSView {
        let view = FlippedView()
        view.isHidden = true
        let node = view.ensureLayoutNode()
        node.width = .points(0)
        node.height = .points(0)
        return view
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        // No-op — pull-to-refresh doesn't exist on macOS
        Self.warnOnce("prop '\(key)'")
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        // No-op — the handler can never be invoked on this platform.
        Self.warnOnce("event '\(event)' (this listener will never fire)")
    }

    func removeEventListener(view: NSView, event: String) {
        // No-op.
    }

    private static func warnOnce(_ what: String) {
        #if DEBUG
        guard !warnedKeys.contains(what) else { return }
        warnedKeys.insert(what)
        NSLog("[VueNative macOS] VRefreshControl is a no-op stub: pull-to-refresh does not exist on macOS. Ignoring \(what). Use an explicit refresh control instead.")
        #endif
    }
}
