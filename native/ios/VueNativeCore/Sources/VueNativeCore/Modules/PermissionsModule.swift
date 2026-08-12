#if canImport(UIKit)
import UIKit
import AVFoundation
import Photos
import CoreLocation
import UserNotifications
import Contacts
import EventKit

/// Native module for checking and requesting system permissions.
///
/// Supported permissions: "camera", "microphone", "photos", "location",
///                        "locationAlways", "notifications", "contacts", "calendar"
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
        case "contacts":
            callback(PermissionsModule.statusString(contactsStatus: CNContactStore.authorizationStatus(for: .contacts)), nil)
        case "calendar":
            callback(PermissionsModule.statusString(calendarStatus: EKEventStore.authorizationStatus(for: .event)), nil)
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
        case "contacts":
            // `requestAccess`'s `granted` bool collapses the iOS 18 `.limited`
            // outcome into a boolean, so re-check the authorization status
            // afterward rather than trusting it directly.
            CNContactStore().requestAccess(for: .contacts) { _, _ in
                callback(PermissionsModule.statusString(contactsStatus: CNContactStore.authorizationStatus(for: .contacts)), nil)
            }
        case "calendar":
            requestCalendarAccess(callback: callback)
        default:
            callback("notDetermined", nil)
        }
    }

    /// `EKEventStore`'s iOS 17+ API only requests *full* access, so a
    /// user picking write-only access still reports `granted == false`; the
    /// authorization status is re-checked afterward (like `contacts` above)
    /// to recover the accurate `"limited"` outcome.
    private func requestCalendarAccess(callback: @escaping (Any?, String?) -> Void) {
        let store = EKEventStore()
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { _, _ in
                callback(PermissionsModule.statusString(calendarStatus: EKEventStore.authorizationStatus(for: .event)), nil)
            }
        } else {
            store.requestAccess(to: .event) { _, _ in
                callback(PermissionsModule.statusString(calendarStatus: EKEventStore.authorizationStatus(for: .event)), nil)
            }
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

    /// Maps `CNAuthorizationStatus` to the shared `PermissionStatus` contract.
    /// `.limited` was added in iOS 18 and has no macOS equivalent, so it is
    /// only referenced under an availability check. Not `private` (unlike the
    /// other `statusString` helpers above) so it is unit-testable without
    /// touching the Contacts framework.
    static func statusString(contactsStatus status: CNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "granted"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        default:
            // `.limited` (iOS 18+) is compile-time visible but availability-
            // gated, so the compiler treats it as "not one of the cases
            // above" even inside `@unknown default:` and warns about it as
            // an unhandled known case; a plain `default:` sidesteps that
            // false positive while still handling it correctly at runtime.
            if #available(iOS 18.0, *), status == .limited {
                return "limited"
            }
            return "notDetermined"
        }
    }

    /// Maps `EKAuthorizationStatus` to the shared `PermissionStatus` contract.
    /// iOS 17+ reports granular access via `.fullAccess`/`.writeOnly`;
    /// earlier versions only ever report the coarse (now-deprecated)
    /// `.authorized`. Not `private` so it is unit-testable without touching
    /// EventKit.
    static func statusString(calendarStatus status: EKAuthorizationStatus) -> String {
        if #available(iOS 17.0, *) {
            switch status {
            case .fullAccess: return "granted"
            case .writeOnly: return "limited"
            case .restricted: return "restricted"
            case .denied: return "denied"
            case .notDetermined: return "notDetermined"
            @unknown default: return "notDetermined"
            }
        }
        switch status {
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        default: return "granted" // legacy `.authorized` (pre-iOS 17)
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
