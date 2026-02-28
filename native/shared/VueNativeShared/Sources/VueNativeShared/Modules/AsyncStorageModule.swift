import Foundation

/// Native module providing async key-value storage backed by UserDefaults.
///
/// Methods:
///   - getItem(key: String) -> String?
///   - setItem(key: String, value: String)
///   - removeItem(key: String)
///   - getAllKeys() -> [String]
///   - clear()
public final class AsyncStorageModule: NativeModule {
    public let moduleName = "AsyncStorage"

    private let defaults = UserDefaults.standard
    private let keyPrefix = "VueNative.AsyncStorage."

    public init() {}

    public func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            switch method {
            case "getItem":
                guard let key = args.first as? String else {
                    callback(nil, "getItem: missing key")
                    return
                }
                let result = self.defaults.string(forKey: self.keyPrefix + key)
                callback(result, nil)

            case "setItem":
                guard args.count >= 2,
                      let key = args[0] as? String,
                      let val = args[1] as? String else {
                    callback(nil, "setItem: missing key or value")
                    return
                }
                self.defaults.set(val, forKey: self.keyPrefix + key)
                callback(nil, nil)

            case "removeItem":
                guard let key = args.first as? String else {
                    callback(nil, "removeItem: missing key")
                    return
                }
                self.defaults.removeObject(forKey: self.keyPrefix + key)
                callback(nil, nil)

            case "getAllKeys":
                let allKeys = self.defaults.dictionaryRepresentation().keys
                    .filter { $0.hasPrefix(self.keyPrefix) }
                    .map { String($0.dropFirst(self.keyPrefix.count)) }
                callback(allKeys, nil)

            case "clear":
                let allKeys = self.defaults.dictionaryRepresentation().keys
                    .filter { $0.hasPrefix(self.keyPrefix) }
                for key in allKeys {
                    self.defaults.removeObject(forKey: key)
                }
                callback(nil, nil)

            default:
                callback(nil, "AsyncStorageModule: Unknown method '\(method)'")
            }
        }
    }
}
