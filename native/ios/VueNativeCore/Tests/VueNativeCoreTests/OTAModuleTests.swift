#if canImport(UIKit)
import Foundation
import Network
import XCTest
@testable import VueNativeCore

@MainActor
final class OTAModuleTests: XCTestCase {
    private var defaults: UserDefaults!
    private var bundleDirectory: URL!
    private var module: OTAModule!
    private var suiteName = ""

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "VueNativeCore.OTAModuleTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        bundleDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VueNativeCore-OTA-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)
        module = OTAModule(
            bridge: NativeBridge.shared,
            defaults: defaults,
            bundleDirectory: bundleDirectory
        )
    }

    override func tearDownWithError() throws {
        module.destroy()
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: bundleDirectory)
        module = nil
        defaults = nil
        bundleDirectory = nil
        try super.tearDownWithError()
    }

    func testVerifyAndApplyPersistOfferedVersionAndHash() throws {
        let staged = try stageBundle(source: "globalThis.__otaVersion = 2;", version: "2.4.0")

        let verified = invoke("verifyBundle")
        XCTAssertNil(verified.error)
        XCTAssertEqual((verified.result as? [String: Any])?["version"] as? String, "2.4.0")

        let applied = invoke("applyUpdate")
        XCTAssertNil(applied.error)
        XCTAssertEqual((applied.result as? [String: Any])?["version"] as? String, "2.4.0")
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "2.4.0")
        XCTAssertEqual(defaults.string(forKey: OTAModule.bundleHashKey), staged.hash)
        XCTAssertEqual(
            OTAModule.activeBundleURL(
                defaults: defaults,
                bundleDirectory: bundleDirectory
            ),
            staged.url
        )

        let current = invoke("getCurrentVersion")
        let currentInfo = current.result as? [String: Any]
        XCTAssertEqual(currentInfo?["version"] as? String, "2.4.0")
        XCTAssertEqual(currentInfo?["isUsingOTA"] as? Bool, true)
    }

    func testCleanupPartialDownloadRemovesPendingStateAndFile() throws {
        let staged = try stageBundle(source: "globalThis.__pending = true;", version: "3.0.0")

        let cleaned = invoke("cleanupPartialDownload")

        XCTAssertNil(cleaned.error)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staged.url.path))
        XCTAssertNil(defaults.string(forKey: OTAModule.pendingBundlePathKey))
        XCTAssertNil(defaults.string(forKey: OTAModule.pendingVersionKey))
        XCTAssertNil(defaults.string(forKey: OTAModule.pendingBundleHashKey))
    }

    func testActiveResolverRejectsTamperedBundleAndClearsAppliedState() throws {
        let staged = try stageBundle(source: "globalThis.__safe = true;", version: "4.0.0")
        XCTAssertNil(invoke("applyUpdate").error)

        try Data("globalThis.__tampered = true;".utf8).write(to: staged.url, options: .atomic)

        XCTAssertNil(
            OTAModule.activeBundleURL(
                defaults: defaults,
                bundleDirectory: bundleDirectory
            )
        )
        XCTAssertNil(defaults.string(forKey: OTAModule.bundlePathKey))
        XCTAssertNil(defaults.string(forKey: OTAModule.currentVersionKey))
        XCTAssertNil(defaults.string(forKey: OTAModule.bundleHashKey))
    }

    func testRollbackRestoresPreviousContentAddressedBundle() throws {
        let first = try stageBundle(source: "globalThis.__otaVersion = 1;", version: "1.0.0")
        XCTAssertNil(invoke("applyUpdate").error)
        let second = try stageBundle(source: "globalThis.__otaVersion = 2;", version: "2.0.0")
        XCTAssertNil(invoke("applyUpdate").error)

        let rolledBack = invoke("rollback")

        XCTAssertNil(rolledBack.error)
        XCTAssertEqual((rolledBack.result as? [String: Any])?["toEmbedded"] as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "1.0.0")
        XCTAssertEqual(
            OTAModule.activeBundleURL(
                defaults: defaults,
                bundleDirectory: bundleDirectory
            ),
            first.url
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.url.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.url.path))
    }

    func testResolverWillNotReadOrDeleteOutsideManagedDirectory() throws {
        let source = Data("globalThis.__outside = true;".utf8)
        let outsideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("VueNativeCore-outside-\(UUID().uuidString).js")
        try source.write(to: outsideURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: outsideURL) }

        defaults.set(outsideURL.path, forKey: OTAModule.bundlePathKey)
        defaults.set("1.0.0", forKey: OTAModule.currentVersionKey)
        defaults.set(OTAModule.sha256(data: source), forKey: OTAModule.bundleHashKey)

        XCTAssertNil(
            OTAModule.activeBundleURL(
                defaults: defaults,
                bundleDirectory: bundleDirectory
            )
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideURL.path))
    }

    func testLocalHTTPManifestDownloadIntegrityApplyAndRollback() throws {
        let server = try OTALocalHTTPServer()
        defer { server.stop() }

        let firstSource = Data("globalThis.__otaVersion = 1;".utf8)
        let firstHash = OTAModule.sha256(data: firstSource)
        server.setResponse(path: "/bundle-1.js", body: firstSource)
        server.setJSONResponse(path: "/manifest", object: [
            "updateAvailable": true,
            "version": "1.0.0",
            "downloadUrl": "\(server.baseURL)/bundle-1.js",
            "hash": firstHash,
            "size": firstSource.count,
            "releaseNotes": "Local fixture",
        ])

        let firstCheck = invokeAsync("checkForUpdate", args: ["\(server.baseURL)/manifest"])
        XCTAssertNil(firstCheck.error)
        let firstManifest = try XCTUnwrap(firstCheck.result as? [String: Any])
        XCTAssertEqual(firstManifest["version"] as? String, "1.0.0")
        XCTAssertEqual(firstManifest["hash"] as? String, firstHash)
        let initialRequest = try XCTUnwrap(server.lastRequest(path: "/manifest"))
        XCTAssertEqual(initialRequest.headers["x-current-version"], "embedded")
        XCTAssertEqual(initialRequest.headers["x-platform"], "ios")

        let firstDownload = invokeAsync(
            "downloadUpdate",
            args: ["\(server.baseURL)/bundle-1.js", firstHash, "1.0.0"]
        )
        XCTAssertNil(firstDownload.error)
        XCTAssertNil(invoke("verifyBundle").error)
        XCTAssertNil(invoke("applyUpdate").error)
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "1.0.0")
        XCTAssertEqual(
            try Data(contentsOf: XCTUnwrap(OTAModule.activeBundleURL(
                defaults: defaults,
                bundleDirectory: bundleDirectory
            ))),
            firstSource
        )

        let secondSource = Data("globalThis.__otaVersion = 2;".utf8)
        let secondHash = OTAModule.sha256(data: secondSource)
        server.setResponse(path: "/bundle-2.js", body: secondSource)
        server.setJSONResponse(path: "/manifest", object: [
            "updateAvailable": true,
            "version": "2.0.0",
            "downloadUrl": "\(server.baseURL)/bundle-2.js",
            "hash": secondHash,
            "size": secondSource.count,
        ])

        XCTAssertNil(invokeAsync("checkForUpdate", args: ["\(server.baseURL)/manifest"]).error)
        let updateRequest = try XCTUnwrap(server.lastRequest(path: "/manifest"))
        XCTAssertEqual(updateRequest.headers["x-current-version"], "1.0.0")
        XCTAssertNil(invokeAsync(
            "downloadUpdate",
            args: ["\(server.baseURL)/bundle-2.js", secondHash, "2.0.0"]
        ).error)
        XCTAssertNil(invoke("applyUpdate").error)
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "2.0.0")

        let rollback = invoke("rollback")
        XCTAssertNil(rollback.error)
        XCTAssertEqual((rollback.result as? [String: Any])?["toEmbedded"] as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "1.0.0")

        let rejectedHash = String(repeating: "0", count: 64)
        server.setResponse(path: "/tampered.js", body: Data("globalThis.__tampered = true;".utf8))
        let rejected = invokeAsync(
            "downloadUpdate",
            args: ["\(server.baseURL)/tampered.js", rejectedHash, "3.0.0"]
        )
        XCTAssertTrue(rejected.error?.contains("integrity check failed") == true)
        XCTAssertNil(defaults.string(forKey: OTAModule.pendingBundlePathKey))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: bundleDirectory.appendingPathComponent("bundle-\(rejectedHash).js").path
        ))
        XCTAssertEqual(defaults.string(forKey: OTAModule.currentVersionKey), "1.0.0")
    }

    private func stageBundle(source: String, version: String) throws -> (url: URL, hash: String) {
        let data = Data(source.utf8)
        let hash = OTAModule.sha256(data: data)
        let url = bundleDirectory.appendingPathComponent("bundle-\(hash).js")
        try data.write(to: url, options: .atomic)
        defaults.set(url.path, forKey: OTAModule.pendingBundlePathKey)
        defaults.set(version, forKey: OTAModule.pendingVersionKey)
        defaults.set(hash, forKey: OTAModule.pendingBundleHashKey)
        return (url, hash)
    }

    private func invoke(_ method: String, args: [Any] = []) -> (result: Any?, error: String?) {
        var result: Any?
        var error: String?
        module.invoke(method: method, args: args) { value, callbackError in
            result = value
            error = callbackError
        }
        return (result, error)
    }

    private func invokeAsync(
        _ method: String,
        args: [Any] = [],
        timeout: TimeInterval = 5
    ) -> (result: Any?, error: String?) {
        let completed = expectation(description: "\(method) callback")
        var result: Any?
        var error: String?
        module.invoke(method: method, args: args) { value, callbackError in
            result = value
            error = callbackError
            completed.fulfill()
        }
        wait(for: [completed], timeout: timeout)
        return (result, error)
    }
}

