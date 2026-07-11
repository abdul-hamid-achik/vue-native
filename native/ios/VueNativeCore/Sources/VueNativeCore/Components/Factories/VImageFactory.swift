#if canImport(UIKit)
import UIKit
import FlexLayout
import ObjectiveC

/// Factory for VImage — the image display component.
/// Maps to UIImageView on iOS. Loads images from URLs asynchronously using URLSession.
/// Caches decoded images in a shared NSCache.
final class VImageFactory: NativeComponentFactory {

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

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
    private static var loadTaskKey: UInt8 = 0
    private static var requestTokenKey: UInt8 = 0

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
            invalidateImageLoad(for: imageView)

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

    func destroyView(view: UIView) {
        guard let imageView = view as? UIImageView else { return }
        invalidateImageLoad(for: imageView)
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

        let requestToken = UUID().uuidString
        objc_setAssociatedObject(
            imageView,
            &VImageFactory.requestTokenKey,
            requestToken as NSString,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        let task = urlSession.dataTask(with: url) { [weak imageView] data, _, error in
            let decodedImage = data.flatMap(UIImage.init(data:))

            DispatchQueue.main.async { [weak imageView] in
                guard let imageView,
                      VImageFactory.isCurrentRequest(requestToken, for: imageView) else { return }

                VImageFactory.finishRequest(for: imageView)

                if let error {
                    VImageFactory.fireErrorHandler(for: imageView, message: error.localizedDescription)
                    return
                }

                guard let data, let image = decodedImage else {
                    VImageFactory.fireErrorHandler(for: imageView, message: "Failed to decode image")
                    return
                }

                VImageFactory.imageCache.setObject(
                    image,
                    forKey: urlString as NSString,
                    cost: data.count
                )
                imageView.image = image
                imageView.flex.markDirty()
                VImageFactory.fireLoadHandler(for: imageView)
            }
        }

        objc_setAssociatedObject(
            imageView,
            &VImageFactory.loadTaskKey,
            task,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        task.resume()
    }

    @MainActor
    private func invalidateImageLoad(for imageView: UIImageView) {
        let task = objc_getAssociatedObject(
            imageView,
            &VImageFactory.loadTaskKey
        ) as? URLSessionDataTask
        task?.cancel()
        VImageFactory.finishRequest(for: imageView)
    }

    @MainActor
    private static func isCurrentRequest(_ requestToken: String, for imageView: UIImageView) -> Bool {
        let currentToken = objc_getAssociatedObject(
            imageView,
            &VImageFactory.requestTokenKey
        ) as? String
        return currentToken == requestToken
    }

    @MainActor
    private static func finishRequest(for imageView: UIImageView) {
        objc_setAssociatedObject(
            imageView,
            &VImageFactory.loadTaskKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            imageView,
            &VImageFactory.requestTokenKey,
            nil,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
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
