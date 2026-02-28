import AppKit

/// Custom NSView subclass that provides button-like behavior with mouse events.
/// macOS equivalent of iOS TouchableView.
/// Supports press and long press events with configurable active opacity.
class ClickableView: FlippedView {

    // MARK: - Public properties

    /// The opacity to apply when the user is pressing the view.
    var activeOpacity: CGFloat = 0.7

    /// Called when a click completes within the view bounds.
    var onPress: (() -> Void)?

    /// Called when a long press gesture is recognized.
    var onLongPress: (() -> Void)?

    /// Whether mouse interactions are disabled.
    var isDisabled: Bool = false {
        didSet {
            alphaValue = isDisabled ? 0.4 : 1.0
        }
    }

    // MARK: - Private properties

    private var isPressed = false
    private var longPressTimer: Timer?

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        guard !isDisabled else { return }
        isPressed = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            self.animator().alphaValue = activeOpacity
        }

        // Start long press timer
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.onLongPress?()
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard !isDisabled, isPressed else { return }
        isPressed = false

        longPressTimer?.invalidate()
        longPressTimer = nil

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            self.animator().alphaValue = 1.0
        }

        // Check if mouse is still inside bounds
        let location = convert(event.locationInWindow, from: nil)
        if bounds.contains(location) {
            onPress?()
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard isPressed else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            self.animator().alphaValue = 1.0
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard isPressed else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            self.animator().alphaValue = activeOpacity
        }
    }

    // MARK: - Tracking areas

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Remove old tracking areas
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        // Add new tracking area for mouse enter/exit events
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }
}
