import AppKit
import XCTest
@testable import VueNativeMacOS

private class VImageURLProtocolStub: URLProtocol {
    static var onStart: ((VImageURLProtocolStub) -> Void)?
    static var onStop: (() -> Void)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        VImageURLProtocolStub.onStart?(self)
    }

    override func stopLoading() {
        VImageURLProtocolStub.onStop?()
    }

    func finish(with data: Data) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/tiff"]
              ) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    static func reset() {
        onStart = nil
        onStop = nil
    }
}

@MainActor
final class ComponentFactoryTests: XCTestCase {

    private func makeVImageTestSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VImageURLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = FlippedView(frame: window.contentView?.bounds ?? .zero)
        return window
    }

    func testVModalStyleTargetsVisibleOverlay() {
        let factory = VModalFactory()
        let placeholder = factory.createView()
        factory.updateProp(view: placeholder, key: "backgroundColor", value: "#ff0000")
        let child = FlippedView()

        factory.insertChild(child, into: placeholder, before: nil)

        guard let overlayColor = child.superview?.layer?.backgroundColor,
              let color = NSColor(cgColor: overlayColor)?.usingColorSpace(.sRGB) else {
            return XCTFail("Expected overlay background color")
        }
        XCTAssertEqual(color.redComponent, 1, accuracy: 0.01)
        XCTAssertEqual(color.greenComponent, 0, accuracy: 0.01)
        XCTAssertEqual(color.blueComponent, 0, accuracy: 0.01)
        XCTAssertNil(placeholder.layer?.backgroundColor)
    }

    func testVListFactoryAppliesPublicProps() {
        let factory = VListFactory()
        guard let container = factory.createView() as? VListContainerView else {
            return XCTFail("Expected VListContainerView")
        }

        factory.updateProp(view: container, key: "estimatedItemHeight", value: 72)
        factory.updateProp(view: container, key: "showsScrollIndicator", value: false)
        factory.updateProp(view: container, key: "bounces", value: false)

        XCTAssertEqual(container.estimatedItemHeight, 72)
        XCTAssertFalse(container.scrollView.hasVerticalScroller)
        XCTAssertEqual(container.scrollView.verticalScrollElasticity, .none)
        XCTAssertEqual(container.scrollView.horizontalScrollElasticity, .none)
    }

    func testVSectionListFactoryBuildsRowsFromInsertedChildren() {
        let factory = VSectionListFactory()
        guard let container = factory.createView() as? VSectionListContainerView else {
            return XCTFail("Expected VSectionListContainerView")
        }

        let header = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        header.ensureLayoutNode()
        StyleEngine.setInternalPropDirect("__sectionHeader", value: true, on: header)

        let item1 = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 44))
        item1.ensureLayoutNode()
        let item2 = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 44))
        item2.ensureLayoutNode()

        factory.insertChild(header, into: container, before: nil)
        factory.insertChild(item1, into: container, before: nil)
        factory.insertChild(item2, into: container, before: nil)

        XCTAssertEqual(container.numberOfRows(in: container.tableView), 3)
        XCTAssertTrue(container.tableView(container.tableView, isGroupRow: 0))
        XCTAssertFalse(container.tableView(container.tableView, isGroupRow: 1))
    }

    func testVSectionListFactoryEmitsFlatScrollPayload() {
        let factory = VSectionListFactory()
        guard let container = factory.createView() as? VSectionListContainerView else {
            return XCTFail("Expected VSectionListContainerView")
        }

        var payload: [String: Any]?
        factory.addEventListener(view: container, event: "scroll") { eventPayload in
            payload = eventPayload as? [String: Any]
        }

        container.scrollView.frame = NSRect(x: 0, y: 0, width: 120, height: 240)
        container.tableView.frame = NSRect(x: 0, y: 0, width: 240, height: 960)
        container.scrollView.contentView.scroll(to: NSPoint(x: 12, y: 34))
        NotificationCenter.default.post(
            name: NSView.boundsDidChangeNotification,
            object: container.scrollView.contentView
        )

        guard let payload else {
            return XCTFail("Expected scroll payload")
        }

        XCTAssertEqual(payload["x"] as? CGFloat, 12)
        XCTAssertEqual(payload["y"] as? CGFloat, 34)
        XCTAssertEqual(payload["contentWidth"] as? CGFloat, 240)
        XCTAssertEqual(payload["contentHeight"] as? CGFloat, 960)
        XCTAssertEqual(payload["layoutWidth"] as? CGFloat, 120)
        XCTAssertEqual(payload["layoutHeight"] as? CGFloat, 240)
        XCTAssertNil(payload["contentOffset"])
        XCTAssertNil(payload["layoutMeasurement"])
    }

    func testVPickerFactoryUsesTheCrossPlatformDateTimeModes() {
        let factory = VPickerFactory()
        guard let picker = factory.createView() as? NSDatePicker else {
            return XCTFail("Expected NSDatePicker")
        }

        factory.updateProp(view: picker, key: "mode", value: "time")
        XCTAssertEqual(picker.datePickerElements, [.hourMinute])

        factory.updateProp(view: picker, key: "mode", value: "datetime")
        XCTAssertEqual(picker.datePickerElements, [.yearMonthDay, .hourMinute])

        factory.updateProp(view: picker, key: "mode", value: "date")
        XCTAssertEqual(picker.datePickerElements, [.yearMonthDay])
    }

    func testVPickerFactoryUsesEpochMillisecondsAndClearsBounds() {
        let factory = VPickerFactory()
        guard let picker = factory.createView() as? NSDatePicker else {
            return XCTFail("Expected NSDatePicker")
        }
        let milliseconds = 1_725_043_755_000.0

        factory.updateProp(view: picker, key: "value", value: milliseconds)
        XCTAssertEqual(picker.dateValue.timeIntervalSince1970 * 1000, milliseconds, accuracy: 0.001)

        factory.updateProp(view: picker, key: "minimumDate", value: milliseconds - 1_000)
        XCTAssertNotNil(picker.minDate)
        factory.updateProp(view: picker, key: "minimumDate", value: nil)
        XCTAssertNil(picker.minDate)
    }

    func testVImageFactoryAcceptsSourceObjectAndEmitsMessageErrorPayload() {
        let factory = VImageFactory()
        guard let imageView = factory.createView() as? NSImageView else {
            return XCTFail("Expected NSImageView")
        }
        let missingImage = "vue-native-missing-\(UUID().uuidString).png"
        var payload: [String: Any]?

        factory.addEventListener(view: imageView, event: "error") { eventPayload in
            payload = eventPayload as? [String: Any]
        }
        factory.updateProp(
            view: imageView,
            key: "source",
            value: ["uri": missingImage]
        )

        XCTAssertEqual(payload?["message"] as? String, "Image not found: \(missingImage)")
        XCTAssertNil(payload?["error"])
    }

    func testVImageFactoryPreservesStringSourceCompatibility() {
        let factory = VImageFactory()
        guard let imageView = factory.createView() as? NSImageView else {
            return XCTFail("Expected NSImageView")
        }
        let missingImage = "vue-native-missing-\(UUID().uuidString).png"
        var payload: [String: Any]?

        factory.addEventListener(view: imageView, event: "error") { eventPayload in
            payload = eventPayload as? [String: Any]
        }
        factory.updateProp(view: imageView, key: "source", value: missingImage)

        XCTAssertEqual(payload?["message"] as? String, "Image not found: \(missingImage)")
    }

    func testVImageFactoryDestroyViewCancelsInFlightRequest() {
        let requestStarted = expectation(description: "image request started")
        let requestCancelled = expectation(description: "image request cancelled")
        VImageURLProtocolStub.onStart = { _ in requestStarted.fulfill() }
        VImageURLProtocolStub.onStop = { requestCancelled.fulfill() }

        let session = makeVImageTestSession()
        defer {
            VImageURLProtocolStub.reset()
            session.invalidateAndCancel()
        }
        let factory = VImageFactory(urlSession: session)
        guard let imageView = factory.createView() as? NSImageView else {
            return XCTFail("Expected NSImageView")
        }

        factory.updateProp(
            view: imageView,
            key: "source",
            value: ["uri": "https://example.invalid/destroyed.png"]
        )
        wait(for: [requestStarted], timeout: 1)

        factory.destroyView(view: imageView)

        wait(for: [requestCancelled], timeout: 1)
    }

    func testVImageFactoryReplacingSourceSuppressesCancelledRequestError() {
        let firstRequestStarted = expectation(description: "first image request started")
        let secondRequestStarted = expectation(description: "second image request started")
        let firstRequestCancelled = expectation(description: "first image request cancelled")
        let staleError = expectation(description: "cancelled request does not emit an error")
        staleError.isInverted = true
        let lock = NSLock()
        var stoppedRequestCount = 0

        VImageURLProtocolStub.onStart = { stub in
            switch stub.request.url?.lastPathComponent {
            case "first.png":
                firstRequestStarted.fulfill()
            case "second.png":
                secondRequestStarted.fulfill()
            default:
                break
            }
        }
        VImageURLProtocolStub.onStop = {
            lock.lock()
            stoppedRequestCount += 1
            let isFirstCancellation = stoppedRequestCount == 1
            lock.unlock()
            if isFirstCancellation {
                firstRequestCancelled.fulfill()
            }
        }

        let session = makeVImageTestSession()
        defer {
            VImageURLProtocolStub.reset()
            session.invalidateAndCancel()
        }
        let factory = VImageFactory(urlSession: session)
        guard let imageView = factory.createView() as? NSImageView else {
            return XCTFail("Expected NSImageView")
        }
        factory.addEventListener(view: imageView, event: "error") { _ in
            staleError.fulfill()
        }

        factory.updateProp(
            view: imageView,
            key: "source",
            value: ["uri": "https://example.invalid/first.png"]
        )
        wait(for: [firstRequestStarted], timeout: 1)

        factory.updateProp(
            view: imageView,
            key: "source",
            value: ["uri": "https://example.invalid/second.png"]
        )

        wait(for: [firstRequestCancelled, secondRequestStarted], timeout: 1)
        wait(for: [staleError], timeout: 0.25)
        factory.destroyView(view: imageView)
    }

    func testVImageFactoryLateCompletionCannotOverwriteReplacementSource() throws {
        let firstRequestStarted = expectation(description: "first image request started")
        let secondRequestStarted = expectation(description: "second image request started")
        let staleLoad = expectation(description: "late first request does not emit a load event")
        staleLoad.isInverted = true
        let lock = NSLock()
        var firstRequestStub: VImageURLProtocolStub?

        VImageURLProtocolStub.onStart = { stub in
            switch stub.request.url?.lastPathComponent {
            case "late-first.tiff":
                lock.lock()
                firstRequestStub = stub
                lock.unlock()
                firstRequestStarted.fulfill()
            case "current-second.tiff":
                secondRequestStarted.fulfill()
            default:
                break
            }
        }

        let session = makeVImageTestSession()
        defer {
            VImageURLProtocolStub.reset()
            session.invalidateAndCancel()
        }
        let factory = VImageFactory(urlSession: session)
        guard let imageView = factory.createView() as? NSImageView else {
            return XCTFail("Expected NSImageView")
        }
        factory.addEventListener(view: imageView, event: "load") { _ in
            staleLoad.fulfill()
        }

        factory.updateProp(
            view: imageView,
            key: "source",
            value: ["uri": "https://example.invalid/late-first.tiff"]
        )
        wait(for: [firstRequestStarted], timeout: 1)

        let image = NSImage(size: NSSize(width: 1, height: 1), flipped: false) { rect in
            NSColor.red.setFill()
            rect.fill()
            return true
        }
        let imageData = try XCTUnwrap(image.tiffRepresentation)
        lock.lock()
        let capturedFirstRequest = firstRequestStub
        lock.unlock()
        try XCTUnwrap(capturedFirstRequest).finish(with: imageData)

        // Replace the source in the same main-actor turn. The first URLSession
        // callback can only dispatch back to main after this token changes.
        factory.updateProp(
            view: imageView,
            key: "source",
            value: ["uri": "https://example.invalid/current-second.tiff"]
        )

        wait(for: [secondRequestStarted], timeout: 1)
        wait(for: [staleLoad], timeout: 0.25)
        XCTAssertNil(imageView.image)
        factory.destroyView(view: imageView)
    }

    func testVToolbarAttachesWhenItemsArriveBeforeWindow() {
        let factory = VToolbarFactory()
        let view = factory.createView()
        let window = makeWindow()

        factory.updateProp(view: view, key: "displayMode", value: "labelOnly")
        factory.updateProp(view: view, key: "showsBaselineSeparator", value: false)
        factory.updateProp(
            view: view,
            key: "items",
            value: [["id": "new", "label": "New", "icon": "doc.badge.plus"]]
        )

        XCTAssertNil(window.toolbar)

        window.contentView?.addSubview(view)

        guard let toolbar = window.toolbar else {
            return XCTFail("Expected toolbar after placeholder moved to a window")
        }

        XCTAssertEqual(toolbar.displayMode, .labelOnly)
        let defaultIdentifiers = toolbar.delegate?
            .toolbarDefaultItemIdentifiers?(toolbar)
            .map { $0.rawValue }
        XCTAssertEqual(defaultIdentifiers, ["new"])
    }

    func testVToolbarRebuildsWhenItemClickHandlerArrivesAfterItems() {
        let factory = VToolbarFactory()
        let view = factory.createView()
        let window = makeWindow()
        var payload: [String: Any]?

        window.contentView?.addSubview(view)
        factory.updateProp(
            view: view,
            key: "items",
            value: [["id": "new", "label": "New"]]
        )
        factory.addEventListener(view: view, event: "itemClick") { eventPayload in
            payload = eventPayload as? [String: Any]
        }

        guard let toolbar = window.toolbar else {
            return XCTFail("Expected toolbar")
        }

        let itemIdentifier = NSToolbarItem.Identifier("new")
        if !toolbar.items.contains(where: { $0.itemIdentifier == itemIdentifier }) {
            toolbar.insertItem(withItemIdentifier: itemIdentifier, at: 0)
        }

        guard let toolbarItem = toolbar.items.first(where: { $0.itemIdentifier == itemIdentifier }),
              let target = toolbarItem.target as? NSObject,
              let action = toolbarItem.action else {
            return XCTFail("Expected toolbar item target and action")
        }

        target.perform(action, with: toolbarItem)

        XCTAssertEqual(payload?["id"] as? String, "new")
    }

    func testVToolbarDetachesOwnedToolbarWhenPlaceholderLeavesWindow() {
        let factory = VToolbarFactory()
        let view = factory.createView()
        let window = makeWindow()

        factory.updateProp(
            view: view,
            key: "items",
            value: [["id": "new", "label": "New"]]
        )
        window.contentView?.addSubview(view)
        XCTAssertNotNil(window.toolbar)

        view.removeFromSuperview()

        XCTAssertNil(window.toolbar)
    }
}
