#if canImport(UIKit)
import UIKit
import CoreLocation

/// Native module for GPS/location access.
///
/// Methods:
///   - getCurrentPosition() -> location payload
///   - watchPosition() -> watchId (Int); fires "location:update" global events
///   - clearWatch(watchId: Int)
///
/// Location payload keys: latitude, longitude, altitude, accuracy,
///                        altitudeAccuracy, heading, speed, timestamp
final class GeolocationModule: NativeModule {
    var moduleName: String { "Geolocation" }
    private weak var bridge: NativeBridge?

    init(bridge: NativeBridge) { self.bridge = bridge }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "getCurrentPosition":
            DispatchQueue.main.async {
                GeolocationManager.shared.getCurrentPosition(callback: callback)
            }
        case "watchPosition":
            let weakBridge = bridge
            DispatchQueue.main.async {
                let watchId = GeolocationManager.shared.watchPosition(bridge: weakBridge)
                callback(watchId, nil)
            }
        case "clearWatch":
            guard let watchId = args.first.flatMap({ $0 as? Int }) else {
                callback(nil, nil); return
            }
            DispatchQueue.main.async {
                GeolocationManager.shared.clearWatch(watchId)
                callback(nil, nil)
            }
        default:
            callback(nil, "GeolocationModule: Unknown method '\(method)'")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}

// MARK: - Internal location manager

/// All CLLocationManager interactions happen on @MainActor (main thread),
/// matching the UIKit + CoreLocation threading requirement.
@MainActor
private final class GeolocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = GeolocationManager()

    private var manager: CLLocationManager?
    private var pendingCallbacks: [(Any?, String?) -> Void] = []

    // Map watchId -> weak bridge reference
    private struct WeakBridge { weak var bridge: NativeBridge? }
    private var watchCallbacks: [Int: WeakBridge] = [:]
    private var nextWatchId = 1

    // MARK: Setup

    private func ensureManager() {
        guard manager == nil else { return }
        let mgr = CLLocationManager()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyBest
        manager = mgr
    }

    // MARK: Public interface (called on main thread)

    func getCurrentPosition(callback: @escaping (Any?, String?) -> Void) {
        ensureManager()
        guard let manager = manager else {
            callback(nil, "Failed to initialize location manager"); return
        }
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            callback(nil, "Location permission not granted"); return
        }
        pendingCallbacks.append(callback)
        manager.requestLocation()
    }

    func watchPosition(bridge: NativeBridge?) -> Int {
        ensureManager()
        guard let manager = manager else {
            return -1
        }
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            // Return a sentinel; caller will get no updates
            return -1
        }
        let watchId = nextWatchId; nextWatchId += 1
        watchCallbacks[watchId] = WeakBridge(bridge: bridge)
        manager.startUpdatingLocation()
        return watchId
    }

    func clearWatch(_ watchId: Int) {
        watchCallbacks.removeValue(forKey: watchId)
        if watchCallbacks.isEmpty {
            manager?.stopUpdatingLocation()
        }
    }

    // MARK: CLLocationManagerDelegate
    // nonisolated required by protocol; we hop to @MainActor via Task.

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let payload: [String: Any] = [
            "latitude": loc.coordinate.latitude,
            "longitude": loc.coordinate.longitude,
            "altitude": loc.altitude,
            "accuracy": loc.horizontalAccuracy,
            "altitudeAccuracy": loc.verticalAccuracy,
            "heading": loc.course,
            "speed": loc.speed,
            "timestamp": loc.timestamp.timeIntervalSince1970 * 1000
        ]
        Task { @MainActor in
            // Fire one-shot callbacks
            let cbs = self.pendingCallbacks
            self.pendingCallbacks.removeAll()
            for cb in cbs { cb(payload, nil) }
            // Fire watch callbacks
            for (_, wb) in self.watchCallbacks {
                wb.bridge?.dispatchGlobalEvent("location:update", payload: payload)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let cbs = self.pendingCallbacks
            self.pendingCallbacks.removeAll()
            for cb in cbs { cb(nil, error.localizedDescription) }
        }
    }
}
#endif
