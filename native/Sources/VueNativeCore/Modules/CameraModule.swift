#if canImport(UIKit)
import UIKit
import PhotosUI

/// Native module for camera capture and photo library access.
///
/// Methods:
///   - launchCamera(options: Object?)  -- opens UIImagePickerController for camera capture
///   - launchImageLibrary(options: Object?) -- opens PHPickerViewController (no permission dialog)
///
/// Both methods call back with:
///   { uri: String, width: Number, height: Number, type: "image/jpeg" } on success
///   { didCancel: true }  when user cancels
///   (nil, errorMessage) on error
final class CameraModule: NativeModule {
    var moduleName: String { "Camera" }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        let options = args.first as? [String: Any] ?? [:]
        switch method {
        case "launchCamera":
            DispatchQueue.main.async { self.launchCamera(options: options, callback: callback) }
        case "launchImageLibrary":
            DispatchQueue.main.async { self.launchImageLibrary(options: options, callback: callback) }
        default:
            callback(nil, "CameraModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Private launch helpers

    private func launchCamera(options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            callback(nil, "Camera not available on this device"); return
        }
        guard let rootVC = topViewController() else {
            callback(nil, "No root view controller found"); return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image"]
        let delegate = ImagePickerDelegate(callback: callback)
        picker.delegate = delegate
        // Retain delegate for the picker's lifetime via association
        objc_setAssociatedObject(picker, &CameraModule.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        rootVC.present(picker, animated: true)
    }

    private func launchImageLibrary(options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        guard let rootVC = topViewController() else {
            callback(nil, "No root view controller found"); return
        }
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = (options["selectionLimit"] as? Int) ?? 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        let delegate = PHPickerDelegate(callback: callback)
        picker.delegate = delegate
        objc_setAssociatedObject(picker, &CameraModule.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        rootVC.present(picker, animated: true)
    }

    /// Walks the view controller hierarchy to find the topmost presented controller.
    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }

    private static var delegateKey: UInt8 = 0

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}

// MARK: - UIImagePickerController delegate

private final class ImagePickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let callback: (Any?, String?) -> Void
    init(callback: @escaping (Any?, String?) -> Void) { self.callback = callback }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else {
            callback(nil, "No image in picker result"); return
        }
        let uri = saveImageToTemp(image)?.absoluteString ?? ""
        callback(["uri": uri, "width": image.size.width, "height": image.size.height, "type": "image/jpeg"], nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        callback(["didCancel": true], nil)
    }

    private func saveImageToTemp(_ image: UIImage) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        try? data.write(to: url)
        return url
    }
}

// MARK: - PHPickerViewController delegate

private final class PHPickerDelegate: NSObject, PHPickerViewControllerDelegate {
    private let callback: (Any?, String?) -> Void
    init(callback: @escaping (Any?, String?) -> Void) { self.callback = callback }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else {
            callback(["didCancel": true], nil); return
        }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let self = self else { return }
            if let image = object as? UIImage {
                DispatchQueue.main.async {
                    let uri = self.saveImageToTemp(image)?.absoluteString ?? ""
                    self.callback(["uri": uri, "width": image.size.width, "height": image.size.height, "type": "image/jpeg"], nil)
                }
            } else {
                self.callback(nil, error?.localizedDescription ?? "Failed to load image")
            }
        }
    }

    private func saveImageToTemp(_ image: UIImage) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        try? data.write(to: url)
        return url
    }
}
#endif
