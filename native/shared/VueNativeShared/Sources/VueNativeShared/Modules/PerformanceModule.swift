import Foundation

/// Native module for performance profiling.
/// Tracks memory usage via task_info and bridge operation counts.
/// Dispatches `perf:metrics` global events every 1 second while profiling is active.
///
/// NOTE: FPS tracking is platform-specific (requires CADisplayLink on iOS,
/// CVDisplayLink or CADisplayLink on macOS). This shared module reports FPS as 0
/// unless a platform-specific subclass or wrapper provides it.
/// Platforms can set `fpsProvider` to supply real-time FPS data.
public final class PerformanceModule: NSObject, NativeModule {

    public let moduleName = "Performance"

    private weak var eventDispatcher: NativeEventDispatcher?
    private var isProfiling = false

    // Metrics timer
    private var metricsTimer: Timer?

    // Bridge operation count
    private var bridgeOpsCount: Int = 0

    /// Optional FPS provider. Platform-specific code sets this to a closure
    /// that returns the current FPS reading (e.g., from CADisplayLink).
    public var fpsProvider: (() -> Double)?

    public init(eventDispatcher: NativeEventDispatcher) {
        self.eventDispatcher = eventDispatcher
        super.init()
    }

    public func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "startProfiling":
            startProfiling(callback: callback)
        case "stopProfiling":
            stopProfiling(callback: callback)
        case "getMetrics":
            let metrics = collectMetrics()
            callback(metrics, nil)
        default:
            callback(nil, "PerformanceModule: unknown method '\(method)'")
        }
    }

    // MARK: - Start / Stop

    private func startProfiling(callback: @escaping (Any?, String?) -> Void) {
        guard !isProfiling else { callback(true, nil); return }
        isProfiling = true
        bridgeOpsCount = 0

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Timer for periodic metrics dispatch (every 1 second)
            self.metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.dispatchMetrics()
            }

            callback(true, nil)
        }
    }

    private func stopProfiling(callback: @escaping (Any?, String?) -> Void) {
        guard isProfiling else { callback(true, nil); return }
        isProfiling = false

        DispatchQueue.main.async { [weak self] in
            self?.metricsTimer?.invalidate()
            self?.metricsTimer = nil
            callback(true, nil)
        }
    }

    // MARK: - Metrics collection

    private func collectMetrics() -> [String: Any] {
        let fps = fpsProvider?() ?? 0
        return [
            "fps": round(fps * 10) / 10,
            "memoryMB": getMemoryUsageMB(),
            "bridgeOps": bridgeOpsCount,
            "timestamp": Date().timeIntervalSince1970 * 1000,
        ]
    }

    private func dispatchMetrics() {
        guard isProfiling else { return }
        bridgeOpsCount += 1 // Count the metrics dispatch itself
        let metrics = collectMetrics()
        DispatchQueue.main.async { [weak self] in
            self?.eventDispatcher?.dispatchGlobalEvent("perf:metrics", payload: metrics)
        }
    }

    // MARK: - Memory measurement

    private func getMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024)
        }
        return 0
    }
}
