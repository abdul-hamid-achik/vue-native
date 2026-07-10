import XCTest
import Security
@testable import VueNativeShared

final class VueNativeSharedTests: XCTestCase {
    func testModuleRegistration() {
        let registry = NativeModuleRegistry.shared
        let module = AsyncStorageModule()
        registry.register(module)
        // If we get here without crashing, registration works
        XCTAssertTrue(true)
    }

    func testRegistryDestroysReplacedAndRemovedModules() {
        let registry = NativeModuleRegistry.shared
        registry.removeAll()

        let first = LifecycleTestModule(name: "Lifecycle")
        let replacement = LifecycleTestModule(name: "Lifecycle")
        registry.register(first)
        registry.register(replacement)

        XCTAssertEqual(first.destroyCallCount, 1)
        XCTAssertEqual(replacement.destroyCallCount, 0)

        registry.removeAll()
        XCTAssertEqual(replacement.destroyCallCount, 1)
    }

    func testEventThrottleInit() {
        var callCount = 0
        let throttle = EventThrottle(interval: 0.016) { _ in
            callCount += 1
        }
        throttle.fire("test")
        XCTAssertEqual(callCount, 1)
    }

    func testCertificatePinningNoPins() {
        let pinning = CertificatePinning.shared
        XCTAssertFalse(pinning.hasPins(for: "example.com"))
    }

    func testCertificatePinningConfigure() {
        let pinning = CertificatePinning.shared
        pinning.configurePins(["test.com": ["sha256/abc123"]])
        XCTAssertTrue(pinning.hasPins(for: "test.com"))
        pinning.clearPins()
        XCTAssertFalse(pinning.hasPins(for: "test.com"))
    }

    func testCertificatePinningHashesDERSubjectPublicKeyInfo() {
        // Self-signed RSA certificate generated solely for this deterministic
        // fixture. The expected pin was calculated with:
        // openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER |
        // openssl dgst -sha256 -binary | openssl base64 -A
        let certificateDER = Data(base64Encoded: "MIIDHzCCAgegAwIBAgIUMu+1e87vUfX1EpXsV86C7PYSbAQwDQYJKoZIhvcNAQELBQAwHzEdMBsGA1UEAwwUdnVlLW5hdGl2ZS1zcGtpLXRlc3QwHhcNMjYwNzA5MjIwMzMwWhcNMjYwNzEwMjIwMzMwWjAfMR0wGwYDVQQDDBR2dWUtbmF0aXZlLXNwa2ktdGVzdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOPbGkTKdHKERrLpP/4UiXOGHmI6d/BI4ee6SXm/iyLLkLn2n81bXFKG0rIqoAR7hIi4lJ6uIVSwsZqy+1IXiZNaMufR3pNdcsH5X4+Digwxjh57Txsri3bwTtGHGTgSpX9+cFKLhS6V2e3I/jDr+NnMwwteeBHA7T3OT/GOnEVJG9U+LchtedKW/93nZG90ukJuRFk69JLTY/OA+G1gT5s0QTrHNYXDV7lKuewYOrDPum/bglcSfBW8aueq+XbpYZAVbdZSgWfsbbPo85hRq35Njv3LulunLDePnwCbhCVqdZWXcaR2UfYhHzwhzZmkwlvG56QCDYQxa1dES35nAmMCAwEAAaNTMFEwHQYDVR0OBBYEFIXfFRTd2pOMiHnP8gAwcZOfxSO9MB8GA1UdIwQYMBaAFIXfFRTd2pOMiHnP8gAwcZOfxSO9MA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQADggEBAL2oq854Us/CO+/Rj5hGP7SCdiqiNVwPTKtk7bJ7UtdDEHn7xvQ+HGhutdolSyO7l8L8LKZIXF69yuIHHmgtUMgjAdmUd7uO1Oq2sQ9G17XlJxpP++4nf1tlS8tjOnjHv8jPDg5nRINDn0BRW4SBenhvZVcInqm2mIzhsbLk45Bm7GssVgPdgf2PJN6gA0dbkrLyh4N476WK4LJ5Y7upAV2E28A4hRaSpcmpc1uQ9M8xI7s+I8IvEp5b4GRl56dSSUo9gSnRAFpsW01Vwq0D2zQbWgKbfNbIsEEf0DhpHWj+oLltwX/gR8UccTofd6zsvc9pMEMJfdJyG2t3plcphxs=")
        XCTAssertNotNil(certificateDER)
        guard let certificateDER,
              let certificate = SecCertificateCreateWithData(nil, certificateDER as CFData) else {
            return XCTFail("Expected the SPKI fixture to be a valid certificate")
        }

        XCTAssertEqual(
            CertificatePinning.spkiHash(for: certificate),
            "0mpErEZaN73fzJuGgsnaNpPdmTpi97zzHboW1c3p8y4="
        )
    }

