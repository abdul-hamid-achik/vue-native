#if canImport(UIKit)
import UIKit
import XCTest
@testable import VueNativeCore

@MainActor
final class DialogLifecycleTests: XCTestCase {
    func testAlertDialogDismissesAndDoesNotDuplicatePresentation() {
        var presented: [UIAlertController] = []
        var dismissed: [UIAlertController] = []
        let factory = VAlertDialogFactory(
            presentationHandler: { alert in
                presented.append(alert)
                return true
            },
            dismissalHandler: { dismissed.append($0) }
        )
        let view = factory.createView()
        var eventCount = 0
        factory.addEventListener(view: view, event: "confirm") { _ in eventCount += 1 }
        factory.addEventListener(view: view, event: "cancel") { _ in eventCount += 1 }
        factory.addEventListener(view: view, event: "action") { _ in eventCount += 1 }

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presented.count, 1)
        let firstAlert = presented[0]

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presented.count, 1)

        factory.updateProp(view: view, key: "visible", value: false)
        XCTAssertEqual(dismissed.count, 1)
        XCTAssertTrue(dismissed[0] === firstAlert)

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presented.count, 2)
        let secondAlert = presented[1]
        factory.destroyView(view: view)
        factory.destroyView(view: view)

        XCTAssertEqual(dismissed.count, 2)
        XCTAssertTrue(dismissed[1] === secondAlert)
        XCTAssertEqual(eventCount, 0)
    }

    func testActionSheetDismissesAndDoesNotDuplicatePresentation() {
        var presented: [UIAlertController] = []
        var dismissed: [UIAlertController] = []
        let factory = VActionSheetFactory(
            presentationHandler: { sheet in
                presented.append(sheet)
                return true
            },
            dismissalHandler: { dismissed.append($0) }
        )
        let view = factory.createView()
        var eventCount = 0
        factory.addEventListener(view: view, event: "action") { _ in eventCount += 1 }
        factory.addEventListener(view: view, event: "cancel") { _ in eventCount += 1 }

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presented.count, 1)
        let firstSheet = presented[0]

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presented.count, 1)

        factory.updateProp(view: view, key: "visible", value: false)
        XCTAssertEqual(dismissed.count, 1)
        XCTAssertTrue(dismissed[0] === firstSheet)

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presented.count, 2)
        let secondSheet = presented[1]
        factory.destroyView(view: view)
        factory.destroyView(view: view)

        XCTAssertEqual(dismissed.count, 2)
        XCTAssertTrue(dismissed[1] === secondSheet)
        XCTAssertEqual(eventCount, 0)
    }
}
#endif
