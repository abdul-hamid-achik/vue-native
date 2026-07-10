#if canImport(UIKit)
import VueNativeShared

/// iOS uses the shared implementation so its pin format, SPKI parsing, and
/// thread-safety behavior stay identical to macOS.
public typealias CertificatePinning = VueNativeShared.CertificatePinning
#endif
