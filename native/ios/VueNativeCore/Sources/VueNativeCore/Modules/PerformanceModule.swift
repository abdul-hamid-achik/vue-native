#if canImport(UIKit)
import UIKit

/// Native module for performance profiling.
/// Tracks FPS via CADisplayLink, memory usage via task_info, and bridge operation counts.
/// Dispatches `perf:metrics` global events every 1 second while profiling is active.
final class PerformanceModule: NativeModule {

    let moduleName = "Performance"

    private weak var bridge: NativeBridge?
    private var displayLink: CADisplayLink?
    private var isProfiling = false

    // FPS tracking
    private var frameCount = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var currentFPS: Double = 0

    // Metrics timer
    private var metricsTimer: Timer?

    // Bridge operation count
    private var bridgeOpsCount: Int = 0

    init(bridge: NativeBridge) {
        self.bridge = bridge
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
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
        frameCount = 0
        lastTimestamp = 0
        currentFPS = 0
        bridgeOpsCount = 0

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // CADisplayLink for FPS measurement
            let link = CADisplayLink(target: self, selector: #selector(self.handleDisplayLink(_:)))
            link.add(to: .main, forMode: .common)
            self.displayLink = link

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
            self?.displayLink?.invalidate()
            self?.displayLink = nil
            self?.metricsTimer?.invalidate()
            self?.metricsTimer = nil
            callback(true, nil)
        }
    }

    // MARK: - CADisplayLink handler

    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            frameCount = 0
            return
        }

        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp

        // Calculate FPS every 0.5 seconds for smoother readings
        if elapsed >= 0.5 {
            currentFPS = Double(frameCount) / elapsed
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }

    // MARK: - Metrics collection

    private func collectMetrics() -> [String: Any] {
        return [
            "fps": round(currentFPS * 10) / 10,
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
            self?.bridge?.dispatchGlobalEvent("perf:metrics", payload: metrics)
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
#endif
