import UserNotifications
import AppKit
import VueNativeShared

/// Native module providing local notification access on macOS.
///
/// Methods:
///   - requestPermission() -> Bool
///   - getPermissionStatus() -> "granted"/"denied"/"notDetermined"
///   - scheduleLocal(options) -> id
///   - cancelAll()
///   - cancel(id)
///   - getBadgeCount() -> String?
///   - setBadgeCount(count)
final class NotificationsModule: NativeModule {
    let moduleName = "Notifications"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "requestPermission":
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    callback(nil, "Notification permission error: \(error.localizedDescription)")
                } else {
                    callback(granted, nil)
                }
            }

        case "getPermissionStatus", "checkPermission":
            let center = UNUserNotificationCenter.current()
            center.getNotificationSettings { settings in
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

        case "scheduleLocal":
            let center = UNUserNotificationCenter.current()
            guard let options = args.first as? [String: Any] else {
                callback(nil, "scheduleLocal: expected notification options")
                return
            }
            let title = options["title"] as? String ?? ""
            let body = options["body"] as? String ?? ""
            let delay = options["delay"] as? Double ?? 0.1

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            if options["sound"] as? String == "default" {
                content.sound = .default
            }
            if let badge = options["badge"] as? Int {
                content.badge = NSNumber(value: badge)
            }
            if let data = options["data"] as? [String: Any] {
                content.userInfo = data
            }

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(delay, 0.1),
                repeats: false
            )

            let requestId = options["id"] as? String ?? UUID().uuidString
            let request = UNNotificationRequest(
                identifier: requestId,
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error = error {
                    callback(nil, "Schedule error: \(error.localizedDescription)")
                } else {
                    callback(requestId, nil)
                }
            }

        case "cancelAll":
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            callback(nil, nil)

        case "cancel":
            let center = UNUserNotificationCenter.current()
            guard let identifier = args.first as? String else {
                callback(nil, "cancel: missing notification id")
                return
            }
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            callback(nil, nil)

        case "registerForPush":
            callback(nil, "Remote push registration is not provided by Vue Native on macOS")

        case "getToken":
            callback(nil, nil)

        case "getBadgeCount":
            DispatchQueue.main.async {
                let badge = NSApplication.shared.dockTile.badgeLabel
                callback(badge, nil)
            }

        case "setBadgeCount":
            let count = args.first
            DispatchQueue.main.async {
                if let num = count as? Int {
                    NSApplication.shared.dockTile.badgeLabel = num == 0 ? nil : String(num)
                } else if let str = count as? String {
                    NSApplication.shared.dockTile.badgeLabel = str.isEmpty ? nil : str
                } else {
                    NSApplication.shared.dockTile.badgeLabel = nil
                }
                callback(nil, nil)
            }

        default:
            callback(nil, "NotificationsModule: Unknown method '\(method)'")
        }
    }
}
