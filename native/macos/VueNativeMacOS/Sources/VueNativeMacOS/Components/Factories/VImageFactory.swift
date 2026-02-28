import AppKit
import ObjectiveC

/// Factory for VImage — async image loading component.
/// Maps to NSImageView with URL-based async loading via URLSession,
/// NSCache for in-memory caching, and various resize modes.
final class VImageFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var loadTaskKey: UInt8 = 0
    private static var loadHandlerKey: UInt8 = 0
    private static var errorHandlerKey: UInt8 = 0

    // MARK: - Shared image cache

    private static let imageCache = NSCache<NSString, NSImage>()

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.ensureLayoutNode()
        return imageView
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let imageView = view as? NSImageView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "source", "src":
            // Cancel any in-flight load
            cancelLoad(on: view)

            guard let source = value as? String, !source.isEmpty else {
                imageView.image = nil
                return
            }

            // Try loading as URL
            if let url = URL(string: source), url.scheme == "https" || url.scheme == "http" {
                loadImageFromURL(url, into: imageView)
            } else {
                // Try loading as local resource name
                if let image = NSImage(named: source) {
                    imageView.image = image
                    fireLoadEvent(for: imageView, image: image)
                } else if let image = loadFromBundle(source) {
                    imageView.image = image
                    fireLoadEvent(for: imageView, image: image)
                } else {
                    fireErrorEvent(for: imageView, message: "Image not found: \(source)")
                }
            }

        case "resizeMode":
            guard let mode = value as? String else { return }
            switch mode {
            case "cover":
                imageView.imageScaling = .scaleProportionallyUpOrDown
                imageView.layer?.contentsGravity = .resizeAspectFill
                imageView.layer?.masksToBounds = true
            case "contain":
                imageView.imageScaling = .scaleProportionallyDown
                imageView.layer?.contentsGravity = .resizeAspect
            case "stretch":
                imageView.imageScaling = .scaleAxesIndependently
                imageView.layer?.contentsGravity = .resize
            case "center":
                imageView.imageScaling = .scaleNone
                imageView.layer?.contentsGravity = .center
            default:
                imageView.imageScaling = .scaleProportionallyUpOrDown
            }

        case "tintColor":
            if let colorStr = value as? String {
                imageView.contentTintColor = NSColor.fromHex(colorStr)
                // Set image as template so tint applies
                imageView.image?.isTemplate = true
            } else {
                imageView.contentTintColor = nil
            }

        case "blurRadius":
            if let radius = value as? Double, radius > 0 {
                applyBlur(to: imageView, radius: radius)
            } else {
                // Remove blur
                imageView.layer?.filters = nil
            }

        case "defaultSource":
            // Set placeholder image
            if let source = value as? String {
                if let image = NSImage(named: source) {
                    // Only set if no image is currently loaded
                    if imageView.image == nil {
                        imageView.image = image
                    }
                } else if let image = loadFromBundle(source) {
                    if imageView.image == nil {
                        imageView.image = image
                    }
                }
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
        case "load":
            objc_setAssociatedObject(
                view, &VImageFactory.loadHandlerKey,
                handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "error":
            objc_setAssociatedObject(
                view, &VImageFactory.errorHandlerKey,
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
                view, &VImageFactory.loadHandlerKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "error":
            objc_setAssociatedObject(
                view, &VImageFactory.errorHandlerKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    // MARK: - Async image loading

    private func loadImageFromURL(_ url: URL, into imageView: NSImageView) {
        let cacheKey = url.absoluteString as NSString

        // Check cache first
        if let cached = VImageFactory.imageCache.object(forKey: cacheKey) {
            imageView.image = cached
            fireLoadEvent(for: imageView, image: cached)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak imageView] data, response, error in
            DispatchQueue.main.async {
                guard let imageView = imageView else { return }

                if let error = error {
                    self.fireErrorEvent(for: imageView, message: error.localizedDescription)
                    return
                }

                guard let data = data, let image = NSImage(data: data) else {
                    self.fireErrorEvent(for: imageView, message: "Failed to decode image data")
                    return
                }

                // Cache the image
                VImageFactory.imageCache.setObject(image, forKey: cacheKey)

                imageView.image = image
                self.fireLoadEvent(for: imageView, image: image)
            }
        }
        task.resume()

        // Store the task so we can cancel it if source changes
        objc_setAssociatedObject(
            imageView, &VImageFactory.loadTaskKey,
            task, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private func cancelLoad(on view: NSView) {
        if let task = objc_getAssociatedObject(view, &VImageFactory.loadTaskKey) as? URLSessionDataTask {
            task.cancel()
            objc_setAssociatedObject(
                view, &VImageFactory.loadTaskKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private func loadFromBundle(_ name: String) -> NSImage? {
        // Try loading from main bundle by path
        if let path = Bundle.main.path(forResource: name, ofType: nil) {
            return NSImage(contentsOfFile: path)
        }
        // Try without extension
        let components = name.split(separator: ".")
        if components.count >= 2 {
            let baseName = String(components.dropLast().joined(separator: "."))
            let ext = String(components.last!)
            if let path = Bundle.main.path(forResource: baseName, ofType: ext) {
                return NSImage(contentsOfFile: path)
            }
        }
        return nil
    }

    // MARK: - Event helpers

    private func fireLoadEvent(for imageView: NSImageView, image: NSImage) {
        guard let handler = objc_getAssociatedObject(
            imageView, &VImageFactory.loadHandlerKey
        ) as? (Any?) -> Void else { return }

        let payload: [String: Any] = [
            "width": image.size.width,
            "height": image.size.height
        ]
        handler(payload)
    }

    private func fireErrorEvent(for imageView: NSImageView, message: String) {
        guard let handler = objc_getAssociatedObject(
            imageView, &VImageFactory.errorHandlerKey
        ) as? (Any?) -> Void else { return }

        let payload: [String: Any] = [
            "error": message
        ]
        handler(payload)
    }

    // MARK: - Blur effect

    private func applyBlur(to imageView: NSImageView, radius: Double) {
        guard let image = imageView.image,
              let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return }

        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(radius, forKey: kCIInputRadiusKey)

        guard let outputImage = filter?.outputImage else { return }

        let context = CIContext()
        let extent = ciImage.extent
        guard let cgImage = context.createCGImage(outputImage, from: extent) else { return }

        let blurredImage = NSImage(cgImage: cgImage, size: image.size)
        imageView.image = blurredImage
    }
}
