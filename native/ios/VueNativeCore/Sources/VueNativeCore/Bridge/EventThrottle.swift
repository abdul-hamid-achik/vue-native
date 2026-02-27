#if canImport(UIKit)
import Foundation

/// Throttles high-frequency event handlers to avoid flooding the JS bridge.
///
/// When a high-frequency event (scroll, slider drag, text input) fires many
/// times per frame, each invocation becomes a bridge round-trip. This utility
/// ensures at most one call per `interval` seconds, with a trailing call
/// to deliver the latest value.
///
/// Default interval: 16ms (~60 FPS). Callers can customize via `interval`.
final class EventThrottle {

    /// Minimum time between handler invocations (seconds).
    let interval: TimeInterval

    /// The throttled handler to call.
    private let handler: (Any?) -> Void

    /// Timestamp of the last invocation.
    private var lastFireTime: CFTimeInterval = 0

    /// Whether a trailing call is pending.
    private var pendingTrailing = false

    /// The most recent payload, used for the trailing call.
    private var latestPayload: Any?

    /// Timer for delivering the trailing call.
    private var trailingTimer: DispatchSourceTimer?

    /// Create a throttled event handler.
    /// - Parameters:
    ///   - interval: Minimum seconds between invocations. Default 0.016 (~60fps).
    ///   - handler: The closure to invoke with the event payload.
    init(interval: TimeInterval = 0.016, handler: @escaping (Any?) -> Void) {
        self.interval = interval
        self.handler = handler
    }

    deinit {
        trailingTimer?.cancel()
    }

    /// Call this from the native event callback instead of the original handler.
    /// Fires immediately if enough time has elapsed, otherwise schedules a trailing call.
    func fire(_ payload: Any?) {
        let now = CACurrentMediaTime()
        let elapsed = now - lastFireTime

        latestPayload = payload

        if elapsed >= interval {
            // Enough time has passed — fire immediately
            lastFireTime = now
            pendingTrailing = false
            trailingTimer?.cancel()
            trailingTimer = nil
            handler(payload)
        } else if !pendingTrailing {
            // Schedule a trailing call for the remaining time
            pendingTrailing = true
            let remaining = interval - elapsed
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + remaining)
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.lastFireTime = CACurrentMediaTime()
                self.pendingTrailing = false
                self.trailingTimer = nil
                self.handler(self.latestPayload)
            }
            trailingTimer = timer
            timer.resume()
        }
        // If a trailing call is already pending, just update latestPayload (done above)
    }
}
#endif
