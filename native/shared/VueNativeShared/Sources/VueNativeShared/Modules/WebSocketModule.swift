import Foundation

protocol WebSocketTransport: AnyObject {
    var onOpen: (() -> Void)? { get set }
    var onMessage: ((String) -> Void)? { get set }
    var onClose: ((Int, String) -> Void)? { get set }
    var onFailure: ((Error) -> Void)? { get set }

    func start()
    func send(_ data: String, completion: @escaping (Error?) -> Void)
    func close(code: Int, reason: String?)
    func cancel()
}

private final class URLSessionWebSocketTransport: NSObject, WebSocketTransport, URLSessionWebSocketDelegate, @unchecked Sendable {
    var onOpen: (() -> Void)?
    var onMessage: ((String) -> Void)?
    var onClose: ((Int, String) -> Void)?
    var onFailure: ((Error) -> Void)?

    private let url: URL
    private let stateLock = NSLock()
    private var isTerminal = false
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?

    init(url: URL) {
        self.url = url
    }

    func start() {
        let session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: nil
        )
        let task = session.webSocketTask(with: url)

        stateLock.lock()
        guard self.session == nil, !isTerminal else {
            stateLock.unlock()
            session.invalidateAndCancel()
            return
        }
        self.session = session
        self.task = task
        stateLock.unlock()

        task.resume()
        receiveNext(from: task)
    }

    func send(_ data: String, completion: @escaping (Error?) -> Void) {
        stateLock.lock()
        let activeTask = isTerminal ? nil : task
        stateLock.unlock()
        guard let activeTask else {
            completion(WebSocketTransportError.notStarted)
            return
        }
        activeTask.send(.string(data), completionHandler: completion)
    }

    func close(code: Int, reason: String?) {
        stateLock.lock()
        let activeTask = isTerminal ? nil : task
        stateLock.unlock()
        guard let activeTask else { return }
        let closeCode = URLSessionWebSocketTask.CloseCode(rawValue: code) ?? .normalClosure
        activeTask.cancel(with: closeCode, reason: reason?.data(using: .utf8))
    }

    func cancel() {
        stateLock.lock()
        let shouldCancel = !isTerminal
        isTerminal = true
        let activeTask = task
        let activeSession = session
        task = nil
        session = nil
        stateLock.unlock()
        guard shouldCancel else { return }

        activeTask?.cancel(with: .goingAway, reason: nil)
        activeSession?.invalidateAndCancel()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        stateLock.lock()
        let handler = !isTerminal && task === webSocketTask ? onOpen : nil
        stateLock.unlock()
        handler?()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        finishClose(
            task: webSocketTask,
            code: closeCode.rawValue,
            reason: reason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        )
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let webSocketTask = task as? URLSessionWebSocketTask else {
            return
        }

        if let error {
            finishFailure(task: webSocketTask, error: error)
        } else {
            let rawCode = webSocketTask.closeCode.rawValue
            finishClose(
                task: webSocketTask,
                code: rawCode == 0 ? URLSessionWebSocketTask.CloseCode.normalClosure.rawValue : rawCode,
                reason: webSocketTask.closeReason.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            )
        }
    }

    private func receiveNext(from task: URLSessionWebSocketTask) {
        stateLock.lock()
        let shouldReceive = !isTerminal && self.task === task
        stateLock.unlock()
        guard shouldReceive else { return }

        task.receive { [weak self, weak task] result in
            guard let self, let task else { return }

            if case .success(let message) = result {
                self.stateLock.lock()
                let handler = !self.isTerminal && self.task === task ? self.onMessage : nil
                self.stateLock.unlock()
                guard let handler else { return }

                switch message {
                case .string(let text):
                    handler(text)
                case .data(let data):
                    handler(String(data: data, encoding: .utf8) ?? "")
                @unknown default:
                    handler("")
                }
                self.receiveNext(from: task)
            }
            // URLSession's task delegate owns terminal delivery. It distinguishes
            // a protocol close from a transport failure and prevents double close.
        }
    }

    private func finishClose(task: URLSessionWebSocketTask, code: Int, reason: String) {
        let handler: ((Int, String) -> Void)?
        let activeSession: URLSession?
        stateLock.lock()
        if isTerminal || self.task !== task {
            handler = nil
            activeSession = nil
        } else {
            isTerminal = true
            handler = onClose
            activeSession = session
            self.task = nil
            session = nil
        }
        stateLock.unlock()

        handler?(code, reason)
        activeSession?.finishTasksAndInvalidate()
    }

    private func finishFailure(task: URLSessionWebSocketTask, error: Error) {
        let handler: ((Error) -> Void)?
        let activeSession: URLSession?
        stateLock.lock()
        if isTerminal || self.task !== task {
            handler = nil
            activeSession = nil
        } else {
            isTerminal = true
            handler = onFailure
            activeSession = session
            self.task = nil
            session = nil
        }
        stateLock.unlock()

        handler?(error)
        activeSession?.finishTasksAndInvalidate()
    }
}

