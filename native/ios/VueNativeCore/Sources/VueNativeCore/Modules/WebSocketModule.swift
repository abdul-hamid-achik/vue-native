#if canImport(UIKit)
import Foundation

/// Native module for WebSocket connections.
///
/// Supports multiple simultaneous connections keyed by connection ID.
///
/// Methods:
///   - connect(url: String, connectionId: String)
///   - send(connectionId: String, data: String)
///   - close(connectionId: String, code: Int?, reason: String?)
///
/// Global events dispatched on bridge:
///   "websocket:open"    { connectionId }
///   "websocket:message" { connectionId, data }
///   "websocket:close"   { connectionId, code, reason }
///   "websocket:error"   { connectionId, message }
final class WebSocketModule: NativeModule {
    var moduleName: String { "WebSocket" }
    private weak var bridge: NativeBridge?

    /// Active WebSocket tasks keyed by connectionId
    private var connections: [String: URLSessionWebSocketTask] = [:]
    private var sessions: [String: URLSession] = [:]

    init(bridge: NativeBridge) {
        self.bridge = bridge
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "connect":
            guard let url = args.first as? String,
                  let connectionId = args.count > 1 ? args[1] as? String : nil else {
                callback(nil, "WebSocketModule: expected (url, connectionId)")
                return
            }
            connect(url: url, connectionId: connectionId, callback: callback)

        case "send":
            guard let connectionId = args.first as? String,
                  let data = args.count > 1 ? args[1] as? String : nil else {
                callback(nil, "WebSocketModule: expected (connectionId, data)")
                return
            }
            send(connectionId: connectionId, data: data, callback: callback)

        case "close":
            guard let connectionId = args.first as? String else {
                callback(nil, "WebSocketModule: expected (connectionId)")
                return
            }
            let code = args.count > 1 ? args[1] as? Int : nil
            let reason = args.count > 2 ? args[2] as? String : nil
            close(connectionId: connectionId, code: code, reason: reason, callback: callback)

        default:
            callback(nil, "WebSocketModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Connect

    private func connect(url: String, connectionId: String, callback: @escaping (Any?, String?) -> Void) {
        guard let wsURL = URL(string: url) else {
            callback(nil, "WebSocketModule: invalid URL '\(url)'")
            return
        }

        // Clean up existing connection with same ID if any
        closeConnection(connectionId)

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: wsURL)
        connections[connectionId] = task
        sessions[connectionId] = session

        task.resume()

        // Dispatch open event once resumed
        let weakBridge = bridge
        DispatchQueue.main.async {
            weakBridge?.dispatchGlobalEvent("websocket:open", payload: [
                "connectionId": connectionId
            ])
        }

        // Start receive loop
        receiveLoop(connectionId: connectionId, task: task)

        callback(true, nil)
    }

    // MARK: - Receive loop

    private func receiveLoop(connectionId: String, task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self = self else { return }
            // Check if connection still exists (may have been closed)
            guard self.connections[connectionId] != nil else { return }

            switch result {
            case .success(let message):
                let data: String
                switch message {
                case .string(let text):
                    data = text
                case .data(let bytes):
                    data = String(data: bytes, encoding: .utf8) ?? ""
                @unknown default:
                    data = ""
                }

                let weakBridge = self.bridge
                DispatchQueue.main.async {
                    weakBridge?.dispatchGlobalEvent("websocket:message", payload: [
                        "connectionId": connectionId,
                        "data": data
                    ])
                }

                // Continue receiving
                self.receiveLoop(connectionId: connectionId, task: task)

            case .failure(let error):
                let weakBridge = self.bridge
                let errorMessage = error.localizedDescription
                DispatchQueue.main.async {
                    // Check if this is a normal close or an actual error
                    let nsError = error as NSError
                    if nsError.domain == NSPOSIXErrorDomain && nsError.code == 57 {
                        // Socket not connected — normal close, dispatch close event
                        weakBridge?.dispatchGlobalEvent("websocket:close", payload: [
                            "connectionId": connectionId,
                            "code": 1000,
                            "reason": ""
                        ])
                    } else {
                        weakBridge?.dispatchGlobalEvent("websocket:error", payload: [
                            "connectionId": connectionId,
                            "message": errorMessage
                        ])
                        weakBridge?.dispatchGlobalEvent("websocket:close", payload: [
                            "connectionId": connectionId,
                            "code": 1006,
                            "reason": errorMessage
                        ])
                    }
                }
                self.connections.removeValue(forKey: connectionId)
                self.sessions[connectionId]?.invalidateAndCancel()
                self.sessions.removeValue(forKey: connectionId)
            }
        }
    }

    // MARK: - Send

    private func send(connectionId: String, data: String, callback: @escaping (Any?, String?) -> Void) {
        guard let task = connections[connectionId] else {
            callback(nil, "WebSocketModule: no connection '\(connectionId)'")
            return
        }
        task.send(.string(data)) { error in
            if let error = error {
                callback(nil, error.localizedDescription)
            } else {
                callback(true, nil)
            }
        }
    }

    // MARK: - Close

    private func close(connectionId: String, code: Int?, reason: String?, callback: @escaping (Any?, String?) -> Void) {
        guard let task = connections[connectionId] else {
            callback(nil, nil) // Already closed, not an error
            return
        }

        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code ?? 1000) ?? .normalClosure
        let reasonData = reason?.data(using: .utf8)
        task.cancel(with: closeCode, reason: reasonData)

        let weakBridge = bridge
        DispatchQueue.main.async {
            weakBridge?.dispatchGlobalEvent("websocket:close", payload: [
                "connectionId": connectionId,
                "code": code ?? 1000,
                "reason": reason ?? ""
            ])
        }

        connections.removeValue(forKey: connectionId)
        sessions[connectionId]?.invalidateAndCancel()
        sessions.removeValue(forKey: connectionId)

        callback(true, nil)
    }

    // MARK: - Helpers

    private func closeConnection(_ connectionId: String) {
        guard let task = connections[connectionId] else { return }
        task.cancel(with: .normalClosure, reason: nil)
        connections.removeValue(forKey: connectionId)
        sessions[connectionId]?.invalidateAndCancel()
        sessions.removeValue(forKey: connectionId)
    }

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}
#endif
