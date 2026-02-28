import Foundation
import CommonCrypto

/// Manages certificate pinning for network requests.
/// Stores SHA-256 pin hashes per domain and provides a URLSession with
/// a delegate that validates server certificates against the pinned hashes.
///
/// Usage from JS (via the bridge):
///   __VN_configurePins({ "api.example.com": ["sha256/BBBBBBB..."] })
///
/// The fetch polyfill uses `CertificatePinning.shared.session` instead of
/// `URLSession.shared` when pins are configured for the request's host.
public final class CertificatePinning: NSObject, URLSessionDelegate {

    public static let shared = CertificatePinning()

    /// Maps lowercase domain to an array of base64-encoded SHA-256 hashes of the
    /// Subject Public Key Info (SPKI).
    private var pins: [String: [String]] = [:]

    /// A URLSession configured with this object as its delegate for TLS validation.
    /// Lazily created so we don't pay the cost if pinning is never configured.
    public private(set) lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Configure certificate pins for one or more domains.
    /// Each pin string must be in the format "sha256/<base64-encoded-hash>".
    ///
    /// - Parameter domainPins: Dictionary mapping domain names to arrays of pin strings.
    public func configurePins(_ domainPins: [String: [String]]) {
        for (domain, pinList) in domainPins {
            let hashes = pinList.compactMap { pin -> String? in
                // Accept "sha256/XXXXX" format — strip the prefix
                if pin.hasPrefix("sha256/") {
                    return String(pin.dropFirst(7))
                }
                return nil
            }
            if !hashes.isEmpty {
                pins[domain.lowercased()] = hashes
            }
        }
    }

    /// Returns true if there are pins configured for the given host.
    public func hasPins(for host: String) -> Bool {
        return pins[host.lowercased()] != nil
    }

    /// Remove all configured pins.
    public func clearPins() {
        pins.removeAll()
    }

    // MARK: - URLSessionDelegate

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host.lowercased()

        // If no pins configured for this host, use default handling
        guard let expectedPins = pins[host] else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate the server trust
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            NSLog("[VueNative CertPin] Trust evaluation failed for %@: %@", host, error?.localizedDescription ?? "unknown")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check each certificate in the chain against our pins
        let certCount = SecTrustGetCertificateCount(serverTrust)
        guard let certChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        for i in 0..<certCount {
            guard i < certChain.count else { continue }
            let certificate = certChain[i]
            let spkiHash = sha256OfSPKI(for: certificate)
            if expectedPins.contains(spkiHash) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        // No pin matched — reject the connection
        NSLog("[VueNative CertPin] Pin validation failed for %@. No matching pin found.", host)
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    // MARK: - SPKI Hashing

    /// Compute the base64-encoded SHA-256 hash of a certificate's Subject Public Key Info.
    private func sha256OfSPKI(for certificate: SecCertificate) -> String {
        guard let publicKey = SecCertificateCopyKey(certificate) else { return "" }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return ""
        }

        // Hash the raw public key data with SHA-256
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        publicKeyData.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(publicKeyData.count), &hash)
        }

        return Data(hash).base64EncodedString()
    }
}
