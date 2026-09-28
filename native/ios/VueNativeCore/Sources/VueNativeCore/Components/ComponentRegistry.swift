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

    /// Factories contributed by optional add-on products, keyed by component
    /// tag. Filled through ``provideOptionalComponent(_:factory:)`` and read by
    /// `registerDefaults()`, so an add-on's component joins the default set
    /// without core linking against it.
    private static var optionalComponentFactories: [String: NativeComponentFactory] = [:]

    /// Components whose factories live in optional add-on products that core
    /// deliberately does not link against, mapped to the fix a host must apply.
    ///
    /// `<VSVG>` is the only entry today: it is the framework's sole consumer of
    /// SVGKit, so an app that never renders an SVG should not have to resolve
    /// SVGKit — nor the CocoaLumberjack pin SVGKit's stale platform floors force
    /// on every consumer. Core keeps this table (instead of letting the add-on
    /// supply it) precisely so an app that skipped the add-on can be told what
    /// to do; a tag that resolves to nothing otherwise renders as an invisible
    /// gap with no diagnostic to act on.
    static let optionalComponentHints: [String: String] = [
        "VSVG": "add the VueNativeCoreSVG library product to your app target and call "
            + "VueNativeCoreSVG.register() before the first view is created (for example in "
            + "application(_:didFinishLaunchingWithOptions:))"
    ]

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
        register("VImage", factory: VImageFactory())
        register("VKeyboardAvoiding", factory: VKeyboardAvoidingFactory())
        register("VSafeArea", factory: VSafeAreaFactory())
        register("VSlider", factory: VSliderFactory())
        register("VList", factory: VListFactory())
        register("VModal", factory: VModalFactory())
        register("VAlertDialog", factory: VAlertDialogFactory())
        register("VStatusBar", factory: VStatusBarFactory())
        register("VWebView", factory: VWebViewFactory())
        register("VProgressBar", factory: VProgressBarFactory())
        register("VPicker", factory: VPickerFactory())
        register("VSegmentedControl", factory: VSegmentedControlFactory())
        register("VActionSheet", factory: VActionSheetFactory())
        register("VRefreshControl", factory: VRefreshControlFactory())
        register("VPressable", factory: VPressableFactory())
        register("VSectionList", factory: VSectionListFactory())
        register("VCheckbox", factory: VCheckboxFactory())
        register("VRadio", factory: VRadioFactory())
        register("VDropdown", factory: VDropdownFactory())
        register("VVideo", factory: VVideoFactory())
        // <VSVG> is not built in. Its factory ships in the optional
        // VueNativeCoreSVG product — the only thing in the framework that needs
        // SVGKit — and installs itself through
        // ``provideOptionalComponent(_:factory:)``. Registering it here (rather
        // than leaving it to the add-on alone) keeps the tag part of the default
        // component set whenever that product is present. When it is not,
        // `createView(type:)` reports the missing product via
        // ``optionalComponentHints`` instead of silently rendering nothing.
        if let svgFactory = Self.optionalComponentFactories["VSVG"] {
            register("VSVG", factory: svgFactory)
        }
        register("__ROOT__", factory: VRootFactory())
    }

    // MARK: - Optional (add-on) components

    /// Contribute the factory for a component core does not link against.
    ///
    /// Add-on products call this from their own bootstrap — `VueNativeCoreSVG`
    /// for `<VSVG>`. Safe to call before *or* after the registry is first used:
    /// the factory is recorded for `registerDefaults()` and registered
    /// immediately when the singleton already exists, so a host's bootstrap
    /// order cannot silently drop a component.
    static func provideOptionalComponent(_ type: String, factory: NativeComponentFactory) {
        optionalComponentFactories[type] = factory
        shared.register(type, factory: factory)
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
            NSLog("%@", Self.unknownComponentMessage(for: type, registered: factories.keys.sorted()))
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

    /// Destroy a view using the factory that created it. The bridge calls this
    /// once when a node is permanently unregistered, never during a move.
    func destroyView(view: UIView) {
        guard let factory = ComponentRegistry.factory(for: view) else { return }
        factory.destroyView(view: view)
    }

    // MARK: - Debug helpers

    /// Build the diagnostic logged when a tag has no factory.
    ///
    /// A tag listed in ``optionalComponentHints`` is not a typo — its factory
    /// lives in an add-on product the host has not linked or has not
    /// bootstrapped — so the message names that product and the exact call
    /// instead of dumping the registered list. That distinction is the whole
    /// point of the split: `createView` returning nil is not a crash, so an
    /// unregistered `<VSVG>` would otherwise be an invisible gap in the UI with
    /// nothing actionable in the log.
    static func unknownComponentMessage(for type: String, registered: [String]) -> String {
        if let hint = optionalComponentHints[type] {
            return "[VueNative] Error: <\(type)> is provided by an optional product that has not "
                + "been registered, so it renders nothing. To fix: \(hint)."
        }

        #if DEBUG
        var message = "[VueNative] Warning: No factory registered for component type '\(type)'. Registered types: \(registered.joined(separator: ", "))"
        if let suggestion = suggestion(for: type, among: registered) {
            message += ". Did you mean '\(suggestion)'?"
        }
        return message
        #else
        return "[VueNative] Warning: No factory registered for component type '\(type)'"
        #endif
    }

    /// Suggest a registered component type for a mistyped name. Used only for
    /// DEBUG diagnostics so an unknown component error points at the likely fix.
    private static func suggestion(for type: String, among registered: [String]) -> String? {
        let lower = type.lowercased()
        guard !lower.isEmpty else { return nil }
        if let match = registered.first(where: { $0.lowercased() == lower }) {
            return match
        }
        return registered.first {
            $0.lowercased().contains(lower) || lower.contains($0.lowercased())
        }
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
        // Configure the root Yoga node to fill its container and stack children
        // vertically (column direction matches the default CSS flex behaviour).
        // grow(1) + width/height 100% ensures the entire safe-area rect is
        // occupied even if the first child doesn't explicitly set flex: 1.
        view.flex
            .direction(.column)
            .grow(1)
            .shrink(1)
            .width(100%)
            .height(100%)
        return view
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        // Root view generally doesn't have custom props.
        // Delegate to StyleEngine for any style-related props.
        StyleEngine.apply(key: key, value: value, to: view)
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        if event == "press" {
            let wrapper = GestureWrapper(handler: handler)
            let tap = UITapGestureRecognizer(
                target: wrapper,
                action: #selector(GestureWrapper.handleGesture(_:))
            )
            view.addGestureRecognizer(tap)
            view.isUserInteractionEnabled = true
            GestureStorage.store(wrapper, for: view, event: event)
        }
    }
}
#endif
