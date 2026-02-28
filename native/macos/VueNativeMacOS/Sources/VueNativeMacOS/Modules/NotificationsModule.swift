import UserNotifications
import AppKit
import VueNativeShared

/// Native module providing local notification access on macOS.
///
/// Methods:
///   - requestPermission() -> Bool
///   - checkPermission() -> "granted"/"denied"/"notDetermined"
///   - scheduleLocal(title, body, delay) -> { id }
///   - cancelAll()
///   - cancel(id)
///   - getBadgeCount() -> String?
///   - setBadgeCount(count)
final class NotificationsModule: NativeModule {
    let moduleName = "Notifications"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        let center = UNUserNotificationCenter.current()

        switch method {
        case "requestPermission":
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    callback(nil, "Notification permission error: \(error.localizedDescription)")
                } else {
                    callback(granted, nil)
                }
            }

        case "checkPermission":
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
            let title = args.count > 0 ? (args[0] as? String ?? "") : ""
            let body = args.count > 1 ? (args[1] as? String ?? "") : ""
            let delay = args.count > 2 ? (args[2] as? Double ?? 1.0) : 1.0

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(delay, 0.1),
                repeats: false
            )

            let requestId = UUID().uuidString
            let request = UNNotificationRequest(
                identifier: requestId,
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error = error {
                    callback(nil, "Schedule error: \(error.localizedDescription)")
                } else {
                    callback(["id": requestId], nil)
                }
            }

        case "cancelAll":
            center.removeAllPendingNotificationRequests()
            callback(nil, nil)

        case "cancel":
            guard let identifier = args.first as? String else {
                callback(nil, "cancel: missing notification id")
                return
            }
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
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
