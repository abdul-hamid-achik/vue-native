#if canImport(UIKit)
import Foundation
import WebKit

/// Origin allowlist policy for `VWebView`.
///
/// ## Why this exists
///
/// `VWebView` runs remote content with JavaScript enabled and bridges
/// `window.webkit.messageHandlers.vueNative.postMessage(...)` straight into the
/// Vue app's event stream. Without an origin check, ANY page the view ends up
/// displaying — reached by a redirect, a link, `window.open`, or an injected
/// `location` assignment — can post arbitrary payloads into app logic that then
/// typically calls FileSystem or SecureStorage. Loading `file://` and
/// `javascript:` URIs was also possible.
///
/// ## Default behaviour
///
/// Safe with zero configuration: the origin of the URI the app passed to the
/// `source` prop is allowed, or `about:blank` when the app passed inline `html`.
/// Everything else is refused.
///
/// ## Derived origin vs host origins
///
/// The allowlist has two sources that are kept apart:
///
/// - `derivedOrigins` is the origin of the CURRENT source only. Every source
///   change replaces it, so a previous page's origin stops being trusted.
/// - `hostOrigins` comes from the `allowedOrigins` prop.
///
/// The effective allowlist (``allowedOrigins``) is `hostOrigins` when the host
/// supplied any, otherwise `derivedOrigins`. An `allowedOrigins` prop therefore
/// REPLACES the derived default, and an empty list restores it. Because the
/// two sets are independent, the order in which `source` and `allowedOrigins`
/// arrive does not change the outcome.
final class WebViewOriginPolicy {

    /// Canonical origin string for content loaded with `loadHTMLString`.
    static let aboutBlankOrigin = "about:blank"

    /// Origin of the current source. Replaced on every source change.
    private(set) var derivedOrigins: Set<String> = []
    /// Origins the host supplied through the `allowedOrigins` prop.
    private(set) var hostOrigins: Set<String> = []
    /// `true` only while the current source is inline HTML.
    private(set) var allowsAboutBlank = false

    /// The effective allowlist: host origins when any were supplied, otherwise
    /// the origin derived from the current source.
    var allowedOrigins: Set<String> {
        hostOrigins.isEmpty ? derivedOrigins : hostOrigins
    }

    // MARK: - Configuration

    /// Record the source URI the app requested. This replaces the derived
    /// origin: only an http(s) source yields an origin, and any other scheme
    /// (`file:`, `about:`, `javascript:`) leaves the derived set empty.
    func recordSource(of url: URL) {
        allowsAboutBlank = false
        derivedOrigins = []
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let origin = Self.origin(of: url) else { return }
        derivedOrigins = [origin]
    }

    /// Record inline HTML loaded via `loadHTMLString`, which reports an
    /// `about:blank` security origin. This replaces any previous source origin.
    func recordInlineHTML() {
        allowsAboutBlank = true
        derivedOrigins = [Self.aboutBlankOrigin]
    }

    /// Replace the host-supplied origins. An empty list means "no override":
    /// the derived origin applies again.
    ///
    /// Entries must be full origins (`https://example.com`, `http://localhost:8080`).
    /// A trailing slash and case differences are tolerated; anything else is
    /// dropped rather than guessed at. `about:blank` is never accepted here: that
    /// origin is only trusted for inline HTML the app loaded itself.
    func replaceAllowedOrigins(_ values: [String]) {
        hostOrigins = Set(values.compactMap { Self.normalise(originString: $0) })
            .subtracting([Self.aboutBlankOrigin])
    }

    // MARK: - Decisions

    /// Whether a navigation to `url` may proceed.
    ///
    /// - Parameter isExplicitSourceLoad: `true` only for the URI the app passed
    ///   through the `source` prop. That bypasses the ORIGIN check — the app's
    ///   own declared content is trusted to that extent — but never the SCHEME
    ///   check, so `javascript:` and `file:` sources are still refused.
    func isNavigationAllowed(_ url: URL?, isExplicitSourceLoad: Bool) -> Bool {
        guard let url, let scheme = url.scheme?.lowercased() else { return false }
        if scheme == "about" {
            return allowsAboutBlank
        }
        guard scheme == "http" || scheme == "https" else { return false }
        if isExplicitSourceLoad { return true }
        guard let origin = Self.origin(of: url) else { return false }
        return allowedOrigins.contains(origin)
    }

    /// Whether a `WKScriptMessage` from `origin` may be forwarded to JavaScript.
    ///
    /// A `nil` or opaque origin is only accepted for inline HTML the app loaded
    /// itself. Messages from any other non-allowlisted origin are dropped.
    func isMessageOriginAllowed(_ origin: WKSecurityOrigin?) -> Bool {
        guard let origin else { return false }
        return isMessageOriginAllowed(scheme: origin.protocol, host: origin.host, port: origin.port)
    }

    /// Testable core of ``isMessageOriginAllowed(_:)`` — `WKSecurityOrigin` has
    /// no public initialiser, so the decision is split out from the WebKit type.
    func isMessageOriginAllowed(scheme: String, host: String, port: Int) -> Bool {
        guard let normalised = Self.origin(scheme: scheme, host: host, port: port) else {
            // Opaque origin: WebKit reports empty protocol and host.
            return allowsAboutBlank && scheme.isEmpty && host.isEmpty
        }
        if allowedOrigins.contains(normalised) { return true }
        // `about:blank` is trusted only while the current source is inline HTML,
        // even when a host override has replaced the derived set.
        return normalised == Self.aboutBlankOrigin && allowsAboutBlank
    }

    // MARK: - Origin normalisation

    static func normalise(originString value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        return origin(of: url)
    }

    static func origin(of url: URL?) -> String? {
        guard let url else { return nil }
        let port = url.port ?? defaultPort(for: url.scheme?.lowercased())
        return origin(scheme: url.scheme ?? "", host: url.host ?? "", port: port)
    }

    /// Build a canonical `scheme://host[:port]` origin. Returns `nil` for any
    /// scheme other than http, https and about.
    static func origin(scheme: String, host: String, port: Int) -> String? {
        let loweredScheme = scheme.lowercased()
        if loweredScheme == "about" { return aboutBlankOrigin }
        guard loweredScheme == "http" || loweredScheme == "https" else { return nil }
        let loweredHost = host.lowercased()
        guard !loweredHost.isEmpty else { return nil }
        // WebKit reports port 0 for a scheme's default port, and `URL.port` is
        // nil in the same case — treat both as "no explicit port".
        let isDefaultPort = port == 0 || port == defaultPort(for: loweredScheme)
        return isDefaultPort
            ? "\(loweredScheme)://\(loweredHost)"
            : "\(loweredScheme)://\(loweredHost):\(port)"
    }

    private static func defaultPort(for scheme: String?) -> Int {
        switch scheme?.lowercased() {
        case "https": return 443
        case "http": return 80
        default: return 0
        }
    }
}
#endif
