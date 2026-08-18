#if canImport(UIKit)
import UIKit
import AVFoundation

/// Full-screen QR/barcode preview presented by `CameraModule.scanQRCode`.
/// Close dismisses the controller; the module stops the capture session.
final class QRScannerViewController: UIViewController {
    var onClose: (() -> Void)?

    private let session: AVCaptureSession
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let closeButton = UIButton(type: .system)

    init(session: AVCaptureSession) {
        self.session = session
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        closeButton.layer.cornerRadius = 8
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }

    @objc private func closeTapped() {
        onClose?()
    }
}
#endif
