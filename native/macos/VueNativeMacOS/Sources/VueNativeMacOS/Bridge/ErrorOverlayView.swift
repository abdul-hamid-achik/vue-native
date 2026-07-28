import AppKit

/// A JS error split into the parts the overlay renders individually.
///
/// `stack` and `componentName` are optional: a plain prose message (e.g. the
/// "Hot reload failed" notice) has no stack, and the component name is a
/// best-effort extraction that is `nil` when no Vue render-trace frame is found.
struct ErrorOverlayContent {
    var message: String
    var stack: String?
    var componentName: String?
}

/// Full-window red error overlay shown in dev mode when a JS exception occurs.
/// macOS version using NSView instead of UIView.
///
/// The overlay renders a *structured* error rather than a single text blob:
/// the message in bold, the (optional) component name, a scrollable monospace
/// stack trace, and Reload / Dismiss actions. Layout is driven by an
/// `NSStackView` so it adapts to window resizing.
@MainActor
final class ErrorOverlayView: FlippedView {

    // MARK: - Reload hook

    /// Configurable handler invoked by the Reload button.
    ///
    /// The overlay does not own a bundle source, so the host wires this to
    /// whatever should re-run the JS load (e.g. re-evaluating the embedded
    /// bundle or asking `HotReloadManager` for a fresh bundle). When `nil`,
    /// Reload falls back to dismissing the overlay so a developer is never
    /// stuck behind an error they cannot clear.
    static var reloadHandler: (() -> Void)?

    // MARK: - Subviews (exposed read-only for tests)

    private(set) var titleLabel = NSTextField(labelWithString: "JavaScript Error")
    private(set) var componentLabel = NSTextField(labelWithString: "")
    private(set) var messageLabel = NSTextField(wrappingLabelWithString: "")
    private(set) var stackTextView = NSTextView()
    private(set) var scrollView = NSScrollView()
    private(set) var reloadButton = NSButton(title: "Reload", target: nil, action: nil)
    private(set) var dismissButton = NSButton(title: "Dismiss", target: nil, action: nil)