private enum WebSocketTransportError: LocalizedError {
    case notStarted

    var errorDescription: String? {
        "WebSocket transport has not started"
    }
}

/// Native module providing WebSocket connections through a handshake-aware,
/// identity-safe URLSession transport.
public final class WebSocketModule: NativeModule {
    public var moduleName: String { "WebSocket" }
    private weak var eventDispatcher: NativeEventDispatcher?

    private struct Connection {
        let transport: WebSocketTransport
        let token: UInt64
        var isOpen = false
    }

    private struct EventContext {
        let connectionId: String
        let token: UInt64
        let lifecycle: UInt64
    }

    private let stateQueue = DispatchQueue(label: "com.vuenative.websocket.state")
    private let transportFactory: (URL) -> WebSocketTransport
    private let eventAcceptanceHook: (() -> Void)?
    private var connections: [String: Connection] = [:]
    private var latestTokens: [String: UInt64] = [:]
    private var nextToken: UInt64 = 0
    private var lifecycle: UInt64 = 0
    private var destroyed = false

    public init(eventDispatcher: NativeEventDispatcher) {
        self.eventDispatcher = eventDispatcher
        transportFactory = { URLSessionWebSocketTransport(url: $0) }
        eventAcceptanceHook = nil
    }

    init(
        eventDispatcher: NativeEventDispatcher,
        transportFactory: @escaping (URL) -> WebSocketTransport,
        eventAcceptanceHook: (() -> Void)? = nil
    ) {
        self.eventDispatcher = eventDispatcher
        self.transportFactory = transportFactory
        self.eventAcceptanceHook = eventAcceptanceHook
    }

    public func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
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

    private func connect(url: String, connectionId: String, callback: @escaping (Any?, String?) -> Void) {
        guard let webSocketURL = URL(string: url) else {
            callback(nil, "WebSocketModule: invalid URL '\(url)'")
            return
        }

        let transport = transportFactory(webSocketURL)
        let setup: (previous: WebSocketTransport?, context: EventContext)? = stateQueue.sync {
            guard !destroyed else { return nil }
            nextToken &+= 1
            let token = nextToken
            let previous = connections.removeValue(forKey: connectionId)?.transport
            connections[connectionId] = Connection(transport: transport, token: token)
            latestTokens[connectionId] = token
            return (previous, EventContext(connectionId: connectionId, token: token, lifecycle: lifecycle))
        }

        guard let setup else {
            transport.cancel()
            callback(nil, "WebSocketModule: module has been destroyed")
            return
        }

        configureCallbacks(for: transport, context: setup.context)
        setup.previous?.cancel()
        transport.start()
        callback(true, nil)
    }

    private func configureCallbacks(for transport: WebSocketTransport, context: EventContext) {
        transport.onOpen = { [weak self, weak transport] in
            guard let self, let transport else { return }
            self.dispatchCurrentEvent(
                "websocket:open",
                payload: ["connectionId": context.connectionId],
                transport: transport,
                context: context,
                opensConnection: true
            )
        }
        transport.onMessage = { [weak self, weak transport] data in
            guard let self, let transport else { return }
            self.dispatchCurrentEvent(
                "websocket:message",
                payload: ["connectionId": context.connectionId, "data": data],
                transport: transport,
                context: context,
                requiresOpen: true
            )
        }
        transport.onClose = { [weak self, weak transport] code, reason in
            guard let self, let transport else { return }
            self.finishCurrent(
                transport,
                context: context,
                code: code,
                reason: reason,
                error: nil
            )
        }
        transport.onFailure = { [weak self, weak transport] error in
            guard let self, let transport else { return }
            self.finishCurrent(
                transport,
                context: context,
                code: 1006,
                reason: error.localizedDescription,
                error: error.localizedDescription
            )
        }
    }

