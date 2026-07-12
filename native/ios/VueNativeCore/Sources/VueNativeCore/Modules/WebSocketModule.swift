#if canImport(UIKit)
import Foundation
import VueNativeShared

/// Adapts the UIKit bridge to the shared Apple WebSocket implementation so iOS
/// and macOS use the same handshake, connection-identity, and teardown rules.
final class WebSocketModule: NativeModule {
    let moduleName = "WebSocket"

    private let dispatcher: IOSWebSocketEventDispatcher
    private let implementation: VueNativeShared.WebSocketModule

    init(bridge: NativeBridge) {
        let dispatcher = IOSWebSocketEventDispatcher(bridge: bridge)
        self.dispatcher = dispatcher
        implementation = VueNativeShared.WebSocketModule(eventDispatcher: dispatcher)
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        // Keep the platform wrapper's supported dispatch labels explicit. In
        // addition to documenting its contract, this lets the cross-language
        // contract gate verify that every runtime call is available on iOS.
        switch method {
        case "connect", "send", "close":
            implementation.invoke(method: method, args: args, callback: callback)
        default:
            callback(nil, "WebSocketModule: Unknown method '\(method)'")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? {
        implementation.invokeSync(method: method, args: args)
    }

    func destroy() {
        implementation.destroy()
    }
}

private final class IOSWebSocketEventDispatcher: @preconcurrency NativeEventDispatcher {
    private weak var bridge: NativeBridge?

    init(bridge: NativeBridge) {
        self.bridge = bridge
    }

    func dispatchGlobalEvent(_ eventName: String, payload: [String: Any]) {
        dispatchPrecondition(condition: .onQueue(.main))
        MainActor.assumeIsolated { [weak bridge] in
            bridge?.dispatchGlobalEvent(eventName, payload: payload)
        }
    }
}
#endif
