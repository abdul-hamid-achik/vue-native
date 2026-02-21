#if canImport(UIKit)
import UIKit

final class AppStateModule: NativeModule {
    var moduleName: String { "AppState" }
    private weak var bridge: NativeBridge?

    init(bridge: NativeBridge) {
        self.bridge = bridge
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc private func didBecomeActive() {
        let bridge = bridge
        DispatchQueue.main.async {
            bridge?.dispatchGlobalEvent("appState:change", payload: ["state": "active"])
        }
    }

    @objc private func willResignActive() {
        let bridge = bridge
        DispatchQueue.main.async {
            bridge?.dispatchGlobalEvent("appState:change", payload: ["state": "inactive"])
        }
    }

    @objc private func didEnterBackground() {
        let bridge = bridge
        DispatchQueue.main.async {
            bridge?.dispatchGlobalEvent("appState:change", payload: ["state": "background"])
        }
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
