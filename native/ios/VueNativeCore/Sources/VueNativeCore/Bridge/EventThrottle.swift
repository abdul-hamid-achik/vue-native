#if canImport(UIKit)
import Foundation
import VueNativeShared

/// iOS uses the shared implementation so its throttling behavior stays identical to
/// macOS.
///
/// This file previously held a byte-for-byte private copy of
/// `VueNativeShared.EventThrottle` differing only in the absence of `public`. Two
/// copies of the same throttle drift apart silently, so the duplicate is gone and
/// this is now a typealias — the same arrangement `Bridge/CertificatePinning.swift`
/// already uses.
typealias EventThrottle = VueNativeShared.EventThrottle
#endif
