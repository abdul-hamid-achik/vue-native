import AVFoundation
import UserNotifications
import CoreLocation
import Contacts
import EventKit
import VueNativeShared

/// Native module for checking and requesting system permissions on macOS.
///
/// Methods:
///   - check(type: String) -> "granted"/"denied"/"restricted"/"limited"/"notDetermined"
///   - request(type: String) -> "granted"/"denied"/"restricted"/"limited"/"notDetermined"
///
/// Supported permission types: "camera", "microphone", "notifications", "location",
///                              "contacts", "calendar"
final class PermissionsModule: NativeModule {
    let moduleName = "Permissions"

    private lazy var locationManager = CLLocationManager()

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let permissionType = args.first as? String else {
            callback(nil, "PermissionsModule: missing permission type argument")
            return
        }

        switch method {
        case "check":
            checkPermission(type: permissionType, callback: callback)

        case "request":
            requestPermission(type: permissionType, callback: callback)

        default:
            callback(nil, "PermissionsModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Check

    private func checkPermission(type: String, callback: @escaping (Any?, String?) -> Void) {
        switch type {
        case "camera":
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            callback(mapAVStatus(status), nil)

        case "microphone":
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            callback(mapAVStatus(status), nil)

        case "notifications":
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let result: String
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    result = "granted"
                case .denied:
                    result = "denied"
                case .notDetermined:
                    result = "notDetermined"
                @unknown default:
                    result = "notDetermined"
                }
                callback(result, nil)
            }

        case "location":
            let status: CLAuthorizationStatus
            status = locationManager.authorizationStatus
            callback(mapCLStatus(status), nil)

        case "contacts":
            callback(PermissionsModule.mapContactsStatus(CNContactStore.authorizationStatus(for: .contacts)), nil)

        case "calendar":
            callback(PermissionsModule.mapCalendarStatus(EKEventStore.authorizationStatus(for: .event)), nil)

        default:
            callback(nil, "PermissionsModule: Unsupported permission type '\(type)'")
        }
    }

    // MARK: - Request

    private func requestPermission(type: String, callback: @escaping (Any?, String?) -> Void) {
        switch type {
        case "camera":
            AVCaptureDevice.requestAccess(for: .video) { granted in
                callback(granted ? "granted" : "denied", nil)
            }

        case "microphone":
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                callback(granted ? "granted" : "denied", nil)
            }

        case "notifications":
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, _ in
                callback(granted ? "granted" : "denied", nil)
            }

        case "location":
            locationManager.requestWhenInUseAuthorization()
            // CLLocationManager doesn't provide a completion handler.
            // Return current status; JS side should re-check after a delay.
            let status = locationManager.authorizationStatus
            callback(mapCLStatus(status), nil)

        case "contacts":
            // `requestAccess`'s `granted` bool collapses the iOS 18 `.limited`
            // outcome (not exposed on macOS today, but kept consistent with
            // the iOS module) into a boolean, so re-check the authorization
            // status afterward rather than trusting it directly.
            CNContactStore().requestAccess(for: .contacts) { _, _ in
                callback(PermissionsModule.mapContactsStatus(CNContactStore.authorizationStatus(for: .contacts)), nil)
            }

        case "calendar":
            requestCalendarAccess(callback: callback)

        default:
            callback(nil, "PermissionsModule: Unsupported permission type '\(type)'")
        }
    }

    /// macOS 14+'s full-access API only requests *full* access, so a user
    /// picking write-only access still reports `granted == false`; the
    /// authorization status is re-checked afterward (like `contacts` above)
    /// to recover the accurate `"limited"` outcome.
    private func requestCalendarAccess(callback: @escaping (Any?, String?) -> Void) {
        let store = EKEventStore()
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { _, _ in
                callback(PermissionsModule.mapCalendarStatus(EKEventStore.authorizationStatus(for: .event)), nil)
            }
        } else {
            store.requestAccess(to: .event) { _, _ in
                callback(PermissionsModule.mapCalendarStatus(EKEventStore.authorizationStatus(for: .event)), nil)
            }
        }
    }

    // MARK: - Helpers

    private func mapAVStatus(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "granted"
        case .denied, .restricted: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    private func mapCLStatus(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways:
            return "granted"
        case .denied, .restricted:
            return "denied"
        case .notDetermined:
            return "notDetermined"
        @unknown default:
            return "notDetermined"
        }
    }

    /// Maps `CNAuthorizationStatus` to the shared `PermissionStatus` contract.
    /// Unlike iOS, `.limited` is `@available(macOS, unavailable)` on this SDK
    /// -- macOS has no equivalent to iOS 18's limited-contacts picker -- so it
    /// is intentionally absent here. Not `private` (unlike `mapAVStatus`/
    /// `mapCLStatus` above) so it is unit-testable without touching Contacts.
    static func mapContactsStatus(_ status: CNAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "granted"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    /// Maps `EKAuthorizationStatus` to the shared `PermissionStatus` contract.
    /// macOS 14+ reports granular access via `.fullAccess`/`.writeOnly`;
    /// earlier versions only ever report the coarse (now-deprecated)
    /// `.authorized`. Not `private` so it is unit-testable without touching
    /// EventKit.
    static func mapCalendarStatus(_ status: EKAuthorizationStatus) -> String {
        if #available(macOS 14.0, *) {
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
        default: return "granted" // legacy `.authorized` (pre-macOS 14)
        }
    }
}
