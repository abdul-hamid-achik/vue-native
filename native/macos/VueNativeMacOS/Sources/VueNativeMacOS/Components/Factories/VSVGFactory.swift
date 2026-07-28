import AppKit
import ObjectiveC
import SVGKit

/// Flipped container view that hosts the NSImageView used to display a rendered
/// SVG. The container participates in the LayoutNode flexbox system; the inner
/// image view is kept filling the container via an autoresizing mask so we do not
/// depend on Auto Layout being resolved by the host window.
final class VSVGView: FlippedView {

    /// The image view that displays the rasterized SVG.
    let imageView: NSImageView

    override init(frame: NSRect) {
        imageView = NSImageView()
        super.init(frame: frame)
        configureImageView()
    }

    required init?(coder: NSCoder) {
        imageView = NSImageView()
        super.init(coder: coder)
        configureImageView()
    }

    private func configureImageView() {
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = bounds
        imageView.autoresizingMask = [.width, .height]
        addSubview(imageView)
        setAccessibilityRole(.image)
    }
}

/// Factory for VSVG — renders Scalable Vector Graphics natively via SVGKit.
///
/// Accepts a `source` prop with exactly one of:
/// - `{ svg: "<svg>…</svg>" }` — inline SVG markup (parsed synchronously).
/// - `{ asset: "name" }` — a bundled SVG asset (resolved via `SVGKImage.imageNamed`).
/// - `{ uri: "https://…" }` — a remote SVG (downloaded asynchronously).
///
/// The SVGKImage is rasterized to an NSImage and shown in an NSImageView, which
/// gives us free `imageScaling` and `contentTintColor` support (mirroring
/// VImageFactory). Fires `load` on success and `error` on any failure; invalid
/// SVG never crashes — it reports `error`.
final class VSVGFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var loadHandlerKey: UInt8 = 0
    private static var errorHandlerKey: UInt8 = 0
    private static var tintColorKey: UInt8 = 0
    private static var loadTaskKey: UInt8 = 0
    private static var requestTokenKey: UInt8 = 0

    /// Fallback render size used when an SVG declares no intrinsic size
    /// (no viewBox / width / height). SVGKit asserts when asked to rasterize a
    /// sizeless image, so we always guarantee a concrete size before exporting.
    private static let fallbackSize = CGSize(width: 100, height: 100)

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let view = VSVGView()
        view.ensureLayoutNode()
        return view
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let svgView = view as? VSVGView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "source":
            // Cancel any in-flight remote load before starting a new one.
            cancelLoad(on: svgView)
            applySource(value, to: svgView)

        case "tintColor":
            applyTintColor(value, to: svgView)

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
        case "load":
            objc_setAssociatedObject(
                view, &VSVGFactory.loadHandlerKey,
                handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "error":
            objc_setAssociatedObject(
                view, &VSVGFactory.errorHandlerKey,
                handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        switch event {
        case "load":
            objc_setAssociatedObject(
                view, &VSVGFactory.loadHandlerKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "error":
            objc_setAssociatedObject(
                view, &VSVGFactory.errorHandlerKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    func destroyView(view: NSView) {
        cancelLoad(on: view)
    }

    // MARK: - Source dispatch

    private func applySource(_ value: Any?, to view: VSVGView) {
        if let markup = sourceField(value, key: "svg"), !markup.isEmpty {
            renderInline(markup, into: view)
            return
        }

        if let asset = sourceField(value, key: "asset"), !asset.isEmpty {
            renderAsset(asset, into: view)
            return
        }

        if let uri = sourceField(value, key: "uri"), !uri.isEmpty {
            renderURI(uri, into: view)
            return
        }

        // No recognized source — clear any previous image.
        view.imageView.image = nil
    }

    /// Extract a string field from a source dictionary (`[String: Any]` or NSDictionary).
    private func sourceField(_ value: Any?, key: String) -> String? {
        if let source = value as? [String: Any] {
            return source[key] as? String
        }
        if let source = value as? NSDictionary {
            return source[key] as? String
        }
        return nil
    }

    // MARK: - SVGKImage creation

    /// Number of parse attempts before giving up. SVGKit's first-in-process parse
    /// fails until its parser warms up, so we allow a couple of retries.
    private static let maxParseAttempts = 3

    /// Create an SVGKImage by running a parse closure up to `maxParseAttempts`
    /// times, spinning the run loop briefly between attempts.
    ///
    /// SVGKit's very first parse in a process returns nil until its libxml-based
    /// parser finishes initializing on the run loop (the parse yields no document,
    /// so `initWithParsedSVG:` returns nil); spinning the run loop lets that settle
    /// and the next attempt succeeds. Later renders succeed on the first attempt and
    /// never spin.
    ///
    /// The closure MUST build a fresh `SVGKSource` on every invocation — SVGKit
    /// consumes a source while parsing it, so a reused source will not re-parse.
    /// Retrying is harmless for genuinely invalid input (it stays nil), so this
    /// never turns a real failure into a false success.
    private func parseWithWarmup(_ parse: () -> SVGKImage?) -> SVGKImage? {
        for attempt in 0..<VSVGFactory.maxParseAttempts {
            if let image = parse() {
                return image
            }
            if attempt < VSVGFactory.maxParseAttempts - 1 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
        }
        return nil
    }

    // MARK: - Inline markup

    private func renderInline(_ markup: String, into view: VSVGView) {
        let svgImage = parseWithWarmup {
            SVGKImage(source: SVGKSourceString.source(fromContentsOf: markup))
        }
        guard let svgImage else {
            view.imageView.image = nil
            fireErrorEvent(for: view, message: "Invalid SVG markup")
            return
        }
        finishRender(svgImage, into: view)
    }

    // MARK: - Bundled asset

    private func renderAsset(_ name: String, into view: VSVGView) {
        // SVGKImage(named:) looks in the app's Documents folder then the main
        // bundle, appending ".svg" when missing. It may return a non-nil image
        // whose parse failed; finishRender validates the parse result.
        let svgImage = parseWithWarmup { SVGKImage(named: name) }
        guard let svgImage else {
            view.imageView.image = nil
            fireErrorEvent(for: view, message: "SVG asset not found: \(name)")
            return
        }
        finishRender(svgImage, into: view)
    }

    // MARK: - Remote URI

    private func renderURI(_ uri: String, into view: VSVGView) {
        guard let url = URL(string: uri) else {
            view.imageView.image = nil
            fireErrorEvent(for: view, message: "Invalid SVG URI: \(uri)")
            return
        }

        // Local file paths (no scheme, or file://) are parsed synchronously.
        if url.scheme == nil || url.scheme == "file" {
            let path = url.scheme == nil ? uri : url.path
            let svgImage = parseWithWarmup {
                SVGKImage(source: SVGKSourceLocalFile.source(fromFilename: path))
            }
            guard let svgImage else {
                view.imageView.image = nil
                fireErrorEvent(for: view, message: "SVG file not found: \(uri)")
                return
            }
            finishRender(svgImage, into: view)
            return
        }

        guard url.scheme == "http" || url.scheme == "https" else {
            view.imageView.image = nil
            fireErrorEvent(for: view, message: "Unsupported SVG URI scheme: \(uri)")
            return
        }

        let requestToken = UUID().uuidString
        objc_setAssociatedObject(
            view, &VSVGFactory.requestTokenKey,
            requestToken as NSString, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        let task = urlSession.dataTask(with: url) { [weak self, weak view] data, _, error in
            DispatchQueue.main.async {
                guard let self, let view, VSVGFactory.isCurrentRequest(requestToken, for: view) else { return }
                VSVGFactory.finishRequest(for: view)

                if let error = error {
                    self.fireErrorEvent(for: view, message: error.localizedDescription)
                    return
                }

                guard let data = data, !data.isEmpty else {
                    self.fireErrorEvent(for: view, message: "Empty SVG response")
                    return
                }

                let svgImage = self.parseWithWarmup {
                    SVGKImage(source: SVGKSourceNSData.source(from: data, urlForRelativeLinks: nil))
                }
                guard let svgImage else {
                    self.fireErrorEvent(for: view, message: "Failed to parse SVG response")
                    return
                }
                self.finishRender(svgImage, into: view)
            }
        }
        objc_setAssociatedObject(
            view, &VSVGFactory.loadTaskKey,
            task, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        task.resume()
    }

    private func cancelLoad(on view: NSView) {
        let task = objc_getAssociatedObject(view, &VSVGFactory.loadTaskKey) as? URLSessionDataTask
        task?.cancel()
        VSVGFactory.finishRequest(for: view)
    }

    private static func isCurrentRequest(_ token: String, for view: NSView) -> Bool {
        let current = objc_getAssociatedObject(view, &VSVGFactory.requestTokenKey) as? String
        return current == token
    }

    private static func finishRequest(for view: NSView) {
        objc_setAssociatedObject(view, &VSVGFactory.loadTaskKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VSVGFactory.requestTokenKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Render + validate

    /// Validate a parsed SVGKImage, rasterize it to an NSImage, apply any active
    /// tint, install it on the image view, and fire `load`. Reports `error`
    /// (never crashes) when the parse failed or rasterization is impossible.
    private func finishRender(_ svgImage: SVGKImage, into view: VSVGView) {
        let parse = svgImage.parseErrorsAndWarnings
        let fatalCount = parse?.errorsFatal?.count ?? 0
        let libXMLFailed = parse?.libXMLFailed ?? false

        guard svgImage.domTree != nil, !libXMLFailed, fatalCount == 0 else {
            view.imageView.image = nil
            fireErrorEvent(for: view, message: "Invalid SVG markup")
            return
        }

        // Guarantee a concrete size before rasterizing — SVGKit asserts otherwise.
        if !svgImage.hasSize() {
            svgImage.size = VSVGFactory.fallbackSize
        }

        guard let nsImage = svgImage.nsImage else {
            view.imageView.image = nil
            fireErrorEvent(for: view, message: "Failed to rasterize SVG")
            return
        }

        // Re-apply an active tint to the freshly rendered image.
        if let tint = objc_getAssociatedObject(view, &VSVGFactory.tintColorKey) as? NSColor {
            nsImage.isTemplate = true
            view.imageView.contentTintColor = tint
        }

        view.imageView.image = nsImage
        fireLoadEvent(for: view, size: nsImage.size)
    }

    // MARK: - Tint

    private func applyTintColor(_ value: Any?, to view: VSVGView) {
        if let hex = value as? String, let color = NSColor.fromHex(hex) {
            objc_setAssociatedObject(
                view, &VSVGFactory.tintColorKey,
                color, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            view.imageView.contentTintColor = color
            view.imageView.image?.isTemplate = true
        } else {
            objc_setAssociatedObject(
                view, &VSVGFactory.tintColorKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            view.imageView.contentTintColor = nil
            view.imageView.image?.isTemplate = false
        }
    }

    // MARK: - Event helpers

    private func fireLoadEvent(for view: VSVGView, size: CGSize) {
        guard let handler = objc_getAssociatedObject(
            view, &VSVGFactory.loadHandlerKey
        ) as? (Any?) -> Void else { return }

        let payload: [String: Any] = [
            "width": size.width,
            "height": size.height
        ]
        handler(payload)
    }

    private func fireErrorEvent(for view: VSVGView, message: String) {
        guard let handler = objc_getAssociatedObject(
            view, &VSVGFactory.errorHandlerKey
        ) as? (Any?) -> Void else { return }

        let payload: [String: Any] = [
            "message": message
        ]
        handler(payload)
    }
}
