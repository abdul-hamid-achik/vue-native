#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Tests for the public custom-component escape hatch
/// ``VueNativeViewController/registerComponent(_:factory:)``.
@MainActor
final class CustomComponentRegistrationTests: XCTestCase {

    private let componentName = "VCustomDummy"

    override func tearDown() {
        // Avoid polluting the process-wide singleton for other tests.
        ComponentRegistry.shared.unregister(componentName)
        NativeBridge.shared.reset()
        super.tearDown()
    }

    func testRegisterComponentMakesFactoryRetrievable() {
        let factory = DummyFactory()

        VueNativeViewController.registerComponent(componentName, factory: factory)

        let retrieved = ComponentRegistry.shared.factory(for: componentName)
        XCTAssertNotNil(retrieved, "The registry should return the custom factory after registration")
        XCTAssertTrue((retrieved as? DummyFactory) === factory, "The exact registered factory instance should be returned")
    }

    func testRegisterComponentAllowsCreatingTheView() {
        let factory = DummyFactory()
        VueNativeViewController.registerComponent(componentName, factory: factory)

        let view = ComponentRegistry.shared.createView(type: componentName)

        XCTAssertNotNil(view, "createView should succeed for the custom-registered type")
        XCTAssertTrue(factory.createViewCalled, "The custom factory's createView should be invoked")
        XCTAssertTrue(view is DummyView, "The created view should come from the custom factory")
    }

    func testBridgeCreatesCustomComponentFromCreateOp() {
        let factory = DummyFactory()
        VueNativeViewController.registerComponent(componentName, factory: factory)

        let nodeId = 777
        NativeBridge.shared.processOperations([
            ["op": "create", "args": [nodeId, componentName]],
        ])

        let view = NativeBridge.shared.view(forNodeId: nodeId)
        XCTAssertNotNil(view, "The bridge should create a view for the custom component type")
        XCTAssertTrue(view is DummyView)
    }

    func testRegisterComponentOverwritesExistingFactory() {
        let first = DummyFactory()
        let second = DummyFactory()

        VueNativeViewController.registerComponent(componentName, factory: first)
        VueNativeViewController.registerComponent(componentName, factory: second)

        _ = ComponentRegistry.shared.createView(type: componentName)

        XCTAssertTrue(second.createViewCalled, "The latest registered factory should win")
        XCTAssertFalse(first.createViewCalled)
    }
}

// MARK: - Test fixtures

/// A trivial custom view so tests can assert the factory produced it.
private final class DummyView: UIView {}

/// A minimal custom factory that records createView invocations.
@MainActor
private final class DummyFactory: NativeComponentFactory {

    var createViewCalled = false

    func createView() -> UIView {
        createViewCalled = true
        return DummyView()
    }

    func updateProp(view: UIView, key: String, value: Any?) {}

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {}
}
#endif