    private let containerStack = NSStackView()
    private let buttonStack = NSStackView()

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.95).cgColor

        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.drawsBackground = false

        componentLabel.textColor = NSColor(white: 1.0, alpha: 0.85)
        componentLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        componentLabel.isBordered = false
        componentLabel.isEditable = false
        componentLabel.drawsBackground = false
        componentLabel.isHidden = true

        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 15, weight: .bold)
        messageLabel.isEditable = false
        messageLabel.isBordered = false
        messageLabel.drawsBackground = false
        messageLabel.maximumNumberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping

        // Scrollable monospace stack trace.
        stackTextView.isEditable = false
        stackTextView.isSelectable = true
        stackTextView.drawsBackground = false
        stackTextView.backgroundColor = .clear
        stackTextView.textColor = .white
        stackTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        stackTextView.isVerticallyResizable = true
        stackTextView.isHorizontallyResizable = false
        stackTextView.autoresizingMask = [.width]
        stackTextView.textContainer?.widthTracksTextView = true
        stackTextView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = stackTextView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        // Let the stack view stretch the scroll view to fill leftover space.
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        scrollView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        reloadButton.target = self
        reloadButton.action = #selector(reloadTapped)
        reloadButton.bezelStyle = .rounded
        reloadButton.keyEquivalent = "r"

        dismissButton.target = self
        dismissButton.action = #selector(dismissOverlay)
        dismissButton.bezelStyle = .rounded
        dismissButton.keyEquivalent = "\u{1b}" // Escape

        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.addArrangedSubview(reloadButton)
        buttonStack.addArrangedSubview(dismissButton)

        containerStack.orientation = .vertical
        containerStack.alignment = .leading
        containerStack.distribution = .fill
        containerStack.spacing = 12
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerStack)

        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
        ])

        // Give the scrollable stack a sensible minimum so it never collapses.
        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
        ])
    }

    /// Stretch an arranged subview to the full width of the container stack.
    /// NSStackView's `.leading` alignment pins the leading edge; an explicit
    /// trailing constraint fills the remaining width so wrapping labels and the
    /// scroll view span the overlay.
    private func stretchToContainerWidth(_ view: NSView) {
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: containerStack.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: containerStack.trailingAnchor),
        ])
    }

    // MARK: - Content

    /// Populate the overlay from structured error parts and (re)build the stack
    /// so optional sections (component, stack trace) only occupy space when
    /// present.
    func configure(message: String, stack: String?, componentName: String?) {
        messageLabel.stringValue = message

        if let componentName, !componentName.isEmpty {
            componentLabel.stringValue = "Component: \(componentName)"
            componentLabel.isHidden = false
        } else {
            componentLabel.stringValue = ""
            componentLabel.isHidden = true
        }

        let hasStack = !(stack?.isEmpty ?? true)
        stackTextView.string = stack ?? ""

        // Rebuild the arranged subviews in display order, dropping optional
        // sections that are absent. removeArrangedSubview alone leaves the view
        // in the hierarchy, so it must also be removed from the superview.
        for arranged in containerStack.arrangedSubviews {
            containerStack.removeArrangedSubview(arranged)
            arranged.removeFromSuperview()
        }

        containerStack.addArrangedSubview(titleLabel)
        stretchToContainerWidth(titleLabel)

        if !componentLabel.isHidden {
            containerStack.addArrangedSubview(componentLabel)
            stretchToContainerWidth(componentLabel)
        }

        containerStack.addArrangedSubview(messageLabel)
        stretchToContainerWidth(messageLabel)

        if hasStack {
            containerStack.addArrangedSubview(scrollView)
            stretchToContainerWidth(scrollView)
        }

        containerStack.addArrangedSubview(buttonStack)
        stretchToContainerWidth(buttonStack)
    }

    /// Show the overlay in the given window, replacing any existing overlay.
    func show(message: String, stack: String?, componentName: String?, in window: NSWindow) {
        configure(message: message, stack: stack, componentName: componentName)
        guard let contentView = window.contentView else { return }

        frame = contentView.bounds
        autoresizingMask = [.width, .height]
        contentView.addSubview(self)
        needsLayout = true
    }

    // MARK: - Actions

    @objc private func reloadTapped() {
        if let handler = Self.reloadHandler {
            handler()
        } else {
            // No reload wired up -- clear the overlay so the dev isn't stuck.
            removeFromSuperview()
        }
    }

    @objc private func dismissOverlay() {
        removeFromSuperview()
    }

    // MARK: - Parsing

    /// Parse a raw error blob (as produced by the JS exception handler) into
    /// structured parts.
    ///
    /// The runtime builds errors as `"<message>\n\n<stack>"`. Prose notices
    /// (e.g. the hot-reload failure message) contain no stack frames, so the
    /// whole string is kept as the message and `stack` stays `nil`. The
    /// component name is a best-effort extraction from a Vue render-trace frame
    /// (`at <VButton ...>`) and is `nil` when none is found.
    static func parse(_ raw: String) -> ErrorOverlayContent {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let componentName = extractComponentName(from: trimmed)

        // Split on blank lines into paragraphs (dropping empty runs).
        let paragraphs = trimmed
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard paragraphs.count >= 2 else {
            return ErrorOverlayContent(message: trimmed, stack: nil, componentName: componentName)
        }

        let candidateStack = paragraphs.dropFirst().joined(separator: "\n\n")
        if looksLikeStack(candidateStack) {
            return ErrorOverlayContent(
                message: paragraphs[0],
                stack: candidateStack,
                componentName: componentName
            )
        }

        // Multiple prose paragraphs (no stack frames) -- keep the full text as
        // the message so nothing is dropped.
        return ErrorOverlayContent(message: trimmed, stack: nil, componentName: componentName)
    }

    /// Heuristic: does this text look like a JS stack trace? True when at least
    /// one line resembles a stack frame (`at foo (...)` or JSCore's
    /// `foo@file:line:col`).
    private static func looksLikeStack(_ text: String) -> Bool {
        let lines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }
        return lines.contains { line in
            line.hasPrefix("at ") || (line.contains("@") && line.contains(":"))
        }
    }

    /// Best-effort component name extraction. Prefers a Vue render-trace frame
    /// (`at <VButton ...>`); falls back to the first capitalized
    /// angle-bracketed token. Returns `nil` when nothing plausible is found.
    private static func extractComponentName(from raw: String) -> String? {
        let denyList: Set<String> = ["Anonymous", "Unknown", "Eval", "Function", "Object", "Error"]
        // Capture the component name after `<`, whether followed by `>` or by
        // attributes (e.g. `<VButton onClick=fn>` -> "VButton").
        let pattern = "<([A-Z][A-Za-z0-9]*)[\\s>]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        // Prefer a component named inside a stack frame line.
        for line in raw.components(separatedBy: "\n") {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard trimmedLine.hasPrefix("at ") else { continue }
            let lineRange = NSRange(trimmedLine.startIndex..., in: trimmedLine)
            if let match = regex.firstMatch(in: trimmedLine, range: lineRange),
               let nameRange = Range(match.range(at: 1), in: trimmedLine) {
                let name = String(trimmedLine[nameRange])
                if !denyList.contains(name) { return name }
            }
        }

        // Fall back to the first capitalized angle-bracketed token anywhere.
        let fullRange = NSRange(raw.startIndex..., in: raw)
        if let match = regex.firstMatch(in: raw, range: fullRange),
           let nameRange = Range(match.range(at: 1), in: raw) {
            let name = String(raw[nameRange])
            if !denyList.contains(name) { return name }
        }

        return nil
    }

    // MARK: - Static presentation

    /// Present a structured error overlay on the main window.
    static func show(message: String, stack: String?, componentName: String?) {
        present(content: ErrorOverlayContent(message: message, stack: stack, componentName: componentName))
    }

    /// Present an overlay from a raw error blob (backward-compatible entry point
    /// used by the JS exception handler and hot-reload failures).
    nonisolated static func show(error: String) {
        Task { @MainActor in
            present(content: ErrorOverlayView.parse(error))
        }
    }

    private static func present(content: ErrorOverlayContent) {
        guard let window = NSApp.mainWindow ?? NSApp.windows.first else { return }

        // Remove any existing overlay.
        window.contentView?.subviews
            .compactMap { $0 as? ErrorOverlayView }
            .forEach { $0.removeFromSuperview() }

        let overlay = ErrorOverlayView(frame: window.contentView?.bounds ?? .zero)
        overlay.show(
            message: content.message,
            stack: content.stack,
            componentName: content.componentName,
            in: window
        )
    }
}
