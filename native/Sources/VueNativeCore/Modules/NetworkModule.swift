#if canImport(UIKit)
import Network
import Foundation

/// Monitors network connectivity and pushes changes to JS via global events.
/// Use: NativeBridge.shared.dispatchGlobalEvent("network:change", payload: [...])
final class NetworkModule: NativeModule {
    var moduleName: String { "Network" }

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "vue-native.network")
    private weak var bridge: NativeBridge?

    init(bridge: NativeBridge) {
        self.bridge = bridge
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            let connectionType: String
            if path.usesInterfaceType(.wifi) {
                connectionType = "wifi"
            } else if path.usesInterfaceType(.cellular) {
                connectionType = "cellular"
            } else if path.usesInterfaceType(.wiredEthernet) {
                connectionType = "ethernet"
            } else {
                connectionType = "none"
            }
            let bridge = self?.bridge
            // dispatchGlobalEvent is @MainActor-isolated — dispatch to main queue
            DispatchQueue.main.async {
                bridge?.dispatchGlobalEvent("network:change", payload: [
                    "isConnected": isConnected,
                    "connectionType": connectionType
                ])
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "getStatus":
            let path = monitor.currentPath
            let isConnected = path.status == .satisfied
            let connectionType: String
            if path.usesInterfaceType(.wifi) { connectionType = "wifi" }
            else if path.usesInterfaceType(.cellular) { connectionType = "cellular" }
            else if path.usesInterfaceType(.wiredEthernet) { connectionType = "ethernet" }
            else { connectionType = "none" }
            callback(["isConnected": isConnected, "connectionType": connectionType], nil)
        default:
            callback(nil, "Unknown method: \(method)")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
#endif
