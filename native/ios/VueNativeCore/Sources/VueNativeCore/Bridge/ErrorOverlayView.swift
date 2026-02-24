#if canImport(UIKit)
import UIKit

/// Full-screen red error overlay shown in dev mode when a JS exception occurs.
@MainActor
final class ErrorOverlayView: UIView {

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let dismissButton = UIButton(type: .system)
    private let scrollView = UIScrollView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.95)

        titleLabel.text = "JavaScript Error"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center

        messageLabel.textColor = .white
        messageLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left

        dismissButton.setTitle("Dismiss", for: .normal)
        dismissButton.setTitleColor(.white, for: .normal)
        dismissButton.backgroundColor = UIColor(white: 1, alpha: 0.2)
        dismissButton.layer.cornerRadius = 8
        dismissButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)

        scrollView.addSubview(messageLabel)
        addSubview(titleLabel)
        addSubview(scrollView)
        addSubview(dismissButton)
    }

    func show(error: String, in window: UIWindow) {
        messageLabel.text = error
        frame = window.bounds

        let padding: CGFloat = 20
        let topPadding = window.safeAreaInsets.top + 20

        titleLabel.frame = CGRect(x: padding, y: topPadding, width: bounds.width - padding * 2, height: 30)
        dismissButton.frame = CGRect(
            x: padding,
            y: bounds.height - 60 - window.safeAreaInsets.bottom,
            width: bounds.width - padding * 2,
            height: 44
        )
        scrollView.frame = CGRect(
            x: padding,
            y: topPadding + 40,
            width: bounds.width - padding * 2,
            height: dismissButton.frame.minY - topPadding - 50
        )
        messageLabel.frame = CGRect(x: 0, y: 0, width: scrollView.bounds.width, height: 0)
        messageLabel.sizeToFit()
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: messageLabel.bounds.height)

        window.addSubview(self)
    }

    @objc private func dismiss() {
        removeFromSuperview()
    }

    static func show(error: String) {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.vn_keyWindow else { return }

            // Remove any existing overlay
            window.subviews.compactMap { $0 as? ErrorOverlayView }.forEach { $0.removeFromSuperview() }

            let overlay = ErrorOverlayView(frame: window.bounds)
            overlay.show(error: error, in: window)
        }
    }
}
#endif