    func testCertificatePinningHashesECPublicKeyInfo() {
        // P-256 certificate fixture. Its expected pin was produced with the
        // same OpenSSL SPKI pipeline documented for users, ensuring Apple and
        // Android use the same public-key representation for EC certificates.
        let certificateDER = Data(base64Encoded: "MIIBmTCCAT+gAwIBAgIUUpxO8lOrAryDLKlGxCdgDY7h7SYwCgYIKoZIzj0EAwIwIjEgMB4GA1UEAwwXdnVlLW5hdGl2ZS1lYy1zcGtpLXRlc3QwHhcNMjYwNzA5MjIyMDMxWhcNMzYwNzA2MjIyMDMxWjAiMSAwHgYDVQQDDBd2dWUtbmF0aXZlLWVjLXNwa2ktdGVzdDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABNkZtygI3GFS0VON71Ej/5Aijf/NXX4qRFiZ6RDSjN7SOf89oJRDWhJ1QL0GfiRx8Vb0/lMvR01FD+ue9XZrgyujUzBRMB0GA1UdDgQWBBQsiwLgfuNFNMLMax7f4hdr3gA/kzAfBgNVHSMEGDAWgBQsiwLgfuNFNMLMax7f4hdr3gA/kzAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIBQyXAv6ZFcvjOabGIxJe4AATRA/kB6DXU5NlVz0KhJ+AiEAgWm4Z7rCMJ4sl1V0jzeA0gczu0qPtyfT0V70SmWpEoI=")
        XCTAssertNotNil(certificateDER)
        guard let certificateDER,
              let certificate = SecCertificateCreateWithData(nil, certificateDER as CFData) else {
            return XCTFail("Expected the EC SPKI fixture to be a valid certificate")
        }

        XCTAssertEqual(
            CertificatePinning.spkiHash(for: certificate),
            "Ux7a9gd0+I358d4yPEzgWM8m7taKY/KHujzEiGR0oFs="
        )
    }

    func testCertificatePinningExtractsOnlyTheSPKIElement() {
        // A minimal DER Certificate/TBSCertificate skeleton. It is not trusted
        // or intended for TLS; it verifies the ASN.1 traversal independently
        // of Security's certificate parser.
        let certificateDER = Data([
            0x30, 0x24,
            0x30, 0x19,
            0x02, 0x01, 0x01,
            0x30, 0x03, 0x06, 0x01, 0x2A,
            0x30, 0x00,
            0x30, 0x00,
            0x30, 0x00,
            0x30, 0x09, 0x30, 0x03, 0x06, 0x01, 0x2A, 0x03, 0x02, 0x00, 0x00,
            0x30, 0x03, 0x06, 0x01, 0x2A,
            0x03, 0x02, 0x00, 0x00,
        ])
        let expectedSPKI = Data([0x30, 0x09, 0x30, 0x03, 0x06, 0x01, 0x2A, 0x03, 0x02, 0x00, 0x00])

        XCTAssertEqual(CertificatePinning.spkiDER(fromCertificateDER: certificateDER), expectedSPKI)
        XCTAssertEqual(
            CertificatePinning.sha256Base64(of: expectedSPKI),
            "PUjoO4UP+ROAvD1LG4Gsh4l6eYM6FEJxW4BRHICn0Gc="
        )
    }

    func testSharedJSPolyfillsJSONEncode() {
        let result = SharedJSPolyfillsJSON.encode("hello")
        XCTAssertEqual(result, "\"hello\"")
    }

    func testSharedJSPolyfillsJSONEncodeSpecialChars() {
        let result = SharedJSPolyfillsJSON.encode("line1\nline2")
        XCTAssertTrue(result.contains("\\n"))
    }
}

private final class LifecycleTestModule: NativeModule {
    let moduleName: String
    private(set) var destroyCallCount = 0

    init(name: String) {
        moduleName = name
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        callback(nil, nil)
    }

    func destroy() {
        destroyCallCount += 1
    }
}
