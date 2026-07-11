import AppKit
import XCTest
@testable import VueNativeMacOS

@MainActor
final class ModalLifecycleTests: XCTestCase {
    func testSheetDismissEventComesOnlyFromCompletionAndOnlyOnce() {
        var presentedSheets: [NSWindow] = []
        var dismissedSheets: [NSWindow] = []
        var completions: [VModalFactory.SheetCompletion] = []
        let factory = VModalFactory(
            sheetPresenter: { sheet, completion in
                presentedSheets.append(sheet)
                completions.append(completion)
                return true
            },
            sheetDismissal: { dismissedSheets.append($0) },
            panelPresenter: { _, _ in XCTFail("Expected sheet presentation") },
            panelDismissal: { _, _ in XCTFail("Expected sheet dismissal") }
        )
        let view = factory.createView()
        var showCount = 0
        var dismissCount = 0
        factory.addEventListener(view: view, event: "show") { _ in showCount += 1 }
        factory.addEventListener(view: view, event: "dismiss") { _ in dismissCount += 1 }
        factory.updateProp(view: view, key: "presentationStyle", value: "sheet")

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presentedSheets.count, 1)
        XCTAssertEqual(showCount, 1)

        factory.updateProp(view: view, key: "visible", value: false)
        XCTAssertEqual(dismissedSheets.count, 1)
        XCTAssertTrue(dismissedSheets[0] === presentedSheets[0])
        XCTAssertEqual(dismissCount, 0)

        completions[0](.stop)
        completions[0](.stop)
        XCTAssertEqual(dismissCount, 1)
    }

    func testDestroyingSheetClearsDismissCallbackBeforeCompletion() {
        var dismissedSheets: [NSWindow] = []
        var completion: VModalFactory.SheetCompletion?
        let factory = VModalFactory(
            sheetPresenter: { _, handler in
                completion = handler
                return true
            },
            sheetDismissal: { dismissedSheets.append($0) },
            panelPresenter: { _, _ in XCTFail("Expected sheet presentation") },
            panelDismissal: { _, _ in XCTFail("Expected sheet dismissal") }
        )
        let view = factory.createView()
        var dismissCount = 0
        factory.addEventListener(view: view, event: "dismiss") { _ in dismissCount += 1 }
        factory.updateProp(view: view, key: "presentationStyle", value: "sheet")
        factory.updateProp(view: view, key: "visible", value: true)

        factory.destroyView(view: view)
        completion?(.abort)

        XCTAssertEqual(dismissedSheets.count, 1)
        XCTAssertEqual(dismissCount, 0)
    }

    func testNonSheetPanelEmitsOneDirectDismissEvent() {
        var presentedPanels: [NSPanel] = []
        var dismissedPanels: [NSPanel] = []
        let factory = VModalFactory(
            sheetPresenter: { _, _ in
                XCTFail("Expected panel presentation")
                return false
            },
            sheetDismissal: { _ in XCTFail("Expected panel dismissal") },
            panelPresenter: { panel, _ in presentedPanels.append(panel) },
            panelDismissal: { panel, _ in dismissedPanels.append(panel) }
        )
        let view = factory.createView()
        var dismissCount = 0
        factory.addEventListener(view: view, event: "dismiss") { _ in dismissCount += 1 }

        factory.updateProp(view: view, key: "visible", value: true)
        factory.updateProp(view: view, key: "visible", value: false)
        factory.updateProp(view: view, key: "visible", value: false)

        XCTAssertEqual(presentedPanels.count, 1)
        XCTAssertEqual(dismissedPanels.count, 1)
        XCTAssertTrue(dismissedPanels[0] === presentedPanels[0])
        XCTAssertEqual(dismissCount, 1)
    }

    func testModalContentIsLaidOutWhenPresentedAndResized() throws {
        var presentedPanel: NSPanel?
        let factory = VModalFactory(
            sheetPresenter: { _, _ in false },
            sheetDismissal: { _ in },
            panelPresenter: { panel, _ in presentedPanel = panel },
            panelDismissal: { _, _ in }
        )
        let view = factory.createView()
        let child = FlippedView()
        let childNode = child.ensureLayoutNode()
        childNode.width = .percent(100)
        childNode.height = .percent(100)
        factory.insertChild(child, into: view, before: nil)

        factory.updateProp(view: view, key: "visible", value: true)

        let panel = try XCTUnwrap(presentedPanel)
        XCTAssertEqual(child.frame.width, 400, accuracy: 0.5)
        XCTAssertEqual(child.frame.height, 300, accuracy: 0.5)

        panel.setContentSize(NSSize(width: 520, height: 360))
        panel.contentView?.layoutSubtreeIfNeeded()

        XCTAssertEqual(child.frame.width, 520, accuracy: 0.5)
        XCTAssertEqual(child.frame.height, 360, accuracy: 0.5)

        childNode.width = .points(123)
        childNode.height = .points(77)
        childNode.alignSelf = .flexStart
        ExternalLayoutRootRegistry.layoutAll()

        XCTAssertEqual(child.frame.width, 123, accuracy: 0.5)
        XCTAssertEqual(child.frame.height, 77, accuracy: 0.5)
        factory.destroyView(view: view)
    }

    func testUserClosingPanelEmitsDismissOnceAndAllowsReopen() {
        var presentedPanels: [NSPanel] = []
        let factory = VModalFactory(
            sheetPresenter: { _, _ in false },
            sheetDismissal: { _ in },
            panelPresenter: { panel, _ in presentedPanels.append(panel) },
            panelDismissal: { _, _ in }
        )
        let view = factory.createView()
        var dismissCount = 0
        factory.addEventListener(view: view, event: "dismiss") { _ in
            dismissCount += 1
        }

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presentedPanels.count, 1)

        presentedPanels[0].close()
        presentedPanels[0].close()
        XCTAssertEqual(dismissCount, 1)

        factory.updateProp(view: view, key: "visible", value: true)
        XCTAssertEqual(presentedPanels.count, 2)
        factory.destroyView(view: view)
    }
}
