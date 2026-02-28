import Foundation

/// Manages a WebSocket connection to the Vue Native dev server for hot reload.
/// When a new bundle is broadcast, calls `onBundleReceived` so the platform-specific
/// bridge can perform the reload.
///
/// Usage in your app (debug builds only):
/// ```swift
/// #if DEBUG
/// HotReloadManager.shared.onBundleReceived = { bundle in
///     NativeBridge.shared.reloadWithBundle(bundle)
/// }
/// HotReloadManager.shared.connect(to: URL(string: "ws://localhost:8174")!)
/// #endif
/// ```
public final class HotReloadManager: NSObject, URLSessionWebSocketDelegate {

    public static let shared = HotReloadManager()

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var serverURL: URL?
    private var isConnecting = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    /// Called when a new bundle is received from the dev server.
    /// Platform-specific code sets this to trigger a full app reload.
    public var onBundleReceived: ((String) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Connect to the dev server. Safe to call multiple times.
    public func connect(to url: URL) {
        serverURL = url
        reconnectAttempts = 0
        scheduleConnect(delay: 0)
    }

    /// Disconnect and stop reconnecting.
    public func disconnect() {
        serverURL = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        NSLog("[VueNative HotReload] Disconnected")
    }

    // MARK: - Connection

    private func scheduleConnect(delay: TimeInterval) {
        guard serverURL != nil, !isConnecting else { return }
        isConnecting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.openConnection()
        }
    }

    private func openConnection() {
        guard let url = serverURL else {
            isConnecting = false
            return
        }

        // Create a fresh session each time to avoid stale state
        session?.invalidateAndCancel()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        NSLog("[VueNative HotReload] Connecting to \(url)...")
        receiveNextMessage()
    }

    // MARK: - Message Handling

    private func receiveNextMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.receiveNextMessage()
            case .failure(let error):
                NSLog("[VueNative HotReload] Receive error: \(error.localizedDescription)")
                self.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let text: String
        switch message {
        case .string(let s): text = s
        case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
        @unknown default: return
        }

        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }

        switch type {
        case "connected":
            isConnecting = false
            reconnectAttempts = 0
            NSLog("[VueNative HotReload] Connected — hot reload active")

        case "bundle":
            guard let bundle = json["bundle"] as? String else { return }
            NSLog("[VueNative HotReload] Received bundle (\(bundle.count) bytes) — reloading...")
            DispatchQueue.main.async { [weak self] in
                self?.onBundleReceived?(bundle)
            }

        case "ping":
            // Respond to keep-alive pings
            let pong = "{\"type\":\"pong\"}"
            webSocketTask?.send(.string(pong)) { _ in }

        default:
            break
        }
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        guard serverURL != nil else { return }
        reconnectAttempts += 1
        if reconnectAttempts > maxReconnectAttempts {
            NSLog("[VueNative HotReload] Giving up after %d attempts — start `bun run dev` and relaunch the app", maxReconnectAttempts)
            disconnect()
            return
        }
        isConnecting = false
        NSLog("[VueNative HotReload] Reconnecting in 2s... (attempt %d/%d)", reconnectAttempts, maxReconnectAttempts)
        scheduleConnect(delay: 2.0)
    }

    // MARK: - URLSessionWebSocketDelegate

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                           didOpenWithProtocol protocol: String?) {
        NSLog("[VueNative HotReload] WebSocket opened")
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        NSLog("[VueNative HotReload] WebSocket closed (code: \(closeCode.rawValue))")
        scheduleReconnect()
    }
}
