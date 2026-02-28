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
            default:
                break
            }
        }
    }
}

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
