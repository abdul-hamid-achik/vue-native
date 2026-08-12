import Foundation
import AppKit

/// Connection status of the hot-reload WebSocket, surfaced through
/// ``HotReloadManager/onStatusChange`` so a host (``VueNativeWindowController``)
/// can render a live indicator (see `HotReloadStatusView`). Mirrors the
/// shared iOS/macOS/Android hot-reload status indicator spec.
public enum HotReloadStatus: Equatable {
    /// A connection attempt is in flight or scheduled. `attempt` is `0` for
    /// the very first attempt made by ``HotReloadManager/connect(to:)``, and
    /// the current retry count (1, 2, 3, …) for every attempt scheduled
    /// afterward by the manager's exponential backoff.
    case connecting(attempt: Int)
    /// The dev server accepted the socket and confirmed with a `"connected"` message.
    case connected
}

/// Manages a WebSocket connection to the Vue Native dev server for hot reload.
/// When a new bundle is broadcast, triggers a full app reload via NativeBridge.
///
/// Usage in your app (debug builds only):
/// ```swift
/// #if DEBUG
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

    /// Exponential backoff bounds for reconnection. The manager retries
    /// indefinitely while `serverURL` is set (matching Android), so a dev
    /// server that is down for more than a few seconds never kills hot reload
    /// silently -- it just keeps probing with a capped delay.
    private static let baseReconnectDelay: TimeInterval = 1.0
    private static let maxReconnectDelay: TimeInterval = 30.0

    /// Fires on every connection-state transition: `.connecting(attempt: 0)`
    /// when `connect(to:)` starts, `.connecting(attempt: N)` on each
    /// scheduled reconnect attempt, and `.connected` once the dev server
    /// confirms the socket. Drives the on-screen status badge but has no
    /// dependency on it, so it stays testable without touching AppKit.
    public var onStatusChange: ((HotReloadStatus) -> Void)?

    private override init() {
        super.init()
    }

    /// Exponential backoff delay for a given reconnect attempt (1-based).
    /// Produces `base, 2*base, 4*base, ...` capped at `max`:
    /// 1s, 2s, 4s, 8s, 16s, 30s, 30s, ... There is no attempt limit -- the
    /// caller retries forever while a server URL is configured.
    static func reconnectDelay(
        forAttempt attempt: Int,
        base: TimeInterval = baseReconnectDelay,
        max: TimeInterval = maxReconnectDelay
    ) -> TimeInterval {
        guard attempt > 1 else { return base }
        let exponent = Double(attempt - 1)
        // Double overflows to .infinity well past any realistic attempt count,
        // but guard explicitly so the result is always a finite, capped delay.
        guard exponent < 63 else { return max }
        return Swift.min(base * pow(2.0, exponent), max)
    }

    // MARK: - Public API

    /// Connect to the dev server. Safe to call multiple times.
    public func connect(to url: URL) {
        serverURL = url
        reconnectAttempts = 0
        onStatusChange?(.connecting(attempt: 0))
        scheduleConnect(delay: 0)
    }

    /// Disconnect and stop reconnecting.
    public func disconnect() {
        serverURL = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        NSLog("[VueNative macOS HotReload] Disconnected")
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

        session?.invalidateAndCancel()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        NSLog("[VueNative macOS HotReload] Connecting to \(url)...")
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
                NSLog("[VueNative macOS HotReload] Receive error: \(error.localizedDescription)")
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
            NSLog("[VueNative macOS HotReload] Connected -- hot reload active")
            onStatusChange?(.connected)

        case "bundle":
            guard let bundle = json["bundle"] as? String else { return }
            NSLog("[VueNative macOS HotReload] Received bundle (\(bundle.count) bytes) -- reloading...")
            DispatchQueue.main.async {
                NativeBridge.shared.reloadWithBundle(bundle)
            }

        case "ping":
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
        isConnecting = false
        // Never give up: retry indefinitely with exponential backoff capped at
        // maxReconnectDelay, matching Android's behavior. Only disconnect()
        // (which clears serverURL) stops the reconnect loop.
        let delay = Self.reconnectDelay(forAttempt: reconnectAttempts)
        NSLog("[VueNative macOS HotReload] Reconnecting in %.1fs... (attempt %d)", delay, reconnectAttempts)
        onStatusChange?(.connecting(attempt: reconnectAttempts))
        scheduleConnect(delay: delay)
    }

    // MARK: - URLSessionWebSocketDelegate

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                           didOpenWithProtocol protocol: String?) {
        NSLog("[VueNative macOS HotReload] WebSocket opened")
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                           didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        NSLog("[VueNative macOS HotReload] WebSocket closed (code: \(closeCode.rawValue))")
        scheduleReconnect()
    }
}
