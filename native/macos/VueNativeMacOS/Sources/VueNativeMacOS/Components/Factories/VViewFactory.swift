import AppKit
import ObjectiveC

/// Factory for VView — the basic container component.
/// Maps to a FlippedView (NSView subclass) with a LayoutNode.
/// Supports all style props via StyleEngine and gesture events.
final class VViewFactory: NativeComponentFactory {

    func createView() -> NSView {
        let view = FlippedView()
        // Ensure layout node is attached
        view.ensureLayoutNode()
        return view
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        // All VView props are style-related — delegate to StyleEngine
        StyleEngine.apply(key: key, value: value, to: view)
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        switch event {

        // MARK: Click / Press
        case "press":
            let wrapper = ClickGestureWrapper(handler: handler)
            let click = NSClickGestureRecognizer(
                target: wrapper,
                action: #selector(ClickGestureWrapper.handleGesture(_:))
            )
            view.addGestureRecognizer(click)
            GestureStorage.store(wrapper, for: view, event: event)

        // MARK: Right Click
        case "rightPress":
            let wrapper = ClickGestureWrapper(handler: handler)
            let click = NSClickGestureRecognizer(
                target: wrapper,
                action: #selector(ClickGestureWrapper.handleGesture(_:))
            )
            click.buttonMask = 0x2  // Right mouse button
            view.addGestureRecognizer(click)
            GestureStorage.store(wrapper, for: view, event: event)

        // MARK: Pan
        case "pan":
            let panWrapper = PanGestureWrapper(handler: handler)
            let pan = NSPanGestureRecognizer(
                target: panWrapper,
                action: #selector(PanGestureWrapper.handle(_:))
            )
            view.addGestureRecognizer(pan)
            GestureStorage.storeObject(panWrapper, for: view, event: event)

        // MARK: Magnify (macOS equivalent of pinch)
        case "pinch", "magnify":
            let magWrapper = MagnificationGestureWrapper(handler: handler)
            let mag = NSMagnificationGestureRecognizer(
                target: magWrapper,
                action: #selector(MagnificationGestureWrapper.handle(_:))
            )
            view.addGestureRecognizer(mag)
            GestureStorage.storeObject(magWrapper, for: view, event: event)

        // MARK: Rotation
        case "rotate":
            let rotationWrapper = RotationGestureWrapper(handler: handler)
            let rotation = NSRotationGestureRecognizer(
                target: rotationWrapper,
                action: #selector(RotationGestureWrapper.handle(_:))
            )
            view.addGestureRecognizer(rotation)
            GestureStorage.storeObject(rotationWrapper, for: view, event: event)

        // MARK: Double Click / Double Tap
        case "doubleTap":
            let wrapper = DoubleClickWrapper(handler: handler)
            let click = NSClickGestureRecognizer(
                target: wrapper,
                action: #selector(DoubleClickWrapper.handleGesture(_:))
            )
            click.numberOfClicksRequired = 2
            view.addGestureRecognizer(click)
            GestureStorage.storeObject(wrapper, for: view, event: event)

        // MARK: Hover
        case "hover":
            let hoverWrapper = HoverWrapper(handler: handler)
            GestureStorage.storeObject(hoverWrapper, for: view, event: event)
            attachHoverHandler(to: view, wrapper: hoverWrapper)

        // MARK: Force Touch / Pressure
        case "forceTouch":
            let pressureWrapper = PressureWrapper(handler: handler)
            GestureStorage.storeObject(pressureWrapper, for: view, event: event)
            attachPressureHandler(to: view, wrapper: pressureWrapper)

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        GestureStorage.remove(for: view, event: event)
        // Remove matching gesture recognizers
        view.gestureRecognizers.forEach { recognizer in
            switch event {
            case "press" where recognizer is NSClickGestureRecognizer:
                let click = recognizer as! NSClickGestureRecognizer
                if click.buttonMask == 0x1 {
                    view.removeGestureRecognizer(recognizer)
                }
            case "rightPress" where recognizer is NSClickGestureRecognizer:
                let click = recognizer as! NSClickGestureRecognizer
                if click.buttonMask == 0x2 {
                    view.removeGestureRecognizer(recognizer)
                }
            case "pan" where recognizer is NSPanGestureRecognizer:
                view.removeGestureRecognizer(recognizer)
            case "pinch", "magnify":
                if recognizer is NSMagnificationGestureRecognizer {
                    view.removeGestureRecognizer(recognizer)
                }
            case "rotate":
                if recognizer is NSRotationGestureRecognizer {
                    view.removeGestureRecognizer(recognizer)
                }
            case "doubleTap" where recognizer is NSClickGestureRecognizer:
                let click = recognizer as! NSClickGestureRecognizer
                if click.numberOfClicksRequired == 2 {
                    view.removeGestureRecognizer(recognizer)
                }
            default:
                break
            }
        }
    }

    // MARK: - Hover Helper

    private func attachHoverHandler(to view: NSView, wrapper: HoverWrapper) {
        let trackingView = HoverTrackingView(wrapper: wrapper)
        objc_setAssociatedObject(view, &hoverTrackingKey, trackingView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        trackingView.attach(to: view)
    }

    // MARK: - Pressure Helper

    private func attachPressureHandler(to view: NSView, wrapper: PressureWrapper) {
        let pressureView = PressureTrackingView(wrapper: wrapper)
        objc_setAssociatedObject(view, &pressureTrackingKey, pressureView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        pressureView.attach(to: view)
    }
}

// MARK: - HoverTrackingView

/// Custom NSView that handles hover events via tracking area
private class HoverTrackingView: NSView {
    private let wrapper: HoverWrapper
    private weak var targetView: NSView?
    private var trackingArea: NSTrackingArea?

    init(wrapper: HoverWrapper) {
        self.wrapper = wrapper
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(to view: NSView) {
        targetView = view
        updateTrackingAreas()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        if let target = targetView {
            let area = NSTrackingArea(
                rect: target.bounds,
                options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }
    }

    override func mouseEntered(with event: NSEvent) {
        guard let target = targetView else { return }
        let location = convert(event.locationInWindow, from: nil)
        wrapper.handleHover(location: location, isEntering: true)
    }

    override func mouseExited(with event: NSEvent) {
        guard let target = targetView else { return }
        let location = convert(event.locationInWindow, from: nil)
        wrapper.handleHover(location: location, isEntering: false)
    }

    override func mouseMoved(with event: NSEvent) {
        guard let target = targetView else { return }
        let location = convert(event.locationInWindow, from: nil)
        wrapper.handleHover(location: location, isEntering: true)
    }
}

// MARK: - PressureTrackingView

/// Custom NSView that handles Force Touch / pressure events
private class PressureTrackingView: NSView {
    private let wrapper: PressureWrapper
    private weak var targetView: NSView?

    init(wrapper: PressureWrapper) {
        self.wrapper = wrapper
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(to view: NSView) {
        targetView = view
    }

    override func touchesBegan(with event: NSEvent) {
        super.touchesBegan(with: event)
        handlePressure(event: event)
    }

    override func touchesMoved(with event: NSEvent) {
        super.touchesMoved(with: event)
        handlePressure(event: event)
    }

    override func touchesEnded(with event: NSEvent) {
        super.touchesEnded(with: event)
        handlePressure(event: event)
    }

    private func handlePressure(event: NSEvent) {
        guard let target = targetView else { return }

        // Get pressure information (macOS 10.10.3+)
        let pressure = CGFloat(event.pressure)
        let location = event.locationInWindow
        let locationInView = target.convert(location, from: nil)

        // Pressure stages: 0 = no touch, 1-2 = light touch, 3+ = force touch
        let stage: Int
        if event.stage == 0 && pressure == 0 {
            stage = 0
        } else if event.stage == 1 {
            stage = 1
        } else if event.stage == 2 {
            stage = 2
        } else {
            stage = Int(event.stage)
        }

        wrapper.handlePressure(pressure: pressure, location: locationInView, stage: stage)
    }
}

private var hoverTrackingKey: UInt8 = 0
private var pressureTrackingKey: UInt8 = 0

// MARK: - GestureStorage

/// Stores gesture wrapper references as associated objects on views to prevent deallocation.
/// Uses a dictionary keyed by event name to support multiple gesture types per view.
enum GestureStorage {
    private static var storageKey: UInt8 = 0

    // MARK: Legacy — typed store for ClickGestureWrapper
    static func store(_ wrapper: ClickGestureWrapper, for view: NSView, event: String) {
        storeObject(wrapper, for: view, event: event)
    }

    // MARK: Generic store for any NSObject-derived wrapper
    static func storeObject(_ wrapper: NSObject, for view: NSView, event: String) {
        var storage = getStorage(for: view)
        storage[event] = wrapper
        setStorage(storage, for: view)
    }

    static func remove(for view: NSView, event: String) {
        var storage = getStorage(for: view)
        storage.removeValue(forKey: event)
        setStorage(storage, for: view)
    }

    static func get(for view: NSView, event: String) -> ClickGestureWrapper? {
        return getStorage(for: view)[event] as? ClickGestureWrapper
    }

    private static func getStorage(for view: NSView) -> [String: NSObject] {
        return objc_getAssociatedObject(view, &storageKey) as? [String: NSObject] ?? [:]
    }

    private static func setStorage(_ storage: [String: NSObject], for view: NSView) {
        objc_setAssociatedObject(view, &storageKey, storage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}