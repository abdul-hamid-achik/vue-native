import AppKit
import XCTest
@testable import VueNativeMacOS

@MainActor
final class AlertDialogLifecycleTests: XCTestCase {
    func testAlertDialogEndsSheetWithoutActionAndAvoidsDuplicates() {
        var presented: [NSAlert] = []
        var dismissed: [NSAlert] = []
        var completions: [VAlertDialogFactory.SheetCompletion] = []
        let factory = VAlertDialogFactory(
            sheetPresenter: { alert, completion in
                presented.append(alert)
                completions.append(completion)
                return true
            },
            sheetDismissal: { dismissed.append($0) },
            modalRunner: { _ in
                XCTFail("Injected sheet presentation should avoid runModal")
                return .abort
            }
        )
        let view = factory.createView()
        var eventCount = 0
        factory.addEventListener(view: view, event: "action") { _ in eventCount += 1 }

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presented.count, 1)
        let firstAlert = presented[0]

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presented.count, 1)

        factory.updateProp(view: view, key: "visible", value: false)
        XCTAssertEqual(dismissed.count, 1)
        XCTAssertTrue(dismissed[0] === firstAlert)
        completions[0](.alertFirstButtonReturn)
        XCTAssertEqual(eventCount, 0)

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presented.count, 2)
        let secondAlert = presented[1]
        factory.destroyView(view: view)
        factory.destroyView(view: view)

        XCTAssertEqual(dismissed.count, 2)
        XCTAssertTrue(dismissed[1] === secondAlert)
        completions[1](.alertFirstButtonReturn)
        XCTAssertEqual(eventCount, 0)
    }

    func testAlertDialogCompletionEmitsActionAndAllowsAnotherPresentation() {
        var presented: [NSAlert] = []
        var completions: [VAlertDialogFactory.SheetCompletion] = []
        let factory = VAlertDialogFactory(
            sheetPresenter: { alert, completion in
                presented.append(alert)
                completions.append(completion)
                return true
            },
            sheetDismissal: { _ in },
            modalRunner: { _ in .abort }
        )
        let view = factory.createView()
        var payload: [String: Any]?
        factory.addEventListener(view: view, event: "action") { event in
            payload = event as? [String: Any]
        }

        factory.updateProp(view: view, key: "visible", value: true)
        completions[0](.alertFirstButtonReturn)

        XCTAssertEqual(payload?["buttonIndex"] as? Int, 0)
        XCTAssertEqual(payload?["buttonLabel"] as? String, "OK")

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presented.count, 2)
    }

    func testFallbackModalCanBeHiddenWithoutStaleActionOrDuplicatePresentation() {
        var factory: VAlertDialogFactory!
        var view: NSView!
        var modalRunCount = 0
        var dismissed: [NSAlert] = []
        var eventCount = 0
        factory = VAlertDialogFactory(
            sheetPresenter: { _, _ in false },
            sheetDismissal: { dismissed.append($0) },
            modalRunner: { _ in
                modalRunCount += 1
                factory.updateProp(view: view, key: "visible", value: true)
                factory.updateProp(view: view, key: "visible", value: false)
                return .alertFirstButtonReturn
            }
        )
        view = factory.createView()
        factory.addEventListener(view: view, event: "action") { _ in eventCount += 1 }

        factory.updateProp(view: view, key: "visible", value: true)

        XCTAssertEqual(modalRunCount, 1)
        XCTAssertEqual(dismissed.count, 1)
        XCTAssertEqual(eventCount, 0)
    }

    func testDestroyAbortsFallbackModalAfterClearingCallback() {
        var factory: VAlertDialogFactory!
        var view: NSView!
        var dismissed: [NSAlert] = []
        var eventCount = 0
        factory = VAlertDialogFactory(
            sheetPresenter: { _, _ in false },
            sheetDismissal: { dismissed.append($0) },
            modalRunner: { _ in
                factory.destroyView(view: view)
                return .alertFirstButtonReturn
            }
        )
        view = factory.createView()
        factory.addEventListener(view: view, event: "action") { _ in eventCount += 1 }

        factory.updateProp(view: view, key: "visible", value: true)

        XCTAssertEqual(dismissed.count, 1)
        XCTAssertEqual(eventCount, 0)
    }
}
