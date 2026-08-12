#if canImport(UIKit)
import UIKit

/// Small, non-interactive pill shown in the bottom-right corner (debug builds
/// only, and only when a dev server is configured) that surfaces hot-reload
/// connection state, which otherwise only ever reached `NSLog`. Driven by
/// `HotReloadManager.onStatusChange`. See `ErrorOverlayView` for the sibling
/// dev-only overlay.
@MainActor
final class HotReloadStatusView: UIView {

    // MARK: - Pure state -> appearance mapping (unit-testable)

    /// Semantic color for the badge, kept independent of `UIColor` so the
    /// state -> appearance mapping below is a plain, testable value type.
    enum Tone: Equatable {
        case connecting
        case disconnected
        case connected
    }

    struct Content: Equatable {
        let text: String
        let tone: Tone
    }

    /// Reconnect attempts at or below this count still read as "connecting"
    /// (orange). Beyond it the badge switches to "disconnected" (red) even
    /// though `HotReloadManager` keeps retrying in the background.
    static let connectingAttemptThreshold = 3

    /// Delay before a "Connected" badge auto-hides itself.
    static let autoHideDelay: TimeInterval = 2.0

    /// Maps a `HotReloadStatus` to the badge's text and tone. Extracted as a
    /// pure static function -- like `VueNativeViewController
    /// .shouldShowMissingBundleOverlay` -- so it is unit-testable without
    /// instantiating a view.
    static func content(for status: HotReloadStatus) -> Content {
        switch status {
        case .connecting(let attempt):
            if attempt <= connectingAttemptThreshold {
                return Content(text: "Connecting…", tone: .connecting)
            }
            return Content(text: "Disconnected — check `vue-native dev`", tone: .disconnected)
        case .connected:
            return Content(text: "Connected", tone: .connected)
        }
    }

    /// Whether the badge should schedule an auto-hide after this status --
    /// only once connected. The connecting/disconnected states stay visible
    /// so an in-progress or stalled reconnect is never silently hidden.
    static func shouldAutoHide(for status: HotReloadStatus) -> Bool {
        status == .connected
    }

    // MARK: - Subviews (internal for testing)

    let label = UILabel()
    private var hideWorkItem: DispatchWorkItem?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        // Purely informational -- must never intercept touches meant for the
        // Vue-rendered content underneath.
        isUserInteractionEnabled = false
        isHidden = true
        layer.cornerRadius = 10
        clipsToBounds = true

        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])
    }

    // MARK: - Apply status

    /// Update the badge for a new status. Cancels any pending auto-hide from
    /// a previous "Connected" so the badge always reappears on a fresh
    /// connect/reconnect, even if it fires while a previous hide is pending.
    func apply(_ status: HotReloadStatus) {
        hideWorkItem?.cancel()
        hideWorkItem = nil

        let content = Self.content(for: status)
        label.text = content.text
        backgroundColor = Self.backgroundColor(for: content.tone)
        isHidden = false

        if Self.shouldAutoHide(for: status) {
            let workItem = DispatchWorkItem { [weak self] in self?.isHidden = true }
            hideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoHideDelay, execute: workItem)
        }
    }

    private static func backgroundColor(for tone: Tone) -> UIColor {
        switch tone {
        case .connecting: return UIColor.systemOrange.withAlphaComponent(0.92)
        case .disconnected: return UIColor.systemRed.withAlphaComponent(0.92)
        case .connected: return UIColor.systemGreen.withAlphaComponent(0.92)
        }
    }
}
#endif
