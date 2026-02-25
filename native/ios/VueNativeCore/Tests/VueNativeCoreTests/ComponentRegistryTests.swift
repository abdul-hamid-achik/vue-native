#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

@MainActor
final class ComponentRegistryTests: XCTestCase {

    // MARK: - Properties

    private var registry: ComponentRegistry!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        registry = ComponentRegistry.shared
    }

    override func tearDown() {
        registry = nil
        super.tearDown()
    }

    // MARK: - All Built-in Component Types Registered

    func testAllBuiltInComponentTypesRegistered() {
        let expectedTypes = [
            "VView", "VText", "VButton", "VInput", "VSwitch",
            "VActivityIndicator", "VScrollView", "VImage",
            "VKeyboardAvoiding", "VSafeArea", "VSlider", "VList",
            "VModal", "VAlertDialog", "VStatusBar", "VWebView",
            "VProgressBar", "VPicker", "VSegmentedControl", "VActionSheet",
            "VRefreshControl", "VPressable", "VSectionList",
            "VCheckbox", "VRadio", "VDropdown", "VVideo",
            "__ROOT__",
        ]

        for type in expectedTypes {
            let view = registry.createView(type: type)
            XCTAssertNotNil(view, "createView should return non-nil for registered type '\(type)'")
        }
    }

    // MARK: - Unknown Type Returns Nil

    func testUnknownTypeReturnsNil() {
        let view = registry.createView(type: "NonExistentComponent")
        XCTAssertNil(view, "createView should return nil for unknown component types")
    }

    // MARK: - Specific View Type Assertions

    func testVTextCreatesUILabel() {
        let view = registry.createView(type: "VText")
        XCTAssertNotNil(view, "VText should create a view")
        XCTAssertTrue(view is UILabel, "VText should create a UILabel, got \(type(of: view!))")
    }

    func testVViewCreatesUIView() {
        let view = registry.createView(type: "VView")
        XCTAssertNotNil(view, "VView should create a view")
        // VView creates a plain UIView (not a subclass)
        XCTAssertNotNil(view, "VView should create a UIView")
    }

    func testVSwitchCreatesUISwitch() {
        let view = registry.createView(type: "VSwitch")
        XCTAssertNotNil(view, "VSwitch should create a view")
        XCTAssertTrue(view is UISwitch, "VSwitch should create a UISwitch, got \(type(of: view!))")
    }

    func testVImageCreatesUIImageView() {
        let view = registry.createView(type: "VImage")
        XCTAssertNotNil(view, "VImage should create a view")
        XCTAssertTrue(view is UIImageView, "VImage should create a UIImageView, got \(type(of: view!))")
    }

    // MARK: - Factory Stored on Created View

    func testFactoryStoredOnCreatedView() {
        let view = registry.createView(type: "VView")!
        let factory = ComponentRegistry.factory(for: view)
        XCTAssertNotNil(factory, "Factory should be stored on created view via associated object")
    }

    func testFactoryForTypeRetrieval() {
        let factory = registry.factory(for: "VText")
        XCTAssertNotNil(factory, "factory(for:) should return the registered factory for 'VText'")
    }

    func testFactoryForUnknownType() {
        let factory = registry.factory(for: "NonExistent")
        XCTAssertNil(factory, "factory(for:) should return nil for unregistered types")
    }

    // MARK: - Custom Factory Registration

    func testRegisterCustomFactory() {
        let customFactory = StubFactory()
        registry.register("CustomComponent", factory: customFactory)

        let view = registry.createView(type: "CustomComponent")
        XCTAssertNotNil(view, "createView should return a view for the custom-registered type")
        XCTAssertTrue(customFactory.createViewCalled, "Custom factory's createView should have been called")

        // Clean up to avoid polluting singleton state
        registry.unregister("CustomComponent")
    }

    // MARK: - Unregister

    func testUnregisterRemovesFactory() {
        let customFactory = StubFactory()
        registry.register("TempComponent", factory: customFactory)

        // Verify it's registered
        XCTAssertNotNil(registry.createView(type: "TempComponent"), "Should exist before unregister")

        registry.unregister("TempComponent")

        let view = registry.createView(type: "TempComponent")
        XCTAssertNil(view, "createView should return nil after unregistering")
    }

    // MARK: - updateProp Dispatches to Factory

    func testUpdatePropDispatchesToFactory() {
        let customFactory = StubFactory()
        registry.register("PropTestComponent", factory: customFactory)

        let view = registry.createView(type: "PropTestComponent")!
        registry.updateProp(view: view, key: "testKey", value: "testValue")

        XCTAssertTrue(customFactory.updatePropCalled, "updateProp should dispatch to the factory")
        XCTAssertEqual(customFactory.lastPropKey, "testKey", "The correct key should be passed")
        XCTAssertEqual(customFactory.lastPropValue as? String, "testValue", "The correct value should be passed")

        // Clean up
        registry.unregister("PropTestComponent")
    }

    // MARK: - addEventListener Dispatches to Factory

    func testAddEventListenerDispatchesToFactory() {
        let customFactory = StubFactory()
        registry.register("EventTestComponent", factory: customFactory)

        let view = registry.createView(type: "EventTestComponent")!
        registry.addEventListener(view: view, event: "press") { _ in }

        XCTAssertTrue(customFactory.addEventListenerCalled, "addEventListener should dispatch to the factory")
        XCTAssertEqual(customFactory.lastEventName, "press", "The correct event name should be passed")

        // Clean up
        registry.unregister("EventTestComponent")
    }

    // MARK: - removeEventListener Dispatches to Factory

    func testRemoveEventListenerDispatchesToFactory() {
        let customFactory = StubFactory()
        registry.register("RemoveEventTestComponent", factory: customFactory)

        let view = registry.createView(type: "RemoveEventTestComponent")!
        registry.removeEventListener(view: view, event: "press")

        XCTAssertTrue(customFactory.removeEventListenerCalled, "removeEventListener should dispatch to the factory")

        // Clean up
        registry.unregister("RemoveEventTestComponent")
    }

    // MARK: - Factory for Plain UIView Returns Nil

    func testFactoryForPlainUIViewReturnsNil() {
        let plainView = UIView()
        let factory = ComponentRegistry.factory(for: plainView)
        XCTAssertNil(factory, "Factory should be nil for views not created by the registry")
    }

    // MARK: - Register Overwrites Existing

    func testRegisterOverwritesExisting() {
        let factory1 = StubFactory()
        let factory2 = StubFactory()

        registry.register("OverwriteTest", factory: factory1)
        registry.register("OverwriteTest", factory: factory2)

        let view = registry.createView(type: "OverwriteTest")
        XCTAssertNotNil(view, "Should still create a view after overwrite")
        XCTAssertTrue(factory2.createViewCalled, "Second factory's createView should be called")
        XCTAssertFalse(factory1.createViewCalled, "First factory's createView should NOT be called")

        // Clean up
        registry.unregister("OverwriteTest")
    }
}

// MARK: - StubFactory

/// A test-only factory that records method calls for verification.
@MainActor
private final class StubFactory: NativeComponentFactory {

    var createViewCalled = false
    var updatePropCalled = false
    var addEventListenerCalled = false
    var removeEventListenerCalled = false
    var lastPropKey: String?
    var lastPropValue: Any?
    var lastEventName: String?

    func createView() -> UIView {
        createViewCalled = true
        let view = UIView()
        _ = view.flex
        return view
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        updatePropCalled = true
        lastPropKey = key
        lastPropValue = value
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        addEventListenerCalled = true
        lastEventName = event
    }

    func removeEventListener(view: UIView, event: String) {
        removeEventListenerCalled = true
    }
}
#endif
