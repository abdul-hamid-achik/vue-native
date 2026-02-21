#if canImport(UIKit)
import UIKit
import AVFoundation
import Photos
import CoreLocation
import UserNotifications

/// Native module for checking and requesting system permissions.
///
/// Supported permissions: "camera", "microphone", "photos", "location",
///                        "locationAlways", "notifications"
///
/// Status strings: "granted", "denied", "restricted", "limited", "notDetermined"
final class PermissionsModule: NativeModule {
    var moduleName: String { "Permissions" }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "check":
            guard let permission = args.first as? String else {
                callback(nil, "PermissionsModule: missing permission name"); return
            }
            checkPermission(permission, callback: callback)
        case "request":
            guard let permission = args.first as? String else {
                callback(nil, "PermissionsModule: missing permission name"); return
            }
            requestPermission(permission, callback: callback)
        default:
            callback(nil, "PermissionsModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Check

    private func checkPermission(_ permission: String, callback: @escaping (Any?, String?) -> Void) {
        switch permission {
        case "camera":
            callback(statusString(avStatus: AVCaptureDevice.authorizationStatus(for: .video)), nil)
        case "microphone":
            callback(statusString(avStatus: AVCaptureDevice.authorizationStatus(for: .audio)), nil)
        case "photos":
            callback(statusString(photoStatus: PHPhotoLibrary.authorizationStatus(for: .readWrite)), nil)
        case "location", "locationAlways":
            // CLLocationManager.authorizationStatus() instance method must be called on main thread.
            DispatchQueue.main.async {
                let mgr = CLLocationManager()
                callback(self.statusString(locationStatus: mgr.authorizationStatus), nil)
            }
        case "notifications":
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                callback(self.statusString(notifStatus: settings.authorizationStatus), nil)
            }
        default:
            callback("notDetermined", nil)
        }
    }

    // MARK: - Request

    private func requestPermission(_ permission: String, callback: @escaping (Any?, String?) -> Void) {
        switch permission {
        case "camera":
            AVCaptureDevice.requestAccess(for: .video) { granted in
                callback(granted ? "granted" : "denied", nil)
            }
        case "microphone":
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                callback(granted ? "granted" : "denied", nil)
            }
        case "photos":
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                callback(self.statusString(photoStatus: status), nil)
            }
        case "location":
            // LocationPermissionRequester is @MainActor — must dispatch to main.
            DispatchQueue.main.async {
                LocationPermissionRequester.shared.request(always: false, callback: callback)
            }
        case "locationAlways":
            DispatchQueue.main.async {
                LocationPermissionRequester.shared.request(always: true, callback: callback)
            }
        case "notifications":
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                callback(granted ? "granted" : "denied", nil)
            }
        default:
            callback("notDetermined", nil)
        }
    }

    // MARK: - Status helpers

    private func statusString(avStatus: AVAuthorizationStatus) -> String {
        switch avStatus {
        case .authorized: return "granted"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    private func statusString(photoStatus: PHAuthorizationStatus) -> String {
        switch photoStatus {
        case .authorized: return "granted"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        case .limited: return "limited"
        @unknown default: return "notDetermined"
        }
    }

    private func statusString(locationStatus: CLAuthorizationStatus) -> String {
        switch locationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return "granted"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    private func statusString(notifStatus: UNAuthorizationStatus) -> String {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return "granted"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}

// MARK: - Location permission helper

/// CLLocationManager must be created and used on the main thread.
/// This helper lives on @MainActor and drives the one-shot request flow.
@MainActor
private final class LocationPermissionRequester: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPermissionRequester()

    private var manager: CLLocationManager?
    private var pendingCallback: ((Any?, String?) -> Void)?

    func request(always: Bool, callback: @escaping (Any?, String?) -> Void) {
        // If already determined, return immediately without showing the system dialog.
        let probe = CLLocationManager()
        let current = probe.authorizationStatus
        if current != .notDetermined {
            callback(statusString(current), nil)
            return
        }
        pendingCallback = callback
        let mgr = CLLocationManager()
        mgr.delegate = self
        manager = mgr
        if always {
            mgr.requestAlwaysAuthorization()
        } else {
            mgr.requestWhenInUseAuthorization()
        }
    }

    private func statusString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: return "granted"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    // nonisolated because CLLocationManagerDelegate methods arrive on arbitrary threads;
    // we hop back to @MainActor via Task for state access.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            guard let cb = self.pendingCallback else { return }
            self.pendingCallback = nil
            self.manager = nil
            cb(self.statusString(status), nil)
        }
    }
}
#endif
