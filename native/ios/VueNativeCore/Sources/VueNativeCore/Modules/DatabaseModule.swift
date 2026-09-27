#if canImport(UIKit)
import Foundation
import VueNativeShared

/// iOS facade over the shared ``VueNativeShared/DatabaseModule``.
///
/// The iOS package declares its own `NativeModule` protocol, so the shared
/// module cannot be registered directly. Adapting it — rather than keeping a
/// second copy — is what guarantees the security rules cannot drift between iOS
/// and macOS. This mirrors the existing `Bridge/CertificatePinning.swift`
/// arrangement. The previous copy in this file was byte-identical to the shared
/// one apart from access modifiers.
///
/// ## Name validation (P1-3)
///
/// The database name is interpolated into a `<name>.sqlite` path, so
/// ``DatabaseNameValidator`` checks it against `^[A-Za-z0-9_-]{1,64}$` before it
/// reaches the filesystem. The shared implementation also caps
/// `SQLITE_LIMIT_ATTACHED` at 0, so `ATTACH DATABASE` cannot be used from
/// `execute`/`query` as a second write-anywhere primitive.
final class DatabaseModule: NativeModule {
    let moduleName = "Database"

    private let shared: VueNativeShared.DatabaseModule

    init() {
        shared = VueNativeShared.DatabaseModule()
    }

    /// Scratch-directory override used by the package tests.
    init(databaseDirectory: URL) {
        shared = VueNativeShared.DatabaseModule(databaseDirectory: databaseDirectory)
    }

    /// Lifecycle diagnostic used by the package tests.
    var openDatabaseCount: Int { shared.openDatabaseCount }

    /// The forwarded method surface, enumerated explicitly.
    ///
    /// This is not decoration: an unrecognised method is rejected here with the
    /// same message the shared module produces, and the explicit list is what
    /// `scripts/check-native-contracts.mjs` reads to verify iOS matches the
    /// runtime's `invokeNativeModule('Database', ...)` calls.
    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "open", "close":
            shared.invoke(method: method, args: args, callback: callback)
        case "execute", "query", "executeTransaction":
            shared.invoke(method: method, args: args, callback: callback)
        default:
            callback(nil, "DatabaseModule: unknown method '\(method)'")
        }
    }

    func destroy() {
        shared.destroy()
    }
}
#endif
