import Foundation
import Security

/// Thin indirection over the `SecItem*` C API so the module can be tested
/// without an unlocked keychain. The default implementation is the real one.
///
/// Queries are `[String: Any]` rather than `CFDictionary` so a test double can
/// inspect the exact attributes the module builds — which is the whole point of
/// the injection seam (asserting `kSecAttrAccessible` is actually set).
public protocol SecureStorageKeychain: AnyObject {
    func copyMatching(_ query: [String: Any]) -> (status: OSStatus, result: AnyObject?)
    func add(_ query: [String: Any]) -> OSStatus
    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

/// Production keychain backend.
public final class SystemKeychain: SecureStorageKeychain {
    public init() {}

    public func copyMatching(_ query: [String: Any]) -> (status: OSStatus, result: AnyObject?) {
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result)
    }

    public func add(_ query: [String: Any]) -> OSStatus {
        SecItemAdd(query as CFDictionary, nil)
    }

    public func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    public func delete(_ query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}

/// Native module providing secure key-value storage backed by the Keychain.
/// Works on both iOS and macOS via the Security framework.
///
/// Methods:
///   - get(key: String) -> String?
///   - set(key: String, value: String)
///   - remove(key: String)
///   - clear()
///   - getProtected(key: String) -> String?          (user-presence gated)
///   - setProtected(key: String, value: String)       (user-presence gated)
///   - removeProtected(key: String)                   (user-presence gated)
///
/// ## Accessibility and access control
///
/// Unprotected items are stored with an explicit
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Setting this matters:
/// without it items inherit the platform default, and `AfterFirstUnlock`
/// (without `ThisDeviceOnly`) allows the item to be included in an unencrypted
/// backup and restored onto a different device.
///
/// The `*Protected` variants additionally attach a `kSecAttrAccessControl`
/// requiring user presence (biometry when enrolled, otherwise the passcode), so
/// reading or writing them cannot happen silently from background code.
///
/// ## Threat model caveat
///
/// Any code executing inside the app process — including a malicious JS bundle —
/// can call the unprotected methods. Keychain access control raises the cost of
/// silent exfiltration but is not a sandbox boundary. Store only material that
/// genuinely needs it in the protected variants.
public final class SecureStorageModule: NativeModule {
    public let moduleName = "SecureStorage"

    /// Service namespace for the unprotected API.
    static let service = "com.vuenative.securestorage"
    /// Separate namespace for user-presence-gated items, so `clear()` — which any
    /// JavaScript can invoke — can never wipe them.
    static let protectedService = "com.vuenative.securestorage.protected"

    /// Accessibility class for unprotected items.
    static let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

    private let keychain: SecureStorageKeychain
    private let protectedAccessFlags: SecAccessControlCreateFlags

    /// - Parameters:
    ///   - keychain: backend to use; defaults to the real Security framework.
    ///   - protectedAccessFlags: constraint applied to the `*Protected` items.
    ///     Defaults to `.userPresence` (biometry if enrolled, otherwise passcode).
    ///     Pass `.biometryCurrentSet` to require biometry specifically.
    public init(
        keychain: SecureStorageKeychain = SystemKeychain(),
        protectedAccessFlags: SecAccessControlCreateFlags = .userPresence
    ) {
        self.keychain = keychain
        self.protectedAccessFlags = protectedAccessFlags
    }

