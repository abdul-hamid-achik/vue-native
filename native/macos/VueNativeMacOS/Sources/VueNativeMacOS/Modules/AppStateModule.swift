import AppKit
import VueNativeShared

/// Native module providing application lifecycle state notifications.
///
/// Events dispatched:
///   - appState:change { state: "active"|"inactive"|"background" }
///
/// Methods:
///   - getState() -> String
final class AppStateModule: NSObject, NativeModule {
    var moduleName: String { "AppState" }
    private weak var dispatcher: NativeEventDispatcher?
    private var observers: [NSObjectProtocol] = []

    init(dispatcher: NativeEventDispatcher) {
        self.dispatcher = dispatcher
        super.init()
        setupObservers()
    }

    private func setupObservers() {
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.dispatcher?.dispatchGlobalEvent("appState:change", payload: ["state": "active"])
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.dispatcher?.dispatchGlobalEvent("appState:change", payload: ["state": "inactive"])
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didHideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.dispatcher?.dispatchGlobalEvent("appState:change", payload: ["state": "background"])
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didUnhideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.dispatcher?.dispatchGlobalEvent("appState:change", payload: ["state": "active"])
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "getState":
            DispatchQueue.main.async {
                let state = NSApp.isActive ? "active" : "inactive"
                callback(state, nil)
            }
        default:
            callback(nil, "AppStateModule: Unknown method '\(method)'")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
