import Foundation
import Security
import XCTest
@testable import VueNativeShared

/// In-memory stand-in for the Keychain so the module can be tested without an
/// unlocked keychain, and so the exact query attributes it builds are inspectable.
private final class RecordingKeychain: SecureStorageKeychain {

    struct Recorded {
        let operation: String
        let query: [String: Any]
        let attributes: [String: Any]?
    }

    var recorded: [Recorded] = []
    var items: [String: Data] = [:]

    private func storageKey(_ dictionary: [String: Any]) -> String? {
        guard let service = dictionary[kSecAttrService as String] as? String else { return nil }
        guard let account = dictionary[kSecAttrAccount as String] as? String else { return nil }
        return "\(service)|\(account)"
    }

    private func record(_ operation: String, _ query: [String: Any], _ attributes: [String: Any]?) {
        recorded.append(Recorded(operation: operation, query: query, attributes: attributes))
    }

    func copyMatching(_ query: [String: Any]) -> (status: OSStatus, result: AnyObject?) {
        record("copy", query, nil)
        guard let key = storageKey(query), let data = items[key] else {
            return (errSecItemNotFound, nil)
        }
        return (errSecSuccess, data as AnyObject)
    }

    func add(_ query: [String: Any]) -> OSStatus {
        record("add", query, nil)
        guard let key = storageKey(query),
              let data = query[kSecValueData as String] as? Data else {
            return errSecParam
        }
        items[key] = data
        return errSecSuccess
    }

    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        record("update", query, attributes)
        guard let key = storageKey(query), items[key] != nil else {
            return errSecItemNotFound
        }
        if let data = attributes[kSecValueData as String] as? Data {
            items[key] = data
        }
        return errSecSuccess
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        record("delete", query, nil)
        if let key = storageKey(query) {
            items.removeValue(forKey: key)
            return errSecSuccess
        }
        guard let service = query[kSecAttrService as String] as? String else { return errSecParam }
        let prefix = "\(service)|"
        for key in items.keys where key.hasPrefix(prefix) {
            items.removeValue(forKey: key)
        }
        return errSecSuccess
    }
}

/// Regression tests for P1-5: explicit accessibility class, an access-controlled
/// variant, and a `clear()` that cannot wipe gated material.
final class SecureStorageModuleTests: XCTestCase {

    private var keychain: RecordingKeychain!
    private var module: SecureStorageModule!

    override func setUpWithError() throws {
        try super.setUpWithError()
        keychain = RecordingKeychain()
        module = SecureStorageModule(keychain: keychain)
    }

    override func tearDownWithError() throws {
        module.destroy()
        module = nil
        keychain = nil
        try super.tearDownWithError()
    }

    // MARK: - Accessibility class

