#if canImport(UIKit)
import UIKit
import PhotosUI
import AVFoundation
import MobileCoreServices

/// Native module for camera capture, photo library access, video capture, and QR code scanning.
///
/// Methods:
///   - launchCamera(options)         -- photo capture via UIImagePickerController
///   - launchImageLibrary(options)   -- photo picker via PHPickerViewController
///   - captureVideo(options)         -- video capture via UIImagePickerController
///   - scanQRCode()                  -- start QR code scanning via AVCaptureSession
///   - stopQRScan()                  -- stop QR code scanning
final class CameraModule: NativeModule {
    var moduleName: String { "Camera" }

    private var qrSession: AVCaptureSession?
    private var qrDelegate: QRScanDelegate?
    private var qrPreviewLayer: AVCaptureVideoPreviewLayer?
    private weak var bridge: NativeBridge?
    private let qrQueue = DispatchQueue(label: "com.vuenative.camera.qr")

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        let options = args.first as? [String: Any] ?? [:]
        switch method {
        case "launchCamera":
            DispatchQueue.main.async { self.launchCamera(options: options, callback: callback) }
        case "launchImageLibrary":
            DispatchQueue.main.async { self.launchImageLibrary(options: options, callback: callback) }
        case "captureVideo":
            DispatchQueue.main.async { self.captureVideo(options: options, callback: callback) }
        case "scanQRCode":
            DispatchQueue.main.async { self.scanQRCode(callback: callback) }
        case "stopQRScan":
            stopQRScan()
            callback(nil, nil)
        default:
            callback(nil, "CameraModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Photo capture

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
        objc_setAssociatedObject(picker, &CameraModule.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        rootVC.present(picker, animated: true)
    }

    // MARK: - Image library

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

    // MARK: - Video capture

    private func captureVideo(options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            callback(nil, "Camera not available on this device"); return
        }
        guard let rootVC = topViewController() else {
            callback(nil, "No root view controller found"); return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.cameraCaptureMode = .video

        // Quality
        let quality = options["quality"] as? String ?? "medium"
        switch quality {
        case "low": picker.videoQuality = .typeLow
        case "high": picker.videoQuality = .typeHigh
        default: picker.videoQuality = .typeMedium
        }

        // Max duration
        if let maxDuration = options["maxDuration"] as? Double {
            picker.videoMaximumDuration = maxDuration
        }

        // Front camera
        if let frontCamera = options["frontCamera"] as? Bool, frontCamera {
            picker.cameraDevice = .front
        }

        let delegate = VideoPickerDelegate(callback: callback)
        picker.delegate = delegate
        objc_setAssociatedObject(picker, &CameraModule.delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        rootVC.present(picker, animated: true)
    }

    // MARK: - QR Code scanning

    private func scanQRCode(callback: @escaping (Any?, String?) -> Void) {
        // Stop any existing session
        stopQRScan()

        guard let device = AVCaptureDevice.default(for: .video) else {
            callback(nil, "No camera device available"); return
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            callback(nil, "Cannot create camera input"); return
        }

        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard session.canAddInput(input) else {
            callback(nil, "Cannot add camera input to session"); return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            callback(nil, "Cannot add metadata output to session"); return
        }
        session.addOutput(output)

        let bridge = NativeBridge.shared
        let delegate = QRScanDelegate(bridge: bridge)
        output.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417, .code128]

        qrQueue.sync {
            self.qrSession = session
            self.qrDelegate = delegate
            self.bridge = bridge
        }

        // Start on background queue to avoid blocking main thread
        qrQueue.async {
            session.startRunning()
        }

        callback(nil, nil)
    }

    private func stopQRScan() {
        let sessionToStop: AVCaptureSession? = qrQueue.sync {
            let session = self.qrSession
            self.qrSession = nil
            self.qrDelegate = nil
            self.qrPreviewLayer = nil
            return session
        }
        if let session = sessionToStop, session.isRunning {
            qrQueue.async {
                session.stopRunning()
            }
        }
    }

    // MARK: - Helpers

    private func topViewController() -> UIViewController? {
        return UIApplication.shared.vn_topViewController
    }

    private static var delegateKey: UInt8 = 0

    func invokeSync(method: String, args: [Any]) -> Any? { nil }
}

// MARK: - UIImagePickerController delegate (photos)

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

// MARK: - UIImagePickerController delegate (video)

private final class VideoPickerDelegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let callback: (Any?, String?) -> Void
    init(callback: @escaping (Any?, String?) -> Void) { self.callback = callback }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let videoURL = info[.mediaURL] as? URL else {
            callback(nil, "No video URL in picker result"); return
        }

        // Copy to temp directory for consistent access
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        do {
            try FileManager.default.copyItem(at: videoURL, to: tempURL)
        } catch {
            callback(nil, "Failed to copy video: \(error.localizedDescription)"); return
        }

        // Get video duration
        let asset = AVAsset(url: tempURL)
        let duration = CMTimeGetSeconds(asset.duration)

        callback(["uri": tempURL.absoluteString, "duration": duration, "type": "video/quicktime"], nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        callback(["didCancel": true], nil)
    }
}

// MARK: - QR Code scan delegate

private final class QRScanDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private weak var bridge: NativeBridge?

    init(bridge: NativeBridge) {
        self.bridge = bridge
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let data = readable.stringValue else { return }

        let bounds = readable.bounds
        let type = readable.type.rawValue
        DispatchQueue.main.async { [weak self] in
            self?.bridge?.dispatchGlobalEvent("camera:qrDetected", payload: [
                "data": data,
                "type": type,
                "bounds": [
                    "x": bounds.origin.x,
                    "y": bounds.origin.y,
                    "width": bounds.size.width,
                    "height": bounds.size.height,
                ],
            ])
        }
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
