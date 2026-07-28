#if canImport(UIKit)
import UIKit
import SVGKit
import ObjectiveC
import FlexLayout

/// Factory for VSVG — renders SVG content via SVGKit.
///
/// The `source` prop is a dictionary with exactly one of:
/// - `svg`: inline SVG markup string (parsed synchronously)
/// - `asset`: name of an SVG shipped in the app bundle (`SVGKImage.imageNamed:`)
/// - `uri`: remote SVG URL (downloaded + parsed off the main thread)
///
/// Fires `load` when an SVG renders successfully and `error` when parsing or
/// loading fails. An optional `tintColor` prop recolors the artwork (see
/// `applyTint` for the best-effort behaviour and its limitations).
final class VSVGFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var onLoadKey: UInt8 = 0
    private static var onErrorKey: UInt8 = 1
    private static var tintColorKey: UInt8 = 2
    private static var requestTokenKey: UInt8 = 3

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        // Start with an empty SVGKImage so the view is valid before any source
        // is applied (the same pattern SVGKit's own SwiftUI wrapper uses). The
        // initializer is imported as optional, so fall back to a plain frame
        // init (which leaves `image` unset) rather than force-unwrapping.
        let svgView = SVGKFastImageView(svgkImage: SVGKImage()) ?? SVGKFastImageView(frame: .zero)
        // Touch FlexLayout so Yoga tracks this view.
        _ = svgView.flex
        return svgView
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let svgView = view as? SVGKFastImageView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "source":
            // Invalidate any in-flight remote load before starting a new one so
            // a late callback can never overwrite a newer source.
            _ = VSVGFactory.bumpToken(for: svgView)

            guard let sourceDict = value as? [String: Any] else {
                svgView.image = SVGKImage()
                return
            }

            if let svgMarkup = sourceDict["svg"] as? String, !svgMarkup.isEmpty {
                loadInline(svgMarkup, into: svgView)
            } else if let assetName = sourceDict["asset"] as? String, !assetName.isEmpty {
                loadAsset(assetName, into: svgView)
            } else if let uriString = sourceDict["uri"] as? String, !uriString.isEmpty {
                loadRemote(uriString, into: svgView)
            } else {
                svgView.image = SVGKImage()
            }

        case "tintColor":
            if let hex = value as? String, let color = UIColor.fromHex(hex) {
                objc_setAssociatedObject(
                    svgView,
                    &VSVGFactory.tintColorKey,
                    color,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
                if let image = svgView.image {
                    VSVGFactory.applyTint(color, to: image)
                    svgView.setNeedsDisplay()
                }
            } else {
                // nil or invalid value clears the stored tint. Already-rendered
                // colors are left untouched (we cannot recover the originals).
                objc_setAssociatedObject(
                    svgView,
                    &VSVGFactory.tintColorKey,
                    nil,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
        case "load":
            objc_setAssociatedObject(view, &VSVGFactory.onLoadKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "error":
            objc_setAssociatedObject(view, &VSVGFactory.onErrorKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        switch event {
        case "load":
            objc_setAssociatedObject(view, &VSVGFactory.onLoadKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "error":
            objc_setAssociatedObject(view, &VSVGFactory.onErrorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            break
        }
    }

    func destroyView(view: UIView) {
        guard view is SVGKFastImageView else { return }
        // Bump the token so any in-flight remote callback is ignored, then drop
        // the retained handlers/tint.
        _ = VSVGFactory.bumpToken(for: view)
        objc_setAssociatedObject(view, &VSVGFactory.onLoadKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VSVGFactory.onErrorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(view, &VSVGFactory.tintColorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    // MARK: - Loading

    @MainActor
    private func loadInline(_ markup: String, into svgView: SVGKFastImageView) {
        guard let source = SVGKSourceString.source(fromContentsOf: markup),
              let image = SVGKImage(source: source),
              image.domTree != nil else {
            VSVGFactory.fireErrorHandler(for: svgView, message: "Failed to parse inline SVG")
            return
        }
        VSVGFactory.finish(image, into: svgView)
    }

    @MainActor
    private func loadAsset(_ name: String, into svgView: SVGKFastImageView) {
        // SVGKImage.imageNamed: hits an NSParameterAssert (crash) when the file
        // is missing, because it forwards a nil source to imageWithSource:. We
        // therefore verify the asset exists first and surface a clean `error`
        // event instead of crashing.
        guard VSVGFactory.assetExists(name) else {
            VSVGFactory.fireErrorHandler(for: svgView, message: "Asset not found: \(name)")
            return
        }
        guard let image = SVGKImage(named: name), image.domTree != nil else {
            VSVGFactory.fireErrorHandler(for: svgView, message: "Failed to parse SVG asset: \(name)")
            return
        }
        VSVGFactory.finish(image, into: svgView)
    }

    /// Replicates SVGKit's `SVGKSourceLocalFile internalSourceAnywhereInBundle:`
    /// lookup (app bundle first, then the Documents folder, defaulting to the
    /// `svg` extension) so we can detect a missing asset BEFORE calling
    /// `SVGKImage.imageNamed:`, which asserts on a nil source.
    private static func assetExists(_ name: String) -> Bool {
        let nsName = name as NSString
        let baseName = nsName.deletingPathExtension
        let ext = nsName.pathExtension.isEmpty ? "svg" : nsName.pathExtension

        if Bundle.main.url(forResource: baseName, withExtension: ext) != nil {
            return true
        }

        guard let documents = NSSearchPathForDirectoriesInDomains(
            .documentDirectory,
            .userDomainMask,
            true
        ).first else {
            return false
        }
        // Build the path with plain interpolation to avoid the SDK's ambiguous
        // NSString path-extension overloads (one of which takes a UTType).
        let path = "\(documents)/\(baseName).\(ext)"
        return FileManager.default.fileExists(atPath: path)
    }

    @MainActor
    private func loadRemote(_ urlString: String, into svgView: SVGKFastImageView) {
        guard let url = URL(string: urlString) else {
            VSVGFactory.fireErrorHandler(for: svgView, message: "Invalid URL: \(urlString)")
            return
        }

        let token = VSVGFactory.bumpToken(for: svgView)

        DispatchQueue.global(qos: .userInitiated).async {
            // SVGKImage(contentsOf:) downloads and parses synchronously, so it
            // runs on a background queue and never blocks the main thread.
            let parsed = SVGKImage(contentsOf: url)
            DispatchQueue.main.async { [weak svgView] in
                guard let svgView, VSVGFactory.isCurrentToken(token, for: svgView) else { return }
                if let parsed, parsed.domTree != nil {
                    VSVGFactory.finish(parsed, into: svgView)
                } else {
                    VSVGFactory.fireErrorHandler(
                        for: svgView,
                        message: "Failed to load SVG from URL: \(urlString)"
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    /// Install a successfully parsed image: apply any stored tint, mark layout
    /// dirty, request a redraw and fire the `load` event.
    @MainActor
    private static func finish(_ image: SVGKImage, into svgView: SVGKFastImageView) {
        if let tint = objc_getAssociatedObject(svgView, &VSVGFactory.tintColorKey) as? UIColor {
            VSVGFactory.applyTint(tint, to: image)
        }
        svgView.image = image
        svgView.flex.markDirty()
        svgView.setNeedsDisplay()
        VSVGFactory.fireLoadHandler(for: svgView, image: image)
    }

    /// Best-effort monochrome tint.
    ///
    /// SVGKit renders vector artwork into `CAShapeLayer`s, so this recursively
    /// walks the SVG's layer tree and overrides each shape layer's `fillColor`
    /// and `strokeColor` with `color`. SVGKit exposes no first-party tint API,
    /// and `UIView.tintColor` does not affect the rendered CALayer content.
    ///
    /// Limitation: this flattens a multi-color SVG to a single color
    /// (icon-style tint); the original per-element colors are not preserved and
    /// cannot be restored once overwritten.
    private static func applyTint(_ color: UIColor, to image: SVGKImage) {
        guard let root = image.caLayerTree else { return }
        tintLayer(root, color: color)
    }

    private static func tintLayer(_ layer: CALayer, color: UIColor) {
        if let shape = layer as? CAShapeLayer {
            if shape.fillColor != nil {
                shape.fillColor = color.cgColor
            }
            if shape.strokeColor != nil {
                shape.strokeColor = color.cgColor
            }
        }
        for sublayer in layer.sublayers ?? [] {
            tintLayer(sublayer, color: color)
        }
    }

    // MARK: - Request token (guards against stale remote loads)

    @MainActor
    private static func bumpToken(for view: UIView) -> String {
        let token = UUID().uuidString
        objc_setAssociatedObject(
            view,
            &VSVGFactory.requestTokenKey,
            token as NSString,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        return token
    }

    @MainActor
    private static func isCurrentToken(_ token: String, for view: UIView) -> Bool {
        let current = objc_getAssociatedObject(view, &VSVGFactory.requestTokenKey) as? String
        return current == token
    }

    // MARK: - Event dispatch

    private static func fireLoadHandler(for view: UIView, image: SVGKImage) {
        guard let handler = objc_getAssociatedObject(view, &VSVGFactory.onLoadKey) as? ((Any?) -> Void) else {
            return
        }
        // Include intrinsic dimensions when the SVG defines a legal size so
        // consumers can size layouts before the view is laid out. Reading
        // `.size` on an SVG with no defined size asserts, so guard with
        // `hasSize()` first.
        var payload: [String: Any] = [:]
        if image.hasSize() {
            payload["width"] = image.size.width
            payload["height"] = image.size.height
        }
        handler(payload)
    }

    private static func fireErrorHandler(for view: UIView, message: String) {
        if let handler = objc_getAssociatedObject(view, &VSVGFactory.onErrorKey) as? ((Any?) -> Void) {
            handler(["message": message])
        }
    }
}
#endif
