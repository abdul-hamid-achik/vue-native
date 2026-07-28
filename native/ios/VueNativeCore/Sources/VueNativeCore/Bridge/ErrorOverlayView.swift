#if canImport(UIKit)
import UIKit

/// Structured representation of a JavaScript error forwarded from the runtime.
///
/// The Vue app's global `errorHandler` serializes `{ message, stack,
/// componentName, info }` to JSON and forwards it through `__VN_handleError`.
/// Uncaught exceptions surfaced via the JSContext exception handler only carry a
/// message and (optionally) a stack, so `componentName` is optional.
struct JSErrorInfo: Equatable {
    let message: String
    let stack: String
    let componentName: String?

    /// Parse the raw JSON payload that `__VN_handleError` receives. Falls back to
    /// treating the whole payload as a plain message when it is not valid JSON
    /// (e.g. the legacy string-only path).
    static func from(payload: String) -> JSErrorInfo {
        if let data = payload.data(using: .utf8),
           let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let message = info["message"] as? String ?? "Unknown error"
            let stack = info["stack"] as? String ?? ""
            let componentName = info["componentName"] as? String
            return JSErrorInfo(message: message, stack: stack, componentName: componentName)
        }
        return JSErrorInfo(message: payload, stack: "", componentName: nil)
    }
}

/// Full-screen red error overlay shown in dev mode when a JS exception occurs.
///
/// Renders a structured breakdown of the error — a bold message, the originating
/// component name (when known), and a scrollable monospace stack trace — plus a
/// configurable **Reload** button that re-triggers bundle loading.
@MainActor
final class ErrorOverlayView: UIView {

    // MARK: - Reload hook

    /// Invoked when the user taps the Reload button. The host (typically the
    /// `VueNativeViewController`) installs a handler that re-loads the bundle in
    /// a fresh JS context. When `nil`, the Reload button simply dismisses the
    /// overlay.
    static var reloadHandler: (() -> Void)?

    // MARK: - Subviews (internal for testing)

    let titleLabel = UILabel()
    let messageLabel = UILabel()
    let componentLabel = UILabel()
    let stackTextView = UITextView()
    let reloadButton = UIButton(type: .system)
    let dismissButton = UIButton(type: .system)

    private let contentStack = UIStackView()
    private let buttonStack = UIStackView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    private func setupUI() {
        backgroundColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.95)

        titleLabel.text = "JavaScript Error"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center

        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 16, weight: .bold)
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .left

        componentLabel.textColor = UIColor(white: 1, alpha: 0.85)
        componentLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        componentLabel.numberOfLines = 0
        componentLabel.textAlignment = .left

        stackTextView.textColor = UIColor(white: 1, alpha: 0.9)
        stackTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        stackTextView.backgroundColor = UIColor(white: 0, alpha: 0.25)
        stackTextView.isEditable = false
        stackTextView.isScrollEnabled = true
        stackTextView.layer.cornerRadius = 8
        stackTextView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)

        reloadButton.setTitle("Reload", for: .normal)
        reloadButton.setTitleColor(.white, for: .normal)
        reloadButton.backgroundColor = UIColor(white: 1, alpha: 0.25)
        reloadButton.layer.cornerRadius = 8
        reloadButton.addTarget(self, action: #selector(handleReload), for: .touchUpInside)

        dismissButton.setTitle("Dismiss", for: .normal)
        dismissButton.setTitleColor(.white, for: .normal)
        dismissButton.backgroundColor = UIColor(white: 1, alpha: 0.2)
        dismissButton.layer.cornerRadius = 8
        dismissButton.addTarget(self, action: #selector(dismiss), for: .touchUpInside)

        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.addArrangedSubview(reloadButton)
        buttonStack.addArrangedSubview(dismissButton)

        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(messageLabel)
        contentStack.addArrangedSubview(componentLabel)
        contentStack.addArrangedSubview(stackTextView)
        contentStack.addArrangedSubview(buttonStack)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),

            buttonStack.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    // MARK: - Content

    /// Populate the overlay with a structured error. Exposed internally so tests
    /// can configure and inspect the view without attaching it to a window.
    func configure(with error: JSErrorInfo) {
        messageLabel.text = error.message

        if let componentName = error.componentName, !componentName.isEmpty {
            componentLabel.text = "Component: \(componentName)"
            componentLabel.isHidden = false
        } else {
            componentLabel.text = nil
            componentLabel.isHidden = true
        }

        stackTextView.text = error.stack
        stackTextView.isHidden = error.stack.isEmpty
    }

    func show(error: JSErrorInfo, in window: UIWindow) {
        configure(with: error)
        frame = window.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(self)
    }

    // MARK: - Actions

    @objc private func handleReload() {
        removeFromSuperview()
        ErrorOverlayView.reloadHandler?()
    }

    @objc private func dismiss() {
        removeFromSuperview()
    }

    // MARK: - Static entry points

    static func show(error: JSErrorInfo) {
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.vn_keyWindow else { return }

            // Remove any existing overlay
            window.subviews.compactMap { $0 as? ErrorOverlayView }.forEach { $0.removeFromSuperview() }

            let overlay = ErrorOverlayView(frame: window.bounds)
            overlay.show(error: error, in: window)
        }
    }

    /// Convenience for the legacy string-only path (uncaught exceptions, reload
    /// failures). The whole string becomes the message; there is no stack.
    static func show(error: String) {
        show(error: JSErrorInfo(message: error, stack: "", componentName: nil))
    }
}
#endif
