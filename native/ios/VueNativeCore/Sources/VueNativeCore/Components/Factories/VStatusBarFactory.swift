#if canImport(UIKit)
import UIKit
import ObjectiveC

/// Notification contract between `VStatusBarFactory` and the host view controller.
///
/// A standalone nonisolated enum rather than statics on the `@MainActor` factory so
/// the host's `@Sendable` `NotificationCenter` observer blocks can read the names and
/// keys without a main-actor hop (which would warn, and error under Swift 6).
enum VStatusBarNotification {
    /// Posted when `barStyle` changes. `userInfo` carries ``styleKey`` (String:
    /// `"default"` / `"light-content"` / `"dark-content"`) and ``animatedKey`` (Bool).
    static let styleChange = Notification.Name("VueNativeStatusBarStyleChange")

    /// Posted when `hidden` changes. `userInfo` carries ``hiddenKey`` (Bool) and
    /// ``animatedKey`` (Bool).
    static let hiddenChange = Notification.Name("VueNativeStatusBarHiddenChange")

    /// `userInfo` key for the raw `barStyle` string.
    static let styleKey = "style"
    /// `userInfo` key for the `hidden` flag.
    static let hiddenKey = "hidden"
    /// `userInfo` key for the `animated` flag. Present on both notifications so a
    /// host can pick `.slide` vs `.none` for `preferredStatusBarUpdateAnimation`.
    static let animatedKey = "animated"
}

/// Factory for VStatusBar — a zero-size, hidden placeholder view that controls
/// the system status bar appearance by posting notifications to the root
/// view controller, which observes them to update its `preferredStatusBarStyle`,
/// `prefersStatusBarHidden`, and `preferredStatusBarUpdateAnimation` overrides
/// (see `VueNativeViewController.installStatusBarObservers()`).
///
/// UIKit reads status-bar appearance only from the view controller, so the
/// notifications are the transport: a component with no view controller of its
/// own cannot change the bar directly.
@MainActor
final class VStatusBarFactory: NativeComponentFactory {

    /// Per-view storage for the `animated` prop, so a later `barStyle`/`hidden`
    /// update can report the animation preference regardless of prop arrival order.
    private static var animatedStorageKey: UInt8 = 0

    /// Map the TS `StatusBarStyle` union onto `UIStatusBarStyle`.
    /// Exposed for unit testing without posting notifications.
    static func uiStyle(for barStyle: String) -> UIStatusBarStyle {
        switch barStyle {
        case "light-content": return .lightContent
        case "dark-content": return .darkContent
        default: return .default
        }
    }

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let v = UIView()
        v.isHidden = true
        return v
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        switch key {
        case "animated":
            // `animated` is declared in the TS component and documented, so honour it
            // rather than dropping it: remember it here and include it in the next
            // style/hidden notification.
            let animated = Self.boolValue(value) ?? true
            objc_setAssociatedObject(
                view,
                &VStatusBarFactory.animatedStorageKey,
                animated as NSNumber,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "barStyle":
            guard let style = value as? String else { return }
            NotificationCenter.default.post(
                name: VStatusBarNotification.styleChange,
                object: nil,
                userInfo: [
                    VStatusBarNotification.styleKey: style,
                    VStatusBarNotification.animatedKey: Self.isAnimated(view),
                ]
            )

        case "hidden":
            let hidden = Self.boolValue(value) ?? false
            NotificationCenter.default.post(
                name: VStatusBarNotification.hiddenChange,
                object: nil,
                userInfo: [
                    VStatusBarNotification.hiddenKey: hidden,
                    VStatusBarNotification.animatedKey: Self.isAnimated(view),
                ]
            )

        default:
            break
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        // VStatusBar emits no events
    }

    func removeEventListener(view: UIView, event: String) {
        // VStatusBar emits no events
    }

    // MARK: - Private helpers

    /// The `animated` prop defaults to `true` in the TS component definition.
    private static func isAnimated(_ view: UIView) -> Bool {
        guard let stored = objc_getAssociatedObject(view, &animatedStorageKey) as? NSNumber else {
            return true
        }
        return stored.boolValue
    }

    /// Coerce the several shapes a JS boolean can arrive as through the JSON bridge.
    private static func boolValue(_ value: Any?) -> Bool? {
        if let boolValue = value as? Bool { return boolValue }
        if let numberValue = value as? NSNumber { return numberValue.boolValue }
        if let intValue = value as? Int { return intValue != 0 }
        return nil
    }
}
#endif
