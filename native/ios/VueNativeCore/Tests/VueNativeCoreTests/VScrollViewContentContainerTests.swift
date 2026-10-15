#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// VN-13: contentContainerStyle styles the inner content view on iOS (it was ignored).
@MainActor
final class VScrollViewContentContainerTests: XCTestCase {
    func testPaddingAndFlexGrowReachTheContentView() throws {
        let factory = VScrollViewFactory()
        let scroll = try XCTUnwrap(factory.createView() as? UIScrollView)
        scroll.frame = CGRect(x: 0, y: 0, width: 300, height: 600)
        let child = UIView()
        _ = child.flex
        child.flex.height(100)
        factory.insertChild(child, into: try XCTUnwrap(VScrollViewFactory.contentView(for: scroll)), before: nil)

        factory.updateProp(view: scroll, key: "contentContainerStyle", value: ["padding": 20, "flexGrow": 1])
        VScrollViewFactory.layoutContentView(for: scroll)

        XCTAssertEqual(child.frame.minX, 20, accuracy: 0.5, "padding applies around the children")
        XCTAssertEqual(scroll.contentSize.height, 600, accuracy: 0.5, "flexGrow fills the viewport")

        factory.updateProp(view: scroll, key: "contentContainerStyle", value: [String: Any]())
        VScrollViewFactory.layoutContentView(for: scroll)
        XCTAssertEqual(child.frame.minX, 0, accuracy: 0.5, "removed styles are reset")
        XCTAssertEqual(scroll.contentSize.height, 100, accuracy: 0.5)
    }
}
#endif
