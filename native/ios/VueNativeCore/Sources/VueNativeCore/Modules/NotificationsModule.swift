#if canImport(UIKit)
import UIKit
import UserNotifications

/// Native module for local and remote (push) notifications.
///
/// Methods:
///   - requestPermission() -> Bool
///   - getPermissionStatus() -> "granted"|"denied"|"notDetermined"
///   - scheduleLocal(notification: Object) -> notificationId: String
///   - cancel(id: String)
///   - cancelAll()
///   - registerForPush() -> Void (registers for APNS remote notifications)
///   - getToken() -> String? (returns cached APNS device token)
///
/// Global events dispatched on bridge:
///   "notification:received" -- when a notification arrives in foreground or is tapped
///   "push:token"            -- when APNS device token is received { token }
///   "push:received"         -- when a remote push notification arrives { title, body, data }
final class NotificationsModule: NativeModule {
    var moduleName: String { "Notifications" }
    private weak var bridge: NativeBridge?

    /// Cached APNS device token (hex string)
    private var deviceToken: String?

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
        NotificationCenterDelegate.shared.onPushReceived = { payload in
            DispatchQueue.main.async {
                weakBridge?.dispatchGlobalEvent("push:received", payload: payload)
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
        case "registerForPush":
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
            callback(true, nil)
        case "getToken":
            callback(deviceToken, nil)
        default:
            callback(nil, "NotificationsModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Push token handling (called from AppDelegate)

    /// Call this from your AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
    func didRegisterForRemoteNotifications(deviceToken data: Data) {
        let token = data.map { String(format: "%02x", $0) }.joined()
        self.deviceToken = token
        DispatchQueue.main.async { [weak self] in
            self?.bridge?.dispatchGlobalEvent("push:token", payload: ["token": token])
        }
    }

    /// Call this from your AppDelegate's `application(_:didFailToRegisterForRemoteNotificationsWithError:)`
    func didFailToRegisterForRemoteNotifications(error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.bridge?.dispatchGlobalEvent("push:error", payload: [
                "message": error.localizedDescription
            ])
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
    /// Called for local notifications and tapped notifications.
    var onNotification: (([String: Any]) -> Void)?
    /// Called specifically for remote push notifications arriving in foreground.
    var onPushReceived: (([String: Any]) -> Void)?

    /// Show banners/sounds/badges even when the app is in foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let request = notification.request
        if request.trigger is UNPushNotificationTrigger {
            onPushReceived?(makePushPayload(from: request))
        } else {
            onNotification?(makePayload(from: request))
        }
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when the user taps a notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let request = response.notification.request
        if request.trigger is UNPushNotificationTrigger {
            var payload = makePushPayload(from: request)
            payload["action"] = response.actionIdentifier
            onPushReceived?(payload)
        } else {
            var payload = makePayload(from: request)
            payload["action"] = response.actionIdentifier
            onNotification?(payload)
        }
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

    private func makePushPayload(from request: UNNotificationRequest) -> [String: Any] {
        [
            "id": request.identifier,
            "title": request.content.title,
            "body": request.content.body,
            "data": request.content.userInfo,
            "remote": true
        ]
    }
}
#endif
