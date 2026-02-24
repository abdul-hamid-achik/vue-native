#if canImport(UIKit)
import UIKit

final class AppStateModule: NSObject, NativeModule {
    var moduleName: String { "AppState" }
    private weak var bridge: NativeBridge?
    private var observers: [NSObjectProtocol] = []

    init(bridge: NativeBridge) {
        self.bridge = bridge
        super.init()
        setupObservers()
    }

    private func setupObservers() {
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.bridge?.dispatchGlobalEvent("appState:change", payload: ["state": "active"])
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.bridge?.dispatchGlobalEvent("appState:change", payload: ["state": "inactive"])
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.bridge?.dispatchGlobalEvent("appState:change", payload: ["state": "background"])
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "getState":
            let bridge = bridge
            DispatchQueue.main.async {
                let state: String
                switch UIApplication.shared.applicationState {
                case .active: state = "active"
                case .inactive: state = "inactive"
                case .background: state = "background"
                @unknown default: state = "unknown"
                }
                bridge?.dispatchGlobalEvent("appState:change", payload: ["state": state])
                callback(state, nil)
            }
        default:
            callback(nil, "Unknown method: \(method)")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
#endif
