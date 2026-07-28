#if canImport(AppKit)
import XCTest
import AppKit
@testable import VueNativeMacOS

/// ErrorOverlayView tests: structured parsing of a raw JS error blob into
/// message / stack / component parts, structured rendering of those parts, and
/// the Reload button wiring.
@MainActor
final class ErrorOverlayViewTests: XCTestCase {

    override func tearDown() {
        // Never let a reload handler leak between tests.
        ErrorOverlayView.reloadHandler = nil
        super.tearDown()
    }

    // MARK: - Parsing

    func testParseSplitsMessageAndStack() {
        let raw = "TypeError: value is not a function\n\nevaluate@[native code]\nfoo@http://localhost:8174/app.js:10:5"
        let parsed = ErrorOverlayView.parse(raw)

        XCTAssertEqual(parsed.message, "TypeError: value is not a function")
        XCTAssertNotNil(parsed.stack)
        XCTAssertTrue(parsed.stack?.contains("evaluate@[native code]") == true)
        XCTAssertTrue(parsed.stack?.contains("foo@http://localhost:8174/app.js:10:5") == true)
    }

    func testParseProseWithoutStackKeepsFullMessage() {
        // The hot-reload failure notice is prose separated by blank lines but has
        // no stack frames -- nothing should be dropped into a phantom stack.
        let raw = "Hot reload failed.\n\nThe new bundle could not be evaluated.\n\nSave the file again to retry."
        let parsed = ErrorOverlayView.parse(raw)

        XCTAssertNil(parsed.stack)
        XCTAssertTrue(parsed.message.contains("Hot reload failed."))
        XCTAssertTrue(parsed.message.contains("Save the file again to retry."))
    }

    func testParseExtractsComponentNameFromRenderTrace() {
        let raw = "Cannot read property\n\nat <VButton onClick=fn>\nat <App>"
        let parsed = ErrorOverlayView.parse(raw)
        XCTAssertEqual(parsed.componentName, "VButton", "first render-trace component wins")
    }

    func testParseWithoutComponentYieldsNil() {
        let raw = "SyntaxError: unexpected token\n\nevaluate@[native code]"
        let parsed = ErrorOverlayView.parse(raw)
        XCTAssertNil(parsed.componentName)
    }

    // MARK: - Structured rendering

    func testConfigureRendersMessageStackAndComponent() {
        let overlay = ErrorOverlayView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        overlay.configure(
            message: "Boom",
            stack: "at foo (app.js:1:1)",
            componentName: "VButton"
        )

        XCTAssertEqual(overlay.messageLabel.stringValue, "Boom")
        XCTAssertEqual(overlay.stackTextView.string, "at foo (app.js:1:1)")
        XCTAssertFalse(overlay.componentLabel.isHidden, "component section shown when present")
        XCTAssertTrue(overlay.componentLabel.stringValue.contains("VButton"))
        XCTAssertNotNil(overlay.scrollView.superview, "stack trace scroll view is arranged when a stack exists")
    }

    func testConfigureHidesOptionalSectionsWhenAbsent() {
        let overlay = ErrorOverlayView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        overlay.configure(message: "Just a message", stack: nil, componentName: nil)

        XCTAssertEqual(overlay.messageLabel.stringValue, "Just a message")
        XCTAssertTrue(overlay.componentLabel.isHidden, "component section hidden when nil")

        // The scroll view is removed from the hierarchy (not merely emptied) so
        // it occupies no space when there is no stack trace to show.
        XCTAssertNil(overlay.scrollView.superview, "scroll view should not be arranged when stack is nil")
    }

    // MARK: - Reload button

    func testReloadButtonExistsAndIsWired() {
        let overlay = ErrorOverlayView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        overlay.configure(message: "Boom", stack: nil, componentName: nil)

        XCTAssertEqual(overlay.reloadButton.title, "Reload")
        XCTAssertNotNil(overlay.reloadButton.target)
        XCTAssertNotNil(overlay.reloadButton.action)
    }

    func testReloadButtonInvokesConfiguredHandler() {
        var reloadCount = 0
        ErrorOverlayView.reloadHandler = { reloadCount += 1 }

        let overlay = ErrorOverlayView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        overlay.configure(message: "Boom", stack: nil, componentName: nil)
        overlay.reloadButton.performClick(nil)

        XCTAssertEqual(reloadCount, 1, "Reload button must invoke the configured handler")
    }

    func testDismissButtonExists() {
        let overlay = ErrorOverlayView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        overlay.configure(message: "Boom", stack: nil, componentName: nil)
        XCTAssertEqual(overlay.dismissButton.title, "Dismiss")
        XCTAssertNotNil(overlay.dismissButton.action)
    }
}
#endif
