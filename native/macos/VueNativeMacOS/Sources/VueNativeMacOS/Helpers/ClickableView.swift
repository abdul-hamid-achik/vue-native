import AppKit

/// Custom NSView subclass that provides button-like behavior with mouse events.
/// macOS equivalent of iOS TouchableView.
/// Supports press and long press events with configurable active opacity.
class ClickableView: FlippedView {

    // MARK: - Public properties

    /// The opacity to apply when the user is pressing the view.
    var activeOpacity: CGFloat = 0.7

    /// Called when a click completes within the view bounds.
    var onPress: (() -> Void)? {
        didSet { invalidatePointingHandCursorRect() }
    }

    /// Called when a long press gesture is recognized.
    var onLongPress: (() -> Void)? {
        didSet { invalidatePointingHandCursorRect() }
    }

    /// Whether mouse interactions are disabled.
    var isDisabled: Bool = false {
        didSet {
            alphaValue = isDisabled ? 0.4 : 1.0
            invalidatePointingHandCursorRect()
        }
    }

    /// Cursor rects are owned by the window, so refresh through it.
    private func invalidatePointingHandCursorRect() {
        window?.invalidateCursorRects(for: self)
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

    // MARK: - Keyboard / focus

    /// Buttons and pressables must be reachable with the keyboard: without this
    /// Tab navigation skips them entirely and VoiceOver's "press" action has no
    /// responder to activate.
    override var acceptsFirstResponder: Bool { true }

    /// Space activates a focused button, matching NSButton and the web's
    /// `<button>` behaviour.
    override func keyDown(with event: NSEvent) {
        if !isDisabled, event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
           Self.isActivationKey(event) {
            pressFromKeyboard()
            return
        }
        super.keyDown(with: event)
    }

    /// Return is normally routed through `performKeyEquivalent` (that is how the
    /// window's default button works), so `keyDown` alone never sees it. Only
    /// claim it when this view is actually the first responder — otherwise a
    /// focused `VInput` would lose its Return/submit key.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard !isDisabled, window?.firstResponder === self else {
            return super.performKeyEquivalent(with: event)
        }
        if event.type == .keyDown, Self.isActivationKey(event) {
            pressFromKeyboard()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Space (virtual key 49) or Return/Enter (36 / numeric keypad 76).
    private static func isActivationKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 49, 36, 76: return true
        default: return false
        }
    }

    private func pressFromKeyboard() {
        // Mirror the mouse path's press feedback so keyboard activation is
        // visually distinguishable too.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            self.animator().alphaValue = activeOpacity
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, !self.isDisabled else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.1
                self.animator().alphaValue = 1.0
            }
        }
        onPress?()
    }

    // MARK: - Cursor

    /// A pointing hand over anything pressable is the platform convention; AppKit
    /// only does this for `NSButton`, so custom pressable views must opt in.
    override func resetCursorRects() {
        super.resetCursorRects()
        guard !isDisabled, onPress != nil || onLongPress != nil else { return }
        addCursorRect(bounds, cursor: .pointingHand)
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