    func testSetOnANewItemRecordsExplicitAccessibilityClass() {
        let response = invoke("set", args: ["token", "secret"])
        XCTAssertNil(response.error)

        let add = keychain.recorded.first { $0.operation == "add" }
        let attributes = try? XCTUnwrap(add?.query)
        XCTAssertEqual(
            attributes?[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String,
            "new items must pin an explicit accessibility class instead of inheriting the default"
        )
        XCTAssertEqual(keychain.items["\(SecureStorageModule.service)|token"], Data("secret".utf8))
    }

    func testUpdateOfAnExistingItemRestatesAccessibilityClass() {
        XCTAssertNil(invoke("set", args: ["token", "first"]).error)
        keychain.recorded.removeAll()

        XCTAssertNil(invoke("set", args: ["token", "second"]).error)

        let update = keychain.recorded.first { $0.operation == "update" }
        let attributes = try? XCTUnwrap(update?.attributes)
        XCTAssertEqual(
            attributes?[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String,
            "an item written by an older build without the attribute must be migrated on update"
        )
        XCTAssertEqual(keychain.items["\(SecureStorageModule.service)|token"], Data("second".utf8))
    }

    // MARK: - Round trip

    func testGetReturnsStoredValueAndNilForMissingKeys() {
        XCTAssertNil(invoke("set", args: ["token", "secret"]).error)

        let found = invoke("get", args: ["token"])
        XCTAssertNil(found.error)
        XCTAssertEqual(found.result as? String, "secret")

        let missing = invoke("get", args: ["nope"])
        XCTAssertNil(missing.error, "a missing key is not an error")
        XCTAssertNil(missing.result)
    }

    func testRemoveDeletesOnlyTheRequestedKey() {
        XCTAssertNil(invoke("set", args: ["a", "1"]).error)
        XCTAssertNil(invoke("set", args: ["b", "2"]).error)

        XCTAssertNil(invoke("remove", args: ["a"]).error)
        XCTAssertNil(keychain.items["\(SecureStorageModule.service)|a"])
        XCTAssertEqual(keychain.items["\(SecureStorageModule.service)|b"], Data("2".utf8))
    }

    func testMissingArgumentsAreReported() {
        XCTAssertNotNil(invoke("get", args: []).error)
        XCTAssertNotNil(invoke("set", args: ["only-a-key"]).error)
        XCTAssertNotNil(invoke("remove", args: []).error)
    }

    // MARK: - clear() scoping

    func testClearIsScopedToTheUnprotectedService() {
        XCTAssertNil(invoke("set", args: ["token", "secret"]).error)
        // Seed a protected-service item directly so the assertion does not depend
        // on this host having a passcode/biometry enrolled.
        keychain.items["\(SecureStorageModule.protectedService)|token"] = Data("gated".utf8)

        XCTAssertNil(invoke("clear", args: []).error)

        XCTAssertNil(
            keychain.items["\(SecureStorageModule.service)|token"],
            "clear() must wipe the unprotected service"
        )
        XCTAssertEqual(
            keychain.items["\(SecureStorageModule.protectedService)|token"],
            Data("gated".utf8),
            "clear() must never reach user-presence-gated items"
        )
        let deletes = keychain.recorded.filter { $0.operation == "delete" }
        XCTAssertTrue(
            deletes.allSatisfy { ($0.query[kSecAttrService as String] as? String) != SecureStorageModule.protectedService },
            "clear() issued a delete against the protected service"
        )
    }

    // MARK: - Protected variant

    func testProtectedVariantUsesSeparateServiceAndAccessControl() {
        let response = invoke("setProtected", args: ["token", "secret"])

        if let error = response.error {
            // This host has no passcode/biometry available, so building the
            // access control fails. It must fail CLOSED, never fall back to the
            // unprotected service.
            XCTAssertTrue(
                error.contains("could not create access control"),
                "unexpected protected-write failure: \(error)"
            )
            XCTAssertTrue(keychain.items.isEmpty, "nothing may be written when gating is unavailable")
            return
        }

        XCTAssertEqual(keychain.items["\(SecureStorageModule.protectedService)|token"], Data("secret".utf8))
        XCTAssertNil(
            keychain.items["\(SecureStorageModule.service)|token"],
            "protected values must not land in the unprotected service"
        )

        let add = keychain.recorded.first { $0.operation == "add" }
        let query = try? XCTUnwrap(add?.query)
        XCTAssertNotNil(
            query?[kSecAttrAccessControl as String],
            "protected items must carry a kSecAttrAccessControl"
        )
        XCTAssertNil(
            query?[kSecAttrAccessible as String],
            "kSecAttrAccessible and kSecAttrAccessControl are mutually exclusive"
        )
        XCTAssertEqual(query?[kSecAttrService as String] as? String, SecureStorageModule.protectedService)

        let read = invoke("getProtected", args: ["token"])
        XCTAssertEqual(read.result as? String, "secret")

        XCTAssertNil(invoke("removeProtected", args: ["token"]).error)
        XCTAssertNil(keychain.items["\(SecureStorageModule.protectedService)|token"])
    }

    func testProtectedReadsDoNotReachUnprotectedItems() {
        XCTAssertNil(invoke("set", args: ["token", "plain"]).error)

        let read = invoke("getProtected", args: ["token"])
        XCTAssertNil(read.result, "getProtected must not read the unprotected service")
    }

    func testUnknownMethodIsRejected() {
        let response = invoke("nope", args: [])
        XCTAssertNil(response.result)
        XCTAssertEqual(response.error, "SecureStorageModule: Unknown method 'nope'")
    }

    // MARK: - Helper

    private func invoke(
        _ method: String,
        args: [Any],
        timeout: TimeInterval = 10
    ) -> (result: Any?, error: String?) {
        let completed = expectation(description: "\(method) callback")
        var response: (result: Any?, error: String?) = (nil, nil)
        module.invoke(method: method, args: args) { result, error in
            response = (result, error)
            completed.fulfill()
        }
        wait(for: [completed], timeout: timeout)
        return response
    }
}