    public func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            switch method {
            case "get":
                self.read(key: args.first, service: Self.service, prefix: "get", callback: callback)

            case "set":
                guard args.count >= 2 else {
                    callback(nil, "set: missing key or value")
                    return
                }
                self.write(
                    key: args[0],
                    value: args[1],
                    service: Self.service,
                    accessControl: nil,
                    prefix: "set",
                    callback: callback
                )

            case "remove":
                self.delete(key: args.first, service: Self.service, prefix: "remove", callback: callback)

            case "clear":
                // Scoped to the unprotected service only. Protected items live
                // under a different service precisely so this one-call wipe —
                // reachable from any JavaScript — cannot destroy them.
                let status = self.keychain.delete([
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: Self.service,
                ])
                if status == errSecSuccess || status == errSecItemNotFound {
                    callback(nil, nil)
                } else {
                    callback(nil, "clear: Keychain error \(status)")
                }

            case "getProtected":
                self.read(key: args.first, service: Self.protectedService, prefix: "getProtected", callback: callback)

            case "setProtected":
                guard args.count >= 2, let protectedKey = args[0] as? String else {
                    callback(nil, "setProtected: missing key or value")
                    return
                }
                guard let accessControl = self.makeAccessControl(errorPrefix: "setProtected", callback: callback) else {
                    return
                }
                // Access-controlled items cannot be updated in place without an
                // authentication context, and `kSecAttrAccessible` conflicts with
                // `kSecAttrAccessControl`. Delete-then-add is the correct shape.
                _ = self.keychain.delete([
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: Self.protectedService,
                    kSecAttrAccount as String: protectedKey,
                ])
                self.write(
                    key: protectedKey,
                    value: args[1],
                    service: Self.protectedService,
                    accessControl: accessControl,
                    prefix: "setProtected",
                    callback: callback
                )

            case "removeProtected":
                self.delete(
                    key: args.first,
                    service: Self.protectedService,
                    prefix: "removeProtected",
                    callback: callback
                )

            default:
                callback(nil, "SecureStorageModule: Unknown method '\(method)'")
            }
        }
    }

    // MARK: - Operations

    private func read(
        key: Any?,
        service: String,
        prefix: String,
        callback: (Any?, String?) -> Void
    ) {
        guard let key = key as? String else {
            callback(nil, "\(prefix): missing key")
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        let (status, result) = keychain.copyMatching(query)
        if status == errSecSuccess, let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            callback(value, nil)
        } else if status == errSecItemNotFound {
            callback(nil, nil)
        } else if status == errSecAuthFailed || status == errSecInteractionNotAllowed {
            callback(nil, "\(prefix): user authentication is required for this item")
        } else {
            callback(nil, "\(prefix): Keychain error \(status)")
        }
    }

    private func write(
        key: Any?,
        value: Any?,
        service: String,
        accessControl: SecAccessControl?,
        prefix: String,
        callback: (Any?, String?) -> Void
    ) {
        guard let key = key as? String, let value = value as? String else {
            callback(nil, "\(prefix): missing key or value")
            return
        }
        guard let data = value.data(using: .utf8) else {
            callback(nil, "\(prefix): failed to encode value")
            return
        }

        var searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // An update cannot change the access control, and access-controlled
        // items are handled by delete-then-add at the call site, so only the
        // unprotected path attempts an in-place update.
        if accessControl == nil {
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data,
                // Explicitly restated on update: an item written by an older
                // build without this attribute would otherwise keep the default.
                kSecAttrAccessible as String: Self.accessibility,
            ]
            switch keychain.update(searchQuery, updateAttributes) {
            case errSecSuccess:
                callback(nil, nil)
                return
            case errSecItemNotFound:
                break
            case let status:
                callback(nil, "\(prefix): Keychain update error \(status)")
                return
            }
        }

        searchQuery[kSecValueData as String] = data
        if let accessControl {
            // `kSecAttrAccessible` and `kSecAttrAccessControl` are mutually
            // exclusive; the accessibility class lives inside the access control.
            searchQuery[kSecAttrAccessControl as String] = accessControl
        } else {
            searchQuery[kSecAttrAccessible as String] = Self.accessibility
        }

        let addStatus = keychain.add(searchQuery)
        if addStatus == errSecSuccess {
            callback(nil, nil)
        } else {
            callback(nil, "\(prefix): Keychain add error \(addStatus)")
        }
    }

    private func delete(
        key: Any?,
        service: String,
        prefix: String,
        callback: (Any?, String?) -> Void
    ) {
        guard let key = key as? String else {
            callback(nil, "\(prefix): missing key")
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let status = keychain.delete(query)
        if status == errSecSuccess || status == errSecItemNotFound {
            callback(nil, nil)
        } else {
            callback(nil, "\(prefix): Keychain error \(status)")
        }
    }

    private func makeAccessControl(
        errorPrefix: String,
        callback: (Any?, String?) -> Void
    ) -> SecAccessControl? {
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            protectedAccessFlags,
            &error
        ) else {
            let description = error?.takeRetainedValue().localizedDescription ?? "unknown error"
            callback(nil, "\(errorPrefix): could not create access control: \(description)")
            return nil
        }
        return accessControl
    }
}
