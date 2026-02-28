import AVFoundation
import AppKit
import VueNativeShared

/// Native module providing camera access on macOS.
///
/// Methods:
///   - checkPermission() -> "granted"/"denied"/"undetermined"
///   - requestPermission() -> Bool
///   - takePicture() -> { uri, width, height }
///   - getAvailableCameras() -> [{ id, name, position }]
final class CameraModule: NativeModule {
    let moduleName = "Camera"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "checkPermission":
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            let result: String
            switch status {
            case .authorized:
                result = "granted"
            case .denied, .restricted:
                result = "denied"
            case .notDetermined:
                result = "undetermined"
            @unknown default:
                result = "undetermined"
            }
            callback(result, nil)

        case "requestPermission":
            AVCaptureDevice.requestAccess(for: .video) { granted in
                callback(granted, nil)
            }

        case "takePicture":
            takePicture(callback: callback)

        case "getAvailableCameras":
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
                mediaType: .video,
                position: .unspecified
            )
            let cameras: [[String: Any]] = discoverySession.devices.map { device in
                let position: String
                switch device.position {
                case .front: position = "front"
                case .back: position = "back"
                default: position = "unspecified"
                }
                return [
                    "id": device.uniqueID,
                    "name": device.localizedName,
                    "position": position
                ]
            }
            callback(cameras, nil)

        default:
            callback(nil, "CameraModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Photo capture

    private func takePicture(callback: @escaping (Any?, String?) -> Void) {
        guard let device = AVCaptureDevice.default(for: .video) else {
            callback(nil, "No camera available")
            return
        }

        let session = AVCaptureSession()
        session.sessionPreset = .photo

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                callback(nil, "Cannot add camera input")
                return
            }
            session.addInput(input)
        } catch {
            callback(nil, "Camera input error: \(error.localizedDescription)")
            return
        }

        let photoOutput = AVCapturePhotoOutput()
        guard session.canAddOutput(photoOutput) else {
            callback(nil, "Cannot add photo output")
            return
        }
        session.addOutput(photoOutput)

        let delegate = PhotoCaptureDelegate(session: session, callback: callback)
        // Prevent delegate from being deallocated before capture completes
        PhotoCaptureDelegate.activeDelegates.insert(delegate)

        session.startRunning()

        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }
}

// MARK: - PhotoCaptureDelegate

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {

    /// Strong references to active delegates to prevent premature deallocation.
    static var activeDelegates = Set<PhotoCaptureDelegate>()

    private let session: AVCaptureSession
    private let callback: (Any?, String?) -> Void

    init(session: AVCaptureSession, callback: @escaping (Any?, String?) -> Void) {
        self.session = session
        self.callback = callback
        super.init()
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer {
            session.stopRunning()
            PhotoCaptureDelegate.activeDelegates.remove(self)
        }

        if let error = error {
            callback(nil, "Photo capture error: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            callback(nil, "Failed to get photo data")
            return
        }

        guard let image = NSImage(data: imageData) else {
            callback(nil, "Failed to create image from data")
            return
        }

        // Write to temp file
        let tempDir = NSTemporaryDirectory()
        let fileName = "vue_native_photo_\(UUID().uuidString).jpg"
        let filePath = (tempDir as NSString).appendingPathComponent(fileName)

        do {
            try imageData.write(to: URL(fileURLWithPath: filePath))
        } catch {
            callback(nil, "Failed to save photo: \(error.localizedDescription)")
            return
        }

        let result: [String: Any] = [
            "uri": filePath,
            "width": image.size.width,
            "height": image.size.height
        ]
        callback(result, nil)
    }
}
