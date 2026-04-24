#if canImport(UIKit)
import JavaScriptCore
import UIKit
import VueNativeShared

/// iOS-specific requestAnimationFrame helper using CADisplayLink.
/// Registers requestAnimationFrame/cancelAnimationFrame on the JS context
/// and manages the display link lifecycle.
enum IOSRAFHelper {

    /// Active display link for requestAnimationFrame. Accessed only from main thread.
    private static var displayLink: CADisplayLink?

    // MARK: - Registration

    /// Register requestAnimationFrame/cancelAnimationFrame on the given JS context.
    /// MUST be called on the JS queue after SharedJSPolyfills.register().
    static func register(in runtime: JSRuntime) {
        guard let context = runtime.context else { return }

        // requestAnimationFrame(callback) -> rafId (String)
        let requestAnimationFrame: @convention(block) (JSValue) -> JSValue = { [weak runtime] callback in
            guard let runtime = runtime, let context = runtime.context else {
                return JSValue(nullIn: JSContext.current())
            }

            // Store callback using shared helper and get an ID
            let rafId = SharedJSPolyfills.storeRAFCallback(callback)

            // Ensure display link is running
            DispatchQueue.main.async {
                if displayLink == nil {
                    let target = DisplayLinkTarget(runtime: runtime)
                    let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.handleFrame(_:)))
                    link.add(to: .main, forMode: .common)
                    displayLink = link
                }
            }

            return JSValue(object: rafId, in: context)
        }

        // cancelAnimationFrame(rafId)
        let cancelAnimationFrame: @convention(block) (JSValue) -> Void = { [weak runtime] rafId in
            _ = runtime
            guard let id = rafId.toString() else { return }
            // Remove the callback using shared helper
            SharedJSPolyfills.removeRAFCallback(id)
        }

        context.setObject(requestAnimationFrame, forKeyedSubscript: "requestAnimationFrame" as NSString)
        context.setObject(cancelAnimationFrame, forKeyedSubscript: "cancelAnimationFrame" as NSString)
    }

    // MARK: - Reset

    /// Reset RAF state and stop the display link.
    /// Safe to call from any thread — display link operations are dispatched to main thread.
    static func reset() {
        DispatchQueue.main.async {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    // MARK: - Display Link Callback

    /// Called from the display link target on every frame.
    /// Dispatches all pending RAF callbacks to the JS queue.
    fileprivate static func fireRAFCallbacks(runtime: JSRuntime, timestamp: Double) {
        // Snapshot and clear callbacks using shared helper (RAF is one-shot)
        let callbacks = SharedJSPolyfills.drainRAFCallbacks()

        guard !callbacks.isEmpty else {
            // No pending callbacks — stop the display link
            displayLink?.invalidate()
            displayLink = nil
            return
        }

        runtime.jsQueue.async { [weak runtime] in
            guard let runtime = runtime, let context = runtime.context else { return }

            for (_, callback) in callbacks {
                if !callback.isUndefined {
                    callback.call(withArguments: [timestamp])
                }
            }

            // Drain microtasks after all RAF callbacks
            context.evaluateScript("void 0;")

            // If no more callbacks pending, stop the display link
            if !SharedJSPolyfills.hasRAFCallbacks {
                DispatchQueue.main.async {
                    displayLink?.invalidate()
                    displayLink = nil
                }
            }
        }
    }
}

// MARK: - DisplayLinkTarget

/// Separate NSObject target for CADisplayLink to avoid retain cycles with JSRuntime.
private final class DisplayLinkTarget: NSObject {
    private weak var runtime: JSRuntime?

    init(runtime: JSRuntime) {
        self.runtime = runtime
        super.init()
    }

    @objc func handleFrame(_ link: CADisplayLink) {
        guard let runtime = runtime else {
            link.invalidate()
            return
        }
        let timestamp = link.timestamp * 1000.0 // Convert to milliseconds
        IOSRAFHelper.fireRAFCallbacks(runtime: runtime, timestamp: timestamp)
    }
}
#endif
