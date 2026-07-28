import AppKit
import XCTest
@testable import VueNativeMacOS

/// Tests for the public custom-component escape hatch:
/// `VueNativeWindowController.registerComponent(_:factory:)`.
@MainActor
final class CustomComponentRegistrationTests: XCTestCase {

    private static let componentName = "DummyProbe"

    override func tearDown() {
        ComponentRegistry.shared.unregister(Self.componentName)
        NativeBridge.shared.reset()
        super.tearDown()
    }

    func testRegisterComponentMakesFactoryAvailable() {
        let factory = DummyProbeFactory()

        VueNativeWindowController.registerComponent(Self.componentName, factory: factory)

        // The registry resolves the registered factory by name...
        let resolved = ComponentRegistry.shared.factory(for: Self.componentName)
        XCTAssertNotNil(resolved)
        XCTAssertTrue(resolved is DummyProbeFactory)

        // ...and creates views of that type through it.
        let view = ComponentRegistry.shared.createView(type: Self.componentName)
        XCTAssertNotNil(view)
        XCTAssertTrue(view is DummyProbeView)
        XCTAssertEqual(factory.createCount, 1)
    }

    func testRegisteredComponentIsUsableThroughTheBridge() {
        let factory = DummyProbeFactory()
        VueNativeWindowController.registerComponent(Self.componentName, factory: factory)

        let bridge = NativeBridge.shared
        bridge.reset()

        bridge.processOperations([["op": "create", "args": [900, Self.componentName]]])

        let view = bridge.view(forNodeId: 900)
        XCTAssertNotNil(view)
        XCTAssertTrue(view is DummyProbeView)
    }
}

// MARK: - Test fixtures

private final class DummyProbeView: NSView {}

@MainActor
private final class DummyProbeFactory: NativeComponentFactory {
    private(set) var createCount = 0

    func createView() -> NSView {
        createCount += 1
        return DummyProbeView()
    }

    func updateProp(view: NSView, key: String, value: Any?) {}

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {}
}
