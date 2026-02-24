#if canImport(UIKit)
import CoreMotion
import Foundation

/// Native module for accelerometer and gyroscope sensor data.
/// Dispatches continuous events via bridge.dispatchGlobalEvent.
final class SensorsModule: NativeModule {
    let moduleName = "Sensors"

    private let motionManager = CMMotionManager()
    private weak var bridge: NativeBridge?
    private let queue = OperationQueue()

    init(bridge: NativeBridge) {
        self.bridge = bridge
        queue.name = "vue-native.sensors"
        queue.maxConcurrentOperationCount = 1
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "startAccelerometer":
            let interval = (args.first as? Double ?? 100) / 1000.0
            startAccelerometer(interval: interval, callback: callback)
        case "stopAccelerometer":
            stopAccelerometer(callback: callback)
        case "startGyroscope":
            let interval = (args.first as? Double ?? 100) / 1000.0
            startGyroscope(interval: interval, callback: callback)
        case "stopGyroscope":
            stopGyroscope(callback: callback)
        case "isAvailable":
            let sensorType = args.first as? String ?? "accelerometer"
            let available: Bool
            switch sensorType {
            case "gyroscope":
                available = motionManager.isGyroAvailable
            default:
                available = motionManager.isAccelerometerAvailable
            }
            callback(["available": available], nil)
        default:
            callback(nil, "SensorsModule: unknown method '\(method)'")
        }
    }

    // MARK: - Accelerometer

    private func startAccelerometer(interval: TimeInterval, callback: @escaping (Any?, String?) -> Void) {
        guard motionManager.isAccelerometerAvailable else {
            callback(nil, "Accelerometer not available on this device")
            return
        }
        motionManager.accelerometerUpdateInterval = interval
        motionManager.startAccelerometerUpdates(to: queue) { [weak self] data, error in
            guard let data = data, let bridge = self?.bridge else { return }
            if error != nil { return }
            DispatchQueue.main.async {
                bridge.dispatchGlobalEvent("sensor:accelerometer", payload: [
                    "x": data.acceleration.x,
                    "y": data.acceleration.y,
                    "z": data.acceleration.z,
                    "timestamp": data.timestamp,
                ])
            }
        }
        callback(nil, nil)
    }

    private func stopAccelerometer(callback: @escaping (Any?, String?) -> Void) {
        motionManager.stopAccelerometerUpdates()
        callback(nil, nil)
    }

    // MARK: - Gyroscope

    private func startGyroscope(interval: TimeInterval, callback: @escaping (Any?, String?) -> Void) {
        guard motionManager.isGyroAvailable else {
            callback(nil, "Gyroscope not available on this device")
            return
        }
        motionManager.gyroUpdateInterval = interval
        motionManager.startGyroUpdates(to: queue) { [weak self] data, error in
            guard let data = data, let bridge = self?.bridge else { return }
            if error != nil { return }
            DispatchQueue.main.async {
                bridge.dispatchGlobalEvent("sensor:gyroscope", payload: [
                    "x": data.rotationRate.x,
                    "y": data.rotationRate.y,
                    "z": data.rotationRate.z,
                    "timestamp": data.timestamp,
                ])
            }
        }
        callback(nil, nil)
    }

    private func stopGyroscope(callback: @escaping (Any?, String?) -> Void) {
        motionManager.stopGyroUpdates()
        callback(nil, nil)
    }
}
#endif
