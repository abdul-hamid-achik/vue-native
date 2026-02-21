#if canImport(UIKit)
import UIKit
import ObjectiveC
import FlexLayout

// MARK: - Associated object key for factory reference

private var factoryAssociatedKey: UInt8 = 0

// MARK: - ComponentRegistry

/// Singleton registry that maps component type strings (e.g., "VView", "VText")
/// to their corresponding NativeComponentFactory instances.
/// When a view is created by a factory, the factory reference is stored on the
/// view via objc_setAssociatedObject for later prop updates and event wiring.
@MainActor
final class ComponentRegistry {

    // MARK: - Singleton

    static let shared = ComponentRegistry()

    // MARK: - Properties

    /// Mapping from component type strings to factory instances.
    private var factories: [String: NativeComponentFactory] = [:]

    // MARK: - Initialization

    private init() {
        registerDefaults()
    }

    /// Register all built-in component factories.
    private func registerDefaults() {
        register("VView", factory: VViewFactory())
        register("VText", factory: VTextFactory())
        register("VButton", factory: VButtonFactory())
        register("VInput", factory: VInputFactory())
        register("VSwitch", factory: VSwitchFactory())
        register("VActivityIndicator", factory: VActivityIndicatorFactory())
        register("VScrollView", factory: VScrollViewFactory())
        register("__ROOT__", factory: VRootFactory())
    }

    // MARK: - Registration

    /// Register a factory for a given component type string.
    /// Replaces any existing factory for that type.
    func register(_ type: String, factory: NativeComponentFactory) {
        factories[type] = factory
    }

    /// Unregister a factory for a given component type string.
    func unregister(_ type: String) {
        factories.removeValue(forKey: type)
    }

    // MARK: - View Creation

    /// Create a new UIView for the given component type.
    /// Returns nil if no factory is registered for the type.
    /// The factory is stored as an associated object on the created view
    /// so it can be retrieved later for prop updates and event handling.
    func createView(type: String) -> UIView? {
        guard let factory = factories[type] else {
            NSLog("[VueNative] Warning: No factory registered for component type '%@'", type)
            return nil
        }

        let view = factory.createView()

        // Store factory reference on the view for later lookups
        objc_setAssociatedObject(
            view,
            &factoryAssociatedKey,
            FactoryBox(factory: factory),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        return view
    }

    // MARK: - Factory Retrieval

    /// Retrieve the factory for the given component type string.
    func factory(for type: String) -> NativeComponentFactory? {
        return factories[type]
    }

    /// Retrieve the factory that was used to create the given view.
    /// Uses the associated object stored during createView().
    static func factory(for view: UIView) -> NativeComponentFactory? {
        guard let box = objc_getAssociatedObject(view, &factoryAssociatedKey) as? FactoryBox else {
            return nil
        }
        return box.factory
    }

    // MARK: - Prop Updates

    /// Update a property on a view using its associated factory.
    func updateProp(view: UIView, key: String, value: Any?) {
        guard let factory = ComponentRegistry.factory(for: view) else {
            NSLog("[VueNative] Warning: No factory found for view %@", String(describing: type(of: view)))
            return
        }
        factory.updateProp(view: view, key: key, value: value)
    }

    // MARK: - Event Listeners

    /// Add an event listener to a view using its associated factory.
    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let factory = ComponentRegistry.factory(for: view) else {
            NSLog("[VueNative] Warning: No factory found for view %@", String(describing: type(of: view)))
            return
        }
        factory.addEventListener(view: view, event: event, handler: handler)
    }

    /// Remove an event listener from a view using its associated factory.
    func removeEventListener(view: UIView, event: String) {
        guard let factory = ComponentRegistry.factory(for: view) else { return }
        factory.removeEventListener(view: view, event: event)
    }
}

// MARK: - FactoryBox

/// Box wrapper for NativeComponentFactory to store as an associated object.
/// objc_setAssociatedObject requires an AnyObject, so we wrap the protocol.
private final class FactoryBox {
    let factory: NativeComponentFactory

    init(factory: NativeComponentFactory) {
        self.factory = factory
    }
}

// MARK: - VRootFactory

/// Factory for the __ROOT__ component type.
/// Creates a plain UIView with FlexLayout enabled that serves as the root container.
final class VRootFactory: NativeComponentFactory {

    func createView() -> UIView {
        let view = UIView()
        // Accessing .flex automatically enables Yoga layout
        _ = view.flex
        return view
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        // Root view generally doesn't have custom props.
        // Delegate to StyleEngine for any style-related props.
        StyleEngine.apply(key: key, value: value, to: view)
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        // Root view doesn't support events in Phase 1
    }
}
#endif
