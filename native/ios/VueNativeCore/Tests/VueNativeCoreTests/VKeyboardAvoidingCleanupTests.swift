#if canImport(UIKit)
import UIKit
import XCTest
@testable import VueNativeCore

@MainActor
final class VKeyboardAvoidingCleanupTests: XCTestCase {
    func testDestroyViewTwiceClearsKeyboardObservers() throws {
        let factory = VKeyboardAvoidingFactory()
        let view = factory.createView()

        XCTAssertFalse(try observerIsNil(named: "showObserver", in: view))
        XCTAssertFalse(try observerIsNil(named: "hideObserver", in: view))

        factory.destroyView(view: view)
        factory.destroyView(view: view)

        XCTAssertTrue(try observerIsNil(named: "showObserver", in: view))
        XCTAssertTrue(try observerIsNil(named: "hideObserver", in: view))
    }

    private func observerIsNil(named name: String, in view: UIView) throws -> Bool {
        let value = try XCTUnwrap(Mirror(reflecting: view).children.first { $0.label == name }?.value)
        let optional = Mirror(reflecting: value)
        return optional.displayStyle == .optional && optional.children.isEmpty
    }
}
#endif