private final class OTALocalHTTPServer {
    struct Request {
        let path: String
        let headers: [String: String]
    }

    private struct Response {
        let contentType: String
        let body: Data
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "VueNativeCoreTests.OTALocalHTTPServer")
    private let lock = NSLock()
    private var responses: [String: Response] = [:]
    private var requests: [Request] = []
    private(set) var baseURL = ""

    init() throws {
        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener

        let ready = DispatchSemaphore(value: 0)
        var startupError: NWError?
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.signal()
            case .failed(let error):
                startupError = error
                ready.signal()
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)

        guard ready.wait(timeout: .now() + 5) == .success,
              startupError == nil,
              let port = listener.port else {
            listener.cancel()
            throw startupError ?? URLError(.cannotConnectToHost)
        }
        baseURL = "http://localhost:\(port.rawValue)"
    }

    func setResponse(
        path: String,
        body: Data,
        contentType: String = "application/javascript; charset=utf-8"
    ) {
        lock.lock()
        responses[path] = Response(contentType: contentType, body: body)
        lock.unlock()
    }

    func setJSONResponse(path: String, object: [String: Any]) {
        let body = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
        setResponse(path: path, body: body, contentType: "application/json")
    }

    func lastRequest(path: String) -> Request? {
        lock.lock()
        defer { lock.unlock() }
        return requests.last { $0.path == path }
    }

    func stop() {
        listener.cancel()
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, data: Data())
    }

    private func receive(_ connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] chunk, _, complete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var received = data
            if let chunk {
                received.append(chunk)
            }
            if received.range(of: Data("\r\n\r\n".utf8)) != nil {
                self.respond(to: connection, requestData: received)
            } else if complete || error != nil || received.count >= 64 * 1024 {
                connection.cancel()
            } else {
                self.receive(connection, data: received)
            }
        }
    }

    private func respond(to connection: NWConnection, requestData: Data) {
        guard let rawRequest = String(data: requestData, encoding: .utf8) else {
            connection.cancel()
            return
        }
        let lines = rawRequest.components(separatedBy: "\r\n")
        let target = lines.first?.split(separator: " ").dropFirst().first.map(String.init) ?? "/"
        let path = URL(string: "http://localhost\(target)")?.path ?? target
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = line[..<separator].lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        lock.lock()
        requests.append(Request(path: path, headers: headers))
        let response = responses[path]
        lock.unlock()

        let status = response == nil ? "404 Not Found" : "200 OK"
        let body = response?.body ?? Data("Not found".utf8)
        let contentType = response?.contentType ?? "text/plain; charset=utf-8"
        var payload = Data(
            "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8
        )
        payload.append(body)
        connection.send(content: payload, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
#endif
