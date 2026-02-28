import AVFoundation
import UserNotifications
import CoreLocation
import Contacts
import VueNativeShared

/// Native module for checking and requesting system permissions on macOS.
///
/// Methods:
///   - check(type: String) -> "granted"/"denied"/"undetermined"
///   - request(type: String) -> "granted"/"denied"
///
/// Supported permission types: "camera", "microphone", "notifications", "location", "contacts"
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
                    result = "undetermined"
                @unknown default:
                    result = "undetermined"
                }
                callback(result, nil)
            }

        case "location":
            let status: CLAuthorizationStatus
            status = locationManager.authorizationStatus
            callback(mapCLStatus(status), nil)

        case "contacts":
            let status = CNContactStore.authorizationStatus(for: .contacts)
            switch status {
            case .authorized:
                callback("granted", nil)
            case .denied, .restricted:
                callback("denied", nil)
            case .notDetermined:
                callback("undetermined", nil)
            @unknown default:
                callback("undetermined", nil)
            }

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
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                callback(granted ? "granted" : "denied", nil)
            }

        default:
            callback(nil, "PermissionsModule: Unsupported permission type '\(type)'")
        }
    }

    // MARK: - Helpers

    private func mapAVStatus(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "granted"
        case .denied, .restricted: return "denied"
        case .notDetermined: return "undetermined"
        @unknown default: return "undetermined"
        }
    }

    private func mapCLStatus(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways:
            return "granted"
        case .denied, .restricted:
            return "denied"
        case .notDetermined:
            return "undetermined"
        @unknown default:
            return "undetermined"
        }
    }
}
