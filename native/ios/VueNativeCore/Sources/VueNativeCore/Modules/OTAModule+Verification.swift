#if canImport(UIKit)
import CryptoKit
import Foundation

// MARK: - Publisher verification (ECDSA P-256)

extension OTAModule {
    /// Verify downloaded bundle bytes: SHA-256 integrity, then the ECDSA P-256
    /// (SHA-256, DER) publisher signature.
    ///
    /// Two signature formats are accepted, in this order:
    ///
    /// 1. The signed manifest (preferred). The signature covers the UTF-8 bytes of
    ///    `vue-native-ota-v1\n<version>\n<sha256>`, so a valid manifest signature
    ///    also authenticates the version string.
    /// 2. Legacy. The signature covers the raw bundle bytes. That does not bind the
    ///    version, so it is refused when the host sets
    ///    ``requiresSignedManifest`` (see ``signedManifestRequired(bundle:)``).
    ///
    /// CryptoKit's `isValidSignature(_:for:)` hashes the supplied data internally
    /// (SHA-256 for P-256), so signatures are checked over the raw message bytes,
    /// not a pre-computed digest. The signing side must sign those same bytes
    /// (`signature(for: message)`).
    ///
    /// Publisher authentication is MANDATORY. When the host has not configured a
    /// key this returns ``missingPublisherKeyMessage`` instead of accepting the
    /// bundle on its hash alone — integrity without authentication only proves
    /// the bytes were not corrupted in transit, not who produced them.
    ///
    /// - Parameter version: the trimmed version string the update claims.
    /// - Returns: `nil` when the bundle passes every check, or a rejection message.
    func verificationError(
        for data: Data,
        expectedHash: String,
        signature: String?,
        version: String
    ) -> String? {
        guard !data.isEmpty, Self.isReadableJavaScript(data) else {
            return "Downloaded bundle is empty or is not valid UTF-8 text"
        }
        let expected = expectedHash.lowercased()
        let actualHash = Self.sha256(data: data)
        guard actualHash == expected else {
            return "Bundle integrity check failed. Expected: \(expected), got: \(actualHash)"
        }

        guard let verifyKey = self.verifyKey else {
            return Self.missingPublisherKeyMessage
        }
        guard let signature, !signature.isEmpty else {
            return "OTA update rejected: signature required when a verify key is configured"
        }
        // `.ignoreUnknownCharacters` accepts the line breaks that common `base64`
        // tools insert every 64 or 76 characters; the DER parse and the signature
        // check still reject anything that is not a valid signature.
        guard let signatureData = Data(base64Encoded: signature, options: .ignoreUnknownCharacters),
              let ecdsaSignature = try? P256.Signing.ECDSASignature(derRepresentation: signatureData) else {
            return "OTA update rejected: signature verification failed"
        }
        if verifyKey.isValidSignature(ecdsaSignature, for: Self.manifestMessage(version: version, sha256: expected)) {
            return nil
        }
        if verifyKey.isValidSignature(ecdsaSignature, for: data) {
            guard !requiresSignedManifest else {
                return Self.signedManifestRequiredMessage
            }
            #if DEBUG
            NSLog(
                "[VueNative OTA] Accepted a legacy bundle-bytes signature. Sign the release manifest "
                + "instead; it becomes mandatory when '%@' is set.",
                Self.requireSignedManifestInfoPlistKey
            )
            #endif
            return nil
        }
        return "OTA update rejected: signature verification failed"
    }

    /// The message a publisher signs for a release manifest: the domain tag, the
    /// version and the bundle SHA-256, newline-separated, UTF-8, no trailing newline.
    static func manifestMessage(version: String, sha256: String) -> Data {
        Data("\(manifestDomain)\n\(version)\n\(sha256.lowercased())".utf8)
    }
}
#endif
