#if canImport(UIKit)
import UIKit

/// Custom UIView subclass that provides button-like touch behavior
/// with configurable active opacity and support for press and long press events.
///
/// Opacity model: `alpha` is the *visible* value and is always derived from
/// ``baseAlpha`` (the style-driven opacity, e.g. `<VButton style="opacity: 0.5">`)
/// multiplied by the current interaction factor. The press and disabled states
/// therefore dim *relative to* the styled opacity instead of replacing it, and
/// releasing a press restores the styled value rather than snapping to `1.0`.
class TouchableView: UIView {

    // MARK: - Public properties

    /// The opacity factor applied while the user is pressing the view, relative to
    /// ``baseAlpha``. `0.7` on a view styled at `opacity: 0.5` presses to `0.35`.
    var activeOpacity: CGFloat = 0.7 {
        didSet {
            guard activeOpacity != oldValue else { return }
            // Re-derive immediately so a change arriving mid-press is visible.
            if isPressing { applyEffectiveAlpha(duration: 0) }
        }
    }

    /// The opacity factor applied while ``isDisabled``, relative to ``baseAlpha``.
    var disabledOpacity: CGFloat = 0.4 {
        didSet {
            guard disabledOpacity != oldValue else { return }
            if isDisabled { applyEffectiveAlpha(duration: 0) }
        }
    }

    /// The style-driven opacity this view returns to when it is neither pressed nor
    /// disabled. Written implicitly: `StyleEngine` applies the CSS `opacity` prop by
    /// assigning `view.alpha`, and the ``alpha`` override below records that value
    /// here instead of treating it as an interaction state.
    private(set) var baseAlpha: CGFloat = 1.0

    /// Called when a tap completes within the view bounds.
    var onPress: (() -> Void)?

    /// Called when a long press gesture is recognized.
    var onLongPress: (() -> Void)?

    /// Whether touch interactions are disabled.
    var isDisabled: Bool = false {
        didSet {
            guard isDisabled != oldValue else { return }
            isUserInteractionEnabled = !isDisabled
            applyEffectiveAlpha(duration: 0.15)
        }
    }

    // MARK: - Private properties

    private var longPressRecognizer: UILongPressGestureRecognizer?
    private var isTouchInside: Bool = false
    /// A touch sequence is in flight. Distinct from ``isTouchInside``: the touch may
    /// have dragged outside the bounds, which removes the press dim without ending
    /// the sequence.
    private var isPressing: Bool = false
    /// Guards the ``alpha`` override so this type's own writes go straight to
    /// `super` and are not mistaken for a style-driven base-opacity change.
    private var isWritingEffectiveAlpha: Bool = false

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLongPressRecognizer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLongPressRecognizer()
    }

    // MARK: - Alpha

    /// Intercept external writes so the style-driven base opacity survives.
    ///
    /// Without this, `StyleEngine` setting `alpha = 0.5` was overwritten by the
    /// first `touchesEnded` (which hard-coded `1.0`), and toggling `disabled` off
    /// did the same — a semi-transparent button became fully opaque after one tap.
    override var alpha: CGFloat {
        get { super.alpha }
        set {
            guard !isWritingEffectiveAlpha else {
                super.alpha = newValue
                return
            }
            baseAlpha = newValue
            applyEffectiveAlpha(duration: 0)
        }
    }

    /// The alpha that should currently be visible.
    private var effectiveAlpha: CGFloat {
        if isDisabled { return baseAlpha * disabledOpacity }
        if isPressing && isTouchInside { return baseAlpha * activeOpacity }
        return baseAlpha
    }

    /// Animate (or set immediately when `duration` is 0) to ``effectiveAlpha``.
    private func applyEffectiveAlpha(duration: TimeInterval) {
        let target = effectiveAlpha
        isWritingEffectiveAlpha = true
        defer { isWritingEffectiveAlpha = false }

        guard duration > 0 else {
            super.alpha = target
            return
        }
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { [weak self] in
                // Runs synchronously inside `animate`, so the write guard is still set
                // and this lands on `super.alpha`.
                self?.alpha = target
            }
        )
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard !isDisabled else { return }

        isPressing = true
        isTouchInside = true
        applyEffectiveAlpha(duration: 0.1)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard !isDisabled, let touch = touches.first else { return }

        let location = touch.location(in: self)
        let wasInside = isTouchInside
        isTouchInside = bounds.contains(location)

        if wasInside != isTouchInside {
            applyEffectiveAlpha(duration: 0.1)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard !isDisabled else { return }

        // Read the hit-test result before clearing the press state.
        let shouldFirePress = isTouchInside
        isPressing = false
        isTouchInside = false
        applyEffectiveAlpha(duration: 0.15)

        if shouldFirePress {
            onPress?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard !isDisabled else { return }

        isPressing = false
        isTouchInside = false
        applyEffectiveAlpha(duration: 0.15)
    }

    // MARK: - Long press

    private func setupLongPressRecognizer() {
        let recognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        recognizer.minimumPressDuration = 0.5
        addGestureRecognizer(recognizer)
        longPressRecognizer = recognizer
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard !isDisabled else { return }
        if recognizer.state == .began {
            onLongPress?()
        }
    }
}
#endif
