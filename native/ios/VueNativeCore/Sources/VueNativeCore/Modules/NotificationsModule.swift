#if canImport(UIKit)
import UIKit
import UserNotifications

/// Native module for local (and foreground push) notifications.
///
/// Methods:
///   - requestPermission() -> Bool
///   - getPermissionStatus() -> "granted"|"denied"|"notDetermined"
///   - scheduleLocal(notification: Object) -> notificationId: String
///   - cancel(id: String)
///   - cancelAll()
///
/// Global events dispatched on bridge:
///   "notification:received" -- when a notification arrives in foreground or is tapped
final class NotificationsModule: NativeModule {
    var moduleName: String { "Notifications" }
    private weak var bridge: NativeBridge?

    init(bridge: NativeBridge) {
        self.bridge = bridge
        setupForegroundHandler()
    }

    private func setupForegroundHandler() {
        UNUserNotificationCenter.current().delegate = NotificationCenterDelegate.shared
        // Capture bridge weakly; dispatch to main actor because dispatchGlobalEvent is @MainActor.
        let weakBridge = bridge
        NotificationCenterDelegate.shared.onNotification = { payload in
            DispatchQueue.main.async {
                weakBridge?.dispatchGlobalEvent("notification:received", payload: payload)
            }
        }
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "requestPermission":
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                callback(granted, error?.localizedDescription)
            }
        case "getPermissionStatus":
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                callback(self.statusString(settings.authorizationStatus), nil)
            }
        case "scheduleLocal":
            guard let notification = args.first as? [String: Any] else {
                callback(nil, "NotificationsModule: invalid notification object"); return
            }
            scheduleLocal(notification, callback: callback)
        case "cancel":
            if let id = args.first as? String {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            }
            callback(nil, nil)
        case "cancelAll":
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            callback(nil, nil)
        default:
            callback(nil, "NotificationsModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Schedule local notification

    private func scheduleLocal(_ notification: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        let content = UNMutableNotificationContent()
        content.title = notification["title"] as? String ?? ""
        content.body = notification["body"] as? String ?? ""

        if let sound = notification["sound"] as? String, sound == "default" {
            content.sound = .default
        }
        if let badge = notification["badge"] as? Int {
            content.badge = NSNumber(value: badge)
        }
        if let data = notification["data"] as? [String: Any] {
            content.userInfo = data
        }

        let delay = max((notification["delay"] as? Double) ?? 0.1, 0.1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let id = (notification["id"] as? String) ?? UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                callback(nil, error.localizedDescription)
            } else {
                callback(id, nil)
            }
        }
    }

    // MARK: - Status helper

    private func statusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "granted"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "notDetermined"
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}

// MARK: - UNUserNotificationCenterDelegate

/// Singleton delegate that forwards foreground and tapped notifications
/// to whoever has set `onNotification`.
private final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterDelegate()
    /// Called from delegate methods (arbitrary queue). Callers are responsible
    /// for dispatching to the correct actor/queue before touching UI or bridge.
    var onNotification: (([String: Any]) -> Void)?

    /// Show banners/sounds/badges even when the app is in foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        onNotification?(makePayload(from: notification.request))
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when the user taps a notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        var payload = makePayload(from: response.notification.request)
        payload["action"] = response.actionIdentifier
        onNotification?(payload)
        completionHandler()
    }

    private func makePayload(from request: UNNotificationRequest) -> [String: Any] {
        [
            "id": request.identifier,
            "title": request.content.title,
            "body": request.content.body,
            "data": request.content.userInfo
        ]
    }
}
#endif
