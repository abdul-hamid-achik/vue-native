import Foundation
import CommonCrypto
import Security

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
    private let pinsLock = NSLock()

    /// A URLSession configured with this object as its delegate for TLS validation.
    /// Lazily created so we don't pay the cost if pinning is never configured.
    public private(set) lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    /// Session that fetch implementations should use for a new request.
    ///
    /// Once any host is pinned, every request must start on the delegate-backed
    /// session so a redirect from an unpinned origin to a pinned destination
    /// cannot bypass the destination's trust challenge. With no configured
    /// pins, the shared session preserves the zero-overhead default path.
    public var requestSession: URLSession {
        pinsLock.lock()
        let hasConfiguredPins = !pins.isEmpty
        pinsLock.unlock()
        return hasConfiguredPins ? session : URLSession.shared
    }

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Configure certificate pins for one or more domains.
    /// Each pin string must be in the format "sha256/<base64-encoded-hash>".
    ///
    /// - Parameter domainPins: Dictionary mapping domain names to arrays of pin strings.
    public func configurePins(_ domainPins: [String: [String]]) {
        var normalizedPins: [String: [String]] = [:]
        for (domain, pinList) in domainPins {
            let hashes = pinList.compactMap { pin -> String? in
                // Accept "sha256/XXXXX" format — strip the prefix
                if pin.hasPrefix("sha256/") {
                    return String(pin.dropFirst(7))
                }
                return nil
            }
            normalizedPins[domain.lowercased()] = hashes
        }

        // URLSession invokes its delegate on a background queue, while bridge
        // calls can configure pins from another queue. Protect the shared map
        // so a challenge cannot race a configuration update.
        pinsLock.lock()
        defer { pinsLock.unlock() }
        for (domain, hashes) in normalizedPins {
            if hashes.isEmpty {
                pins.removeValue(forKey: domain)
            } else {
                pins[domain] = hashes
            }
        }
    }

    /// Returns true if there are pins configured for the given host.
    public func hasPins(for host: String) -> Bool {
        pinsLock.lock()
        defer { pinsLock.unlock() }
        return pins[host.lowercased()] != nil
    }

    /// Remove all configured pins.
    public func clearPins() {
        pinsLock.lock()
        defer { pinsLock.unlock() }
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
        pinsLock.lock()
        let expectedPins = pins[host]
        pinsLock.unlock()

        guard let expectedPins else {
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
            let spkiHash = Self.spkiHash(for: certificate)
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

    /// Compute the base64-encoded SHA-256 hash of the DER SubjectPublicKeyInfo
    /// structure in a certificate. `SecKeyCopyExternalRepresentation` returns
    /// raw key material (PKCS#1 for RSA and X9.63 for EC), not SPKI, so hashing
    /// it is incompatible with standard `sha256/...` pins and OkHttp.
    static func spkiHash(for certificate: SecCertificate) -> String {
        let certificateDER = SecCertificateCopyData(certificate) as Data
        guard let spkiDER = spkiDER(fromCertificateDER: certificateDER) else {
            return ""
        }
        return sha256Base64(of: spkiDER)
    }

    /// Extracts the complete DER SubjectPublicKeyInfo element from an X.509
    /// certificate. This avoids reconstructing RSA/EC algorithm headers by
    /// hand and works for every key algorithm represented in a DER certificate.
    static func spkiDER(fromCertificateDER certificateDER: Data) -> Data? {
        guard let certificate = parseDERElement(in: certificateDER, at: 0, limit: certificateDER.count),
              certificate.tag == 0x30,
              certificate.endOffset == certificateDER.count,
              let tbsCertificate = parseDERElement(
                  in: certificateDER,
                  at: certificate.contentRange.lowerBound,
                  limit: certificate.contentRange.upperBound
              ),
              tbsCertificate.tag == 0x30 else {
            return nil
        }

        var cursor = tbsCertificate.contentRange.lowerBound
        if let version = parseDERElement(
            in: certificateDER,
            at: cursor,
            limit: tbsCertificate.contentRange.upperBound
        ), version.tag == 0xA0 {
            cursor = version.endOffset
        }

        // serialNumber, signature, issuer, validity, subject
        for _ in 0..<5 {
            guard let field = parseDERElement(
                in: certificateDER,
                at: cursor,
                limit: tbsCertificate.contentRange.upperBound
            ) else {
                return nil
            }
            cursor = field.endOffset
        }

        guard let subjectPublicKeyInfo = parseDERElement(
            in: certificateDER,
            at: cursor,
            limit: tbsCertificate.contentRange.upperBound
        ), subjectPublicKeyInfo.tag == 0x30 else {
            return nil
        }

        return certificateDER.subdata(in: subjectPublicKeyInfo.range)
    }

    static func sha256Base64(of data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(bytes.count), &hash)
        }
        return Data(hash).base64EncodedString()
    }

    private struct DERElement {
        let tag: UInt8
        let range: Range<Int>
        let contentRange: Range<Int>

        var endOffset: Int { range.upperBound }
    }

    /// Read a definite-length ASN.1 DER element. X.509 certificates are DER,
    /// so indefinite lengths and encodings that exceed the enclosing sequence
    /// are intentionally rejected.
    private static func parseDERElement(in data: Data, at offset: Int, limit: Int) -> DERElement? {
        guard offset >= 0, limit <= data.count, offset < limit else { return nil }

        let tag = data[data.index(data.startIndex, offsetBy: offset)]
        var cursor = offset + 1
        guard cursor < limit else { return nil }

        let firstLength = data[data.index(data.startIndex, offsetBy: cursor)]
        cursor += 1

        let length: Int
        if firstLength & 0x80 == 0 {
            length = Int(firstLength)
        } else {
            let lengthOctetCount = Int(firstLength & 0x7F)
            guard lengthOctetCount > 0,
                  lengthOctetCount <= MemoryLayout<Int>.size,
                  cursor + lengthOctetCount <= limit else {
                return nil
            }

            var parsedLength = 0
            for _ in 0..<lengthOctetCount {
                let octet = Int(data[data.index(data.startIndex, offsetBy: cursor)])
                guard parsedLength <= (Int.max - octet) / 256 else { return nil }
                parsedLength = parsedLength * 256 + octet
                cursor += 1
            }
            length = parsedLength
        }

        guard length <= limit - cursor else { return nil }
        let endOffset = cursor + length
        return DERElement(
            tag: tag,
            range: offset..<endOffset,
            contentRange: cursor..<endOffset
        )
    }
}
