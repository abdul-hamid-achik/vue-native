#if canImport(UIKit)
import Foundation
import Security
import VueNativeShared

/// iOS facade over the shared ``VueNativeShared/SecureStorageModule``.
///
/// The iOS package declares its own `NativeModule` protocol, so the shared
/// module cannot be registered directly. Adapting it — rather than keeping a
/// second copy — is what guarantees the Keychain attributes cannot drift between
/// iOS and macOS. This mirrors the existing `Bridge/CertificatePinning.swift`
/// arrangement. The previous copy in this file was byte-identical to the shared
/// one apart from access modifiers.
///
/// ## Access control (P1-5)
///
/// The shared implementation now sets
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` explicitly (previously no
/// accessibility class was set at all, so items inherited the platform default
/// and could be included in a backup and restored onto another device), and
/// offers `getProtected` / `setProtected` / `removeProtected` variants gated by
/// `kSecAttrAccessControl`. `clear()` is scoped to the unprotected service, so a
/// single unauthenticated JavaScript call can no longer wipe gated material.
final class SecureStorageModule: NativeModule {
    let moduleName = "SecureStorage"

    private let shared: VueNativeShared.SecureStorageModule

    /// - Parameters:
    ///   - keychain: backend to use; defaults to the real Security framework.
    ///   - protectedAccessFlags: constraint for the `*Protected` items. Defaults
    ///     to `.userPresence` (biometry when enrolled, otherwise passcode). Pass
    ///     `.biometryCurrentSet` to require biometry specifically.
    init(
        keychain: SecureStorageKeychain = SystemKeychain(),
        protectedAccessFlags: SecAccessControlCreateFlags = .userPresence
    ) {
        shared = VueNativeShared.SecureStorageModule(
            keychain: keychain,
            protectedAccessFlags: protectedAccessFlags
        )
    }

    /// The forwarded method surface, enumerated explicitly.
    ///
    /// This is not decoration: an unrecognised method is rejected here with the
    /// same message the shared module produces, and the explicit list is what
    /// `scripts/check-native-contracts.mjs` reads to verify iOS matches the
    /// runtime's `invokeNativeModule('SecureStorage', ...)` calls.
    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "get", "set", "remove", "clear":
            shared.invoke(method: method, args: args, callback: callback)
        case "getProtected", "setProtected", "removeProtected":
            shared.invoke(method: method, args: args, callback: callback)
        default:
            callback(nil, "SecureStorageModule: Unknown method '\(method)'")
        }
    }

    func destroy() {
        shared.destroy()
    }
}
#endif
