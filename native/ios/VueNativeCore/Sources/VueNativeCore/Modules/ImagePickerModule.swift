#if canImport(UIKit)
import UIKit
import PhotosUI

/// Native module for picking a single image from the photo library.
///
/// Methods:
///   - pickImage() -> { "uri": String, "width": Int, "height": Int } | null
///
/// Uses `PHPickerViewController`, which runs out-of-process and therefore does
/// not require any photo-library permission prompt. When the user selects an
/// image it is re-encoded as JPEG into a temporary file and the resulting
/// `file://` URI plus pixel dimensions are returned. When the user cancels the
/// callback resolves with `null` (nil result, no error) so the JS side can
/// distinguish a cancellation from a failure.
final class ImagePickerModule: NativeModule {
    let moduleName = "ImagePicker"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "pickImage":
            DispatchQueue.main.async {
                self.presentPicker(callback: callback)
            }

        default:
            callback(nil, "ImagePickerModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Presentation

    private func presentPicker(callback: @escaping (Any?, String?) -> Void) {
        guard let rootVC = UIApplication.shared.vn_topViewController else {
            callback(nil, "ImagePicker: no view controller available to present the picker")
            return
        }

        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = .images

        let picker = PHPickerViewController(configuration: configuration)
        let delegate = ImagePickerDelegate(callback: callback)
        picker.delegate = delegate
        // The picker only holds a weak reference to its delegate, so retain the
        // delegate for the lifetime of the presentation via an associated object.
        objc_setAssociatedObject(
            picker,
            &ImagePickerModule.delegateKey,
            delegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        rootVC.present(picker, animated: true)
    }

    private static var delegateKey: UInt8 = 0

    // MARK: - Result processing

    /// Process the picker results. Exposed internally (and kept free of any
    /// `PHPickerViewController` reference) so the cancellation contract can be
    /// unit-tested without presenting UI.
    ///
    /// An empty `results` array means the user cancelled and resolves the
    /// callback with `nil` (JavaScript `null`) and no error.
    static func processPickerResults(
        _ results: [PHPickerResult],
        callback: @escaping (Any?, String?) -> Void
    ) {
        guard let result = results.first else {
            callback(nil, nil)
            return
        }

        result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
            guard let image = object as? UIImage else {
                callback(nil, error?.localizedDescription ?? "ImagePicker: failed to load image")
                return
            }
            DispatchQueue.main.async {
                guard let url = ImagePickerModule.writeTemporaryJPEG(image) else {
                    callback(nil, "ImagePicker: failed to write image to a temporary file")
                    return
                }
                callback([
                    "uri": url.absoluteString,
                    "width": Int(image.size.width),
                    "height": Int(image.size.height),
                ], nil)
            }
        }
    }

    /// Re-encode an image as JPEG into the temporary directory.
    static func writeTemporaryJPEG(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - PHPickerViewController delegate

private final class ImagePickerDelegate: NSObject, PHPickerViewControllerDelegate {
    private let callback: (Any?, String?) -> Void

    init(callback: @escaping (Any?, String?) -> Void) {
        self.callback = callback
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        ImagePickerModule.processPickerResults(results, callback: callback)
    }
}
#endif
