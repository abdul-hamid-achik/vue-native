import AppKit
import UniformTypeIdentifiers
import VueNativeShared

/// macOS-only module that presents an `NSOpenPanel` to pick an image file.
/// Backs the `useImagePicker` composable.
///
/// Methods:
///   - pickImage(options?) -> { "uri": String, "width": Int, "height": Int } | null
///
/// Resolves to `null` when the user cancels. Pixel dimensions are read from the
/// picked file via `NSImage` / `NSBitmapImageRep`.
final class ImagePickerModule: NativeModule {

    let moduleName = "ImagePicker"

    /// Presents the picker and reports the chosen file URL (or `nil` on cancel).
    /// Injected so tests can exercise the result/cancel contract without showing
    /// a modal panel. Defaults to presenting an `NSOpenPanel`.
    private let presentPanel: (_ completion: @escaping (URL?) -> Void) -> Void

    init(presentPanel: ((@escaping (URL?) -> Void) -> Void)? = nil) {
        self.presentPanel = presentPanel ?? ImagePickerModule.presentOpenPanel
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "pickImage":
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    callback(nil, "ImagePickerModule: disposed")
                    return
                }

                self.presentPanel { url in
                    DispatchQueue.main.async {
                        guard let url else {
                            callback(nil, nil) // cancelled -> null
                            return
                        }

                        let dimensions = ImagePickerModule.imageDimensions(at: url)
                        callback([
                            "uri": url.absoluteString,
                            "width": dimensions?.width ?? 0,
                            "height": dimensions?.height ?? 0,
                        ], nil)
                    }
                }
            }

        default:
            callback(nil, "ImagePickerModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Panel presentation

    /// Present a modal `NSOpenPanel` configured for image files.
    private static func presentOpenPanel(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.image]
        panel.title = "Select an image"

        panel.begin { response in
            if response == .OK {
                completion(panel.url)
            } else {
                completion(nil)
            }
        }
    }

    // MARK: - Dimension parsing

    /// Read the pixel dimensions of an image file.
    ///
    /// Prefers the bitmap representation's pixel dimensions (accurate for raster
    /// formats) and falls back to the image size in points. Returns `nil` when
    /// the file cannot be read as an image.
    static func imageDimensions(at url: URL) -> (width: Int, height: Int)? {
        guard let image = NSImage(contentsOf: url) else { return nil }

        if let rep = image.representations.first as? NSBitmapImageRep {
            return (rep.pixelsWide, rep.pixelsHigh)
        }
        return (Int(image.size.width), Int(image.size.height))
    }
}
