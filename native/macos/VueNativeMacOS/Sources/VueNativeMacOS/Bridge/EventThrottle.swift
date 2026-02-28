import Foundation
import QuartzCore

/// Throttles high-frequency event handlers to avoid flooding the JS bridge.
///
/// When a high-frequency event (scroll, slider drag, text input) fires many
/// times per frame, each invocation becomes a bridge round-trip. This utility
/// ensures at most one call per `interval` seconds, with a trailing call
/// to deliver the latest value.
///
/// Default interval: 16ms (~60 FPS).
final class EventThrottle {

    let interval: TimeInterval
    private let handler: (Any?) -> Void
    private var lastFireTime: CFTimeInterval = 0
    private var pendingTrailing = false
    private var latestPayload: Any?
    private var trailingTimer: DispatchSourceTimer?

    init(interval: TimeInterval = 0.016, handler: @escaping (Any?) -> Void) {
        self.interval = interval
        self.handler = handler
    }

    deinit {
        trailingTimer?.cancel()
    }

    func fire(_ payload: Any?) {
        let now = CACurrentMediaTime()
        let elapsed = now - lastFireTime

        latestPayload = payload

        if elapsed >= interval {
            lastFireTime = now
            pendingTrailing = false
            trailingTimer?.cancel()
            trailingTimer = nil
            handler(payload)
        } else if !pendingTrailing {
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
    }
}
