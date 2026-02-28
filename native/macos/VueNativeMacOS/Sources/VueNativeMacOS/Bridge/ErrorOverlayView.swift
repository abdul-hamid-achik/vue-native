import AppKit

/// Full-window red error overlay shown in dev mode when a JS exception occurs.
/// macOS version using NSView instead of UIView.
@MainActor
final class ErrorOverlayView: FlippedView {

    private let titleLabel = NSTextField(labelWithString: "JavaScript Error")
    private let messageLabel = NSTextField(wrappingLabelWithString: "")
    private let dismissButton = NSButton(title: "Dismiss", target: nil, action: nil)
    private let scrollView = NSScrollView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        layer?.backgroundColor = NSColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.95).cgColor

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false

        messageLabel.textColor = .white
        messageLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        messageLabel.isEditable = false
        messageLabel.isBordered = false
        messageLabel.drawsBackground = false
        messageLabel.maximumNumberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping

        dismissButton.target = self
        dismissButton.action = #selector(dismissOverlay)
        dismissButton.bezelStyle = .rounded

        scrollView.documentView = messageLabel
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        addSubview(titleLabel)
        addSubview(scrollView)
        addSubview(dismissButton)
    }

    override func layout() {
        super.layout()

        let padding: CGFloat = 20
        let topPadding: CGFloat = 20

        titleLabel.frame = CGRect(x: padding, y: topPadding, width: bounds.width - padding * 2, height: 30)

        let buttonHeight: CGFloat = 30
        dismissButton.frame = CGRect(
            x: padding,
            y: bounds.height - buttonHeight - padding,
            width: bounds.width - padding * 2,
            height: buttonHeight
        )

        scrollView.frame = CGRect(
            x: padding,
            y: topPadding + 40,
            width: bounds.width - padding * 2,
            height: dismissButton.frame.minY - topPadding - 50
        )

        // Size the message label to fill scroll view width
        messageLabel.frame = CGRect(
            x: 0, y: 0,
            width: scrollView.contentSize.width,
            height: 0
        )
        messageLabel.sizeToFit()
    }

    func show(error: String, in window: NSWindow) {
        messageLabel.stringValue = error
        guard let contentView = window.contentView else { return }

        frame = contentView.bounds
        autoresizingMask = [.width, .height]
        contentView.addSubview(self)
        needsLayout = true
    }

    @objc private func dismissOverlay() {
        removeFromSuperview()
    }

    static func show(error: String) {
        DispatchQueue.main.async {
            guard let window = NSApp.mainWindow ?? NSApp.windows.first else { return }

            // Remove any existing overlay
            window.contentView?.subviews
                .compactMap { $0 as? ErrorOverlayView }
                .forEach { $0.removeFromSuperview() }

            let overlay = ErrorOverlayView(frame: window.contentView?.bounds ?? .zero)
            overlay.show(error: error, in: window)
        }
    }
}
