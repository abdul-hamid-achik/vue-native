import Foundation
import Security

/// Native module providing secure key-value storage backed by the Keychain.
/// Works on both iOS and macOS via the Security framework.
///
/// Methods:
///   - get(key: String) -> String?
///   - set(key: String, value: String)
///   - remove(key: String)
///   - clear()
public final class SecureStorageModule: NativeModule {
    public let moduleName = "SecureStorage"

    private let service = "com.vuenative.securestorage"

    public init() {}

    public func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            switch method {
            case "get":
                guard let key = args.first as? String else {
                    callback(nil, "get: missing key")
                    return
                }
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: self.service,
                    kSecAttrAccount as String: key,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne,
                ]
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                if status == errSecSuccess, let data = result as? Data,
                   let value = String(data: data, encoding: .utf8) {
                    callback(value, nil)
                } else if status == errSecItemNotFound {
                    callback(nil, nil)
                } else {
                    callback(nil, "get: Keychain error \(status)")
                }

            case "set":
                guard args.count >= 2,
                      let key = args[0] as? String,
                      let value = args[1] as? String else {
                    callback(nil, "set: missing key or value")
                    return
                }
                guard let data = value.data(using: .utf8) else {
                    callback(nil, "set: failed to encode value")
                    return
                }

                // Try to update first
                let searchQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: self.service,
                    kSecAttrAccount as String: key,
                ]
                let updateAttributes: [String: Any] = [
                    kSecValueData as String: data,
                ]
                let updateStatus = SecItemUpdate(searchQuery as CFDictionary, updateAttributes as CFDictionary)

                if updateStatus == errSecItemNotFound {
                    // Item doesn't exist yet, add it
                    var addQuery = searchQuery
                    addQuery[kSecValueData as String] = data
                    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
                    if addStatus == errSecSuccess {
                        callback(nil, nil)
                    } else {
                        callback(nil, "set: Keychain add error \(addStatus)")
                    }
                } else if updateStatus == errSecSuccess {
                    callback(nil, nil)
                } else {
                    callback(nil, "set: Keychain update error \(updateStatus)")
                }

            case "remove":
                guard let key = args.first as? String else {
                    callback(nil, "remove: missing key")
                    return
                }
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: self.service,
                    kSecAttrAccount as String: key,
                ]
                let status = SecItemDelete(query as CFDictionary)
                if status == errSecSuccess || status == errSecItemNotFound {
                    callback(nil, nil)
                } else {
                    callback(nil, "remove: Keychain error \(status)")
                }

            case "clear":
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: self.service,
                ]
                let status = SecItemDelete(query as CFDictionary)
                if status == errSecSuccess || status == errSecItemNotFound {
                    callback(nil, nil)
                } else {
                    callback(nil, "clear: Keychain error \(status)")
                }

            default:
                callback(nil, "SecureStorageModule: Unknown method '\(method)'")
            }
        }
    }
}
