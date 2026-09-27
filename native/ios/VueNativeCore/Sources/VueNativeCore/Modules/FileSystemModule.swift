#if canImport(UIKit)
import Foundation
import VueNativeShared

/// iOS facade over the shared ``VueNativeShared/FileSystemModule``.
///
/// The iOS package declares its own `NativeModule` protocol, so the shared
/// module cannot be registered directly. Adapting it — rather than keeping a
/// second copy — is what guarantees the sandbox rules cannot drift between iOS
/// and macOS. This mirrors the existing `Bridge/CertificatePinning.swift`
/// arrangement. The previous copy in this file was byte-identical to the shared
/// one apart from access modifiers.
///
/// ## Path confinement (P0-2)
///
/// Every path argument is resolved through ``FileSystemSandbox`` before any I/O:
/// canonicalised, symlinks resolved, the reserved OTA directory denied, and
/// confined to the app's documents/caches/application-support/temporary roots.
/// Previously this module accepted arbitrary absolute paths from JavaScript with
/// no checks at all, so attacker-controlled JS could read, write and delete
/// anywhere the app UID reached — including
/// `<App Support>/VueNativeOTA/bundle-<sha>.js`, which is persistent code
/// execution at the next launch.
final class FileSystemModule: NativeModule {
    let moduleName = "FileSystem"

    private let shared: VueNativeShared.FileSystemModule

    init(
        fileManager: FileManager = .default,
        sandbox: FileSystemSandbox = .shared
    ) {
        shared = VueNativeShared.FileSystemModule(fileManager: fileManager, sandbox: sandbox)
    }

    /// The forwarded method surface, enumerated explicitly.
    ///
    /// This is not decoration: an unrecognised method is rejected here with the
    /// same message the shared module produces, and the explicit list is what
    /// `scripts/check-native-contracts.mjs` reads to verify iOS matches the
    /// runtime's `invokeNativeModule('FileSystem', ...)` calls.
    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "readFile", "writeFile", "deleteFile", "exists":
            shared.invoke(method: method, args: args, callback: callback)
        case "listDirectory", "downloadFile", "getDocumentsPath", "getCachesPath":
            shared.invoke(method: method, args: args, callback: callback)
        case "stat", "mkdir", "copyFile", "moveFile":
            shared.invoke(method: method, args: args, callback: callback)
        default:
            callback(nil, "FileSystemModule: Unknown method '\(method)'")
        }
    }

    func destroy() {
        shared.destroy()
    }
}
#endif
