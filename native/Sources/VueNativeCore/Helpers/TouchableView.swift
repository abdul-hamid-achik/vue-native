#if canImport(UIKit)
import UIKit

/// Custom UIView subclass that provides button-like touch behavior
/// with configurable active opacity and support for press and long press events.
final class TouchableView: UIView {

    // MARK: - Public properties

    /// The opacity to apply when the user is pressing the view.
    var activeOpacity: CGFloat = 0.7

    /// Called when a tap completes within the view bounds.
    var onPress: (() -> Void)?

    /// Called when a long press gesture is recognized.
    var onLongPress: (() -> Void)?

    /// Whether touch interactions are disabled.
    var isDisabled: Bool = false {
        didSet {
            isUserInteractionEnabled = !isDisabled
            alpha = isDisabled ? 0.4 : 1.0
        }
    }

    // MARK: - Private properties

    private var longPressRecognizer: UILongPressGestureRecognizer?
    private var isTouchInside: Bool = false

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLongPressRecognizer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLongPressRecognizer()
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard !isDisabled else { return }

        isTouchInside = true
        UIView.animate(
            withDuration: 0.1,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { [weak self] in
                guard let self = self else { return }
                self.alpha = self.activeOpacity
            }
        )
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard !isDisabled, let touch = touches.first else { return }

        let location = touch.location(in: self)
        let wasInside = isTouchInside
        isTouchInside = bounds.contains(location)

        if wasInside != isTouchInside {
            UIView.animate(
                withDuration: 0.1,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: { [weak self] in
                    guard let self = self else { return }
                    self.alpha = self.isTouchInside ? self.activeOpacity : 1.0
                }
            )
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard !isDisabled else { return }

        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { [weak self] in
                self?.alpha = 1.0
            }
        )

        if isTouchInside {
            onPress?()
        }
        isTouchInside = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard !isDisabled else { return }

        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { [weak self] in
                self?.alpha = 1.0
            }
        )
        isTouchInside = false
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
