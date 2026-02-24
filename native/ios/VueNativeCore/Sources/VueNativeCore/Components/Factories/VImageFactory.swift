#if canImport(UIKit)
import UIKit
import FlexLayout
import ObjectiveC

/// Factory for VImage — the image display component.
/// Maps to UIImageView on iOS. Loads images from URLs asynchronously using URLSession.
/// Caches decoded images in a shared NSCache.
final class VImageFactory: NativeComponentFactory {

    // MARK: - Shared image cache

    // NSCache is thread-safe, so nonisolated(unsafe) is correct here.
    nonisolated(unsafe) private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        return cache
    }()

    /// Observer that clears the image cache on memory pressure.
    nonisolated(unsafe) private static let memoryWarningObserver: NSObjectProtocol = {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { _ in
            imageCache.removeAllObjects()
            NSLog("[VueNative] VImageFactory: cleared image cache due to memory warning")
        }
    }()

    // MARK: - Associated object keys

    private static var onLoadKey: UInt8 = 0
    private static var onErrorKey: UInt8 = 0
    private static var currentURLKey: UInt8 = 1

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        // Ensure the memory warning observer is initialized (static let is lazy)
        _ = VImageFactory.memoryWarningObserver

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        _ = imageView.flex
        return imageView
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let imageView = view as? UIImageView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "source":
            guard let sourceDict = value as? [String: Any],
                  let uriString = sourceDict["uri"] as? String,
                  !uriString.isEmpty else {
                imageView.image = nil
                return
            }
            loadImage(uriString, into: imageView)

        case "resizeMode":
            if let mode = value as? String {
                switch mode {
                case "cover": imageView.contentMode = .scaleAspectFill
                case "contain": imageView.contentMode = .scaleAspectFit
                case "stretch": imageView.contentMode = .scaleToFill
                case "center": imageView.contentMode = .center
                default: imageView.contentMode = .scaleAspectFill
                }
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {
        case "load":
            objc_setAssociatedObject(view, &VImageFactory.onLoadKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "error":
            objc_setAssociatedObject(view, &VImageFactory.onErrorKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        switch event {
        case "load":
            objc_setAssociatedObject(view, &VImageFactory.onLoadKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        case "error":
            objc_setAssociatedObject(view, &VImageFactory.onErrorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            break
        }
    }

    // MARK: - Image loading

    @MainActor
    private func loadImage(_ urlString: String, into imageView: UIImageView) {
        // Check cache first
        if let cached = VImageFactory.imageCache.object(forKey: urlString as NSString) {
            imageView.image = cached
            VImageFactory.fireLoadHandler(for: imageView)
            return
        }

        guard let url = URL(string: urlString) else {
            VImageFactory.fireErrorHandler(for: imageView, message: "Invalid URL: \(urlString)")
            return
        }

        // Store current URL to handle rapid source changes
        objc_setAssociatedObject(imageView, &VImageFactory.currentURLKey, urlString as NSString, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        URLSession.shared.dataTask(with: url) { [weak imageView] data, _, error in
            guard let imageView = imageView else { return }

            if let error = error {
                DispatchQueue.main.async { [weak imageView] in
                    guard let imageView = imageView else { return }
                    VImageFactory.fireErrorHandler(for: imageView, message: error.localizedDescription)
                }
                return
            }

            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { [weak imageView] in
                    guard let imageView = imageView else { return }
                    VImageFactory.fireErrorHandler(for: imageView, message: "Failed to decode image")
                }
                return
            }

            let cost = data.count
            VImageFactory.imageCache.setObject(image, forKey: urlString as NSString, cost: cost)

            DispatchQueue.main.async { [weak imageView] in
                guard let imageView = imageView else { return }
                // Only update if the URL hasn't changed
                let current = objc_getAssociatedObject(imageView, &VImageFactory.currentURLKey) as? NSString
                if current as String? == urlString {
                    imageView.image = image
                    imageView.flex.markDirty()
                    VImageFactory.fireLoadHandler(for: imageView)
                }
            }
        }.resume()
    }

    private static func fireLoadHandler(for view: UIView) {
        if let handler = objc_getAssociatedObject(view, &VImageFactory.onLoadKey) as? ((Any?) -> Void) {
            handler(nil)
        }
    }

    private static func fireErrorHandler(for view: UIView, message: String) {
        if let handler = objc_getAssociatedObject(view, &VImageFactory.onErrorKey) as? ((Any?) -> Void) {
            handler(["message": message])
        }
    }
}
#endif
