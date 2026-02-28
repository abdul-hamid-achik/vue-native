import Network
import Foundation

/// Monitors network connectivity and pushes changes to JS via global events.
/// Uses NativeEventDispatcher protocol instead of a concrete bridge type.
public final class NetworkModule: NativeModule {
    public var moduleName: String { "Network" }

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "vue-native.network")
    private weak var eventDispatcher: NativeEventDispatcher?

    public init(eventDispatcher: NativeEventDispatcher) {
        self.eventDispatcher = eventDispatcher
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
            let dispatcher = self?.eventDispatcher
            DispatchQueue.main.async {
                dispatcher?.dispatchGlobalEvent("network:change", payload: [
                    "isConnected": isConnected,
                    "connectionType": connectionType
                ])
            }
        }
        monitor.start(queue: monitorQueue)
    }

    public func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
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

    public func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
