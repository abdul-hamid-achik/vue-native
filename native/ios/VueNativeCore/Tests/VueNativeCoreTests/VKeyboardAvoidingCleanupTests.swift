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

/// VN-18: on keyboard show, the focused field's enclosing scroll view is found so the field
/// (and the button under it) can be scrolled into view.
@MainActor
final class VKeyboardAvoidingScrollTests: XCTestCase {
    func testFindsTheNearestScrollViewInsideTheContainer() {
        let container = UIView()
        let scroll = UIScrollView()
        let content = UIView()
        let field = UITextField()
        container.addSubview(scroll)
        scroll.addSubview(content)
        content.addSubview(field)
        XCTAssertTrue(KeyboardAvoidingView.enclosingScrollView(of: field, within: container) === scroll)
    }

    func testNoScrollViewInsideTheContainerReturnsNil() {
        let outerScroll = UIScrollView()
        let container = UIView()
        let field = UITextField()
        outerScroll.addSubview(container)
        container.addSubview(field)
        XCTAssertNil(KeyboardAvoidingView.enclosingScrollView(of: field, within: container))
    }
}
#endif