    private func send(connectionId: String, data: String, callback: @escaping (Any?, String?) -> Void) {
        let transport = stateQueue.sync { connections[connectionId]?.transport }
        guard let transport else {
            callback(nil, "WebSocketModule: no connection '\(connectionId)'")
            return
        }

        transport.send(data) { error in
            if let error {
                callback(nil, error.localizedDescription)
            } else {
                callback(true, nil)
            }
        }
    }

    private func close(
        connectionId: String,
        code: Int?,
        reason: String?,
        callback: @escaping (Any?, String?) -> Void
    ) {
        let closeCode = code ?? 1000
        let closeReason = reason ?? ""
        let removed: (transport: WebSocketTransport, context: EventContext)? = stateQueue.sync {
            guard !destroyed, let connection = connections.removeValue(forKey: connectionId) else {
                return nil
            }
            return (
                connection.transport,
                EventContext(connectionId: connectionId, token: connection.token, lifecycle: lifecycle)
            )
        }

        if let removed {
            removed.transport.close(code: closeCode, reason: closeReason)
            dispatchTerminalEvent(
                context: removed.context,
                code: closeCode,
                reason: closeReason,
                error: nil
            )
        }
        callback(true, nil)
    }

    private func dispatchCurrentEvent(
        _ eventName: String,
        payload: [String: Any],
        transport: WebSocketTransport,
        context: EventContext,
        requiresOpen: Bool = false,
        opensConnection: Bool = false
    ) {
        let weakDispatcher = eventDispatcher
        stateQueue.sync {
            guard !destroyed,
                  lifecycle == context.lifecycle,
                  var connection = connections[context.connectionId],
                  connection.transport === transport,
                  connection.token == context.token,
                  (!requiresOpen || connection.isOpen),
                  (!opensConnection || !connection.isOpen) else {
                return
            }

            if opensConnection {
                connection.isOpen = true
                connections[context.connectionId] = connection
            }

            eventAcceptanceHook?()

            // Enqueue while state ownership is held so a concurrent terminal
            // callback cannot overtake an already accepted open/message event.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isLatest(context) else {
                    return
                }
                weakDispatcher?.dispatchGlobalEvent(eventName, payload: payload)
            }
        }
    }

    private func isLatest(_ context: EventContext) -> Bool {
        stateQueue.sync {
            !destroyed &&
                lifecycle == context.lifecycle &&
                latestTokens[context.connectionId] == context.token
        }
    }

    private func finishCurrent(
        _ transport: WebSocketTransport,
        context: EventContext,
        code: Int,
        reason: String,
        error: String?
    ) {
        let ownsTerminalEvent = stateQueue.sync {
            guard !destroyed,
                  lifecycle == context.lifecycle,
                  let connection = connections[context.connectionId],
                  connection.transport === transport,
                  connection.token == context.token else {
                return false
            }
            connections.removeValue(forKey: context.connectionId)
            return true
        }
        guard ownsTerminalEvent else { return }
        dispatchTerminalEvent(context: context, code: code, reason: reason, error: error)
    }

    private func dispatchTerminalEvent(
        context: EventContext,
        code: Int,
        reason: String,
        error: String?
    ) {
        let weakDispatcher = eventDispatcher
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let shouldDeliver = self.stateQueue.sync {
                guard !self.destroyed,
                      self.lifecycle == context.lifecycle,
                      self.latestTokens[context.connectionId] == context.token else {
                    return false
                }
                self.latestTokens.removeValue(forKey: context.connectionId)
                return true
            }
            guard shouldDeliver else { return }

            if let error {
                weakDispatcher?.dispatchGlobalEvent("websocket:error", payload: [
                    "connectionId": context.connectionId,
                    "message": error
                ])
            }
            weakDispatcher?.dispatchGlobalEvent("websocket:close", payload: [
                "connectionId": context.connectionId,
                "code": code,
                "reason": reason
            ])
        }
    }

    public func invokeSync(method: String, args: [Any]) -> Any? { nil }

    public func destroy() {
        let activeTransports: [WebSocketTransport] = stateQueue.sync {
            guard !destroyed else { return [] }
            destroyed = true
            lifecycle &+= 1
            let transports = connections.values.map(\.transport)
            connections.removeAll()
            latestTokens.removeAll()
            return transports
        }
        activeTransports.forEach { $0.cancel() }
    }

    var activeConnectionCount: Int {
        stateQueue.sync { connections.count }
    }
}
