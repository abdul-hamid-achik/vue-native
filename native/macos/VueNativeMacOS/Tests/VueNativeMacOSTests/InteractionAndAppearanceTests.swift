#if canImport(AppKit)
import AppKit
import XCTest
@testable import VueNativeMacOS

/// Coverage for the interaction, appearance and platform-parity gaps:
/// keyboard activation of pressables (#11), flipped hover tracking (#10),
/// dark-mode re-resolution of style colors (#8), the `VInput` props that were
/// dropped on macOS (#14) and the loud `refresh` no-op (#15).
@MainActor
final class InteractionAndAppearanceTests: XCTestCase {

    // MARK: - Helpers

    private func keyEvent(keyCode: UInt16, characters: String, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        ) else {
            fatalError("could not synthesise a key event")
        }
        return event
    }

    // MARK: - #11 Keyboard activation

    /// Without `acceptsFirstResponder` a VButton is unreachable by Tab and
    /// VoiceOver's press action has no responder to activate.
    func testButtonAcceptsFirstResponder() {
        let button = VButtonFactory().createView()
        XCTAssertTrue(button.acceptsFirstResponder, "pressables must be keyboard-focusable")
    }

    func testPressableViewAcceptsFirstResponder() {
        let pressable = VPressableFactory().createView()
        XCTAssertTrue(pressable.acceptsFirstResponder)
    }

    /// Space on a focused button must fire `press`, matching NSButton and the
    /// web's `<button>`.
    func testSpaceActivatesButton() {
        let factory = VButtonFactory()
        let button = factory.createView()
        var presses = 0
        factory.addEventListener(view: button, event: "press") { _ in presses += 1 }

        button.keyDown(with: keyEvent(keyCode: 49, characters: " "))

        XCTAssertEqual(presses, 1, "Space must activate a focused button")
    }

    func testReturnActivatesPressableThroughKeyEquivalent() {
        let factory = VPressableFactory()
        let pressable = factory.createView()
        var presses = 0
        factory.addEventListener(view: pressable, event: "press") { _ in presses += 1 }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        addTeardownBlock { window.orderOut(nil) }
        let content = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        pressable.frame = NSRect(x: 0, y: 0, width: 100, height: 40)
        content.addSubview(pressable)
        window.contentView = content
        XCTAssertTrue(window.makeFirstResponder(pressable))

        XCTAssertTrue(pressable.performKeyEquivalent(with: keyEvent(keyCode: 36, characters: "\r")),
                      "Return must be claimed by the focused pressable")
        XCTAssertEqual(presses, 1)
    }

    /// A focused button must not swallow Return when it is *not* the first
    /// responder — that would break `VInput`'s submit.
    func testReturnIsNotClaimedWhenNotFirstResponder() {
        let factory = VButtonFactory()
        let button = factory.createView()
        var presses = 0
        factory.addEventListener(view: button, event: "press") { _ in presses += 1 }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        addTeardownBlock { window.orderOut(nil) }
        let content = FlippedView(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
        content.addSubview(button)
        window.contentView = content
        window.makeFirstResponder(content)

        XCTAssertFalse(button.performKeyEquivalent(with: keyEvent(keyCode: 36, characters: "\r")))
        XCTAssertEqual(presses, 0, "an unfocused button must not eat Return")
    }

    func testDisabledButtonIgnoresSpace() {
        let factory = VButtonFactory()
        let button = factory.createView()
        factory.updateProp(view: button, key: "disabled", value: true)
        var presses = 0
        factory.addEventListener(view: button, event: "press") { _ in presses += 1 }

        button.keyDown(with: keyEvent(keyCode: 49, characters: " "))

        XCTAssertEqual(presses, 0)
    }

    func testCommandModifiedSpaceIsNotSwallowed() {
        let factory = VButtonFactory()
        let button = factory.createView()
        var presses = 0
        factory.addEventListener(view: button, event: "press") { _ in presses += 1 }

        button.keyDown(with: keyEvent(keyCode: 49, characters: " ", modifiers: .command))

        XCTAssertEqual(presses, 0, "Cmd+Space is Spotlight's, not the button's")
    }

    // MARK: - #10 Hover tracking must be flipped

    /// `HoverTrackingView` used to be a plain (non-flipped) `NSView` that
    /// converted `event.locationInWindow` in its own space, so `onHover`
    /// reported `y` from the bottom edge.
    func testHoverTrackingViewIsFlipped() {
        let factory = VViewFactory()
        let view = factory.createView()
        view.frame = NSRect(x: 0, y: 0, width: 100, height: 100)

        factory.addEventListener(view: view, event: "hover") { _ in }

        guard let tracker = view.subviews.first else {
            return XCTFail("hover must attach a tracking subview")
        }
        XCTAssertTrue(tracker.isFlipped, "the hover tracker must be a FlippedView so Y is measured from the top")
    }

    func testPressureTrackingViewIsFlipped() {
        let factory = VViewFactory()
        let view = factory.createView()
        view.frame = NSRect(x: 0, y: 0, width: 100, height: 100)

        factory.addEventListener(view: view, event: "forceTouch") { _ in }

        guard let tracker = view.subviews.first else {
            return XCTFail("forceTouch must attach a tracking subview")
        }
        XCTAssertTrue(tracker.isFlipped)
    }

    // MARK: - #8 Dark-mode re-resolution

    /// `layer.backgroundColor` is a `CGColor`, which has no appearance, so a
    /// dynamic catalog color must be re-resolved when the effective appearance
    /// changes. `NSColor+Hex` documents `label`/`background`/`separator` as
    /// auto-adapting; this is what makes that true.
    func testSemanticBackgroundColorReResolvesOnAppearanceChange() {
        let view = FlippedView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        view.appearance = NSAppearance(named: .aqua)
        StyleEngine.apply(key: "backgroundColor", value: "label", to: view)
        guard let lightColor = view.layer?.backgroundColor else {
            return XCTFail("backgroundColor must reach the layer")
        }
        XCTAssertTrue(StyleEngine.hasDynamicColors(view))

        view.appearance = NSAppearance(named: .darkAqua)
        view.viewDidChangeEffectiveAppearance()

        guard let darkColor = view.layer?.backgroundColor else {
            return XCTFail("backgroundColor must still be applied after the appearance change")
        }
        XCTAssertFalse(lightColor == darkColor,
                       "`label` is near-black in Light Mode and near-white in Dark Mode; a snapshot would be identical")
    }

    func testBorderColorReResolvesOnAppearanceChange() {
        let view = FlippedView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        view.appearance = NSAppearance(named: .aqua)
        StyleEngine.apply(key: "borderColor", value: "separator", to: view)
        StyleEngine.apply(key: "borderWidth", value: 1.0, to: view)
        let lightColor = view.layer?.borderColor

        view.appearance = NSAppearance(named: .darkAqua)
        view.viewDidChangeEffectiveAppearance()

        let darkColor = view.layer?.borderColor
        XCTAssertNotNil(darkColor)
        XCTAssertFalse(lightColor == darkColor, "separator is a dynamic catalog color")
    }

    /// A literal hex color has no appearance, so it must survive re-resolution
    /// unchanged rather than being dropped.
    func testLiteralHexColorIsStableAcrossAppearanceChange() {
        let view = FlippedView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        view.appearance = NSAppearance(named: .aqua)
        StyleEngine.apply(key: "backgroundColor", value: "#FF0000", to: view)
        let light = view.layer?.backgroundColor

        view.appearance = NSAppearance(named: .darkAqua)
        view.viewDidChangeEffectiveAppearance()

        guard let light, let dark = view.layer?.backgroundColor else {
            return XCTFail("background must stay applied")
        }
        XCTAssertTrue(light == dark, "a literal hex color must not change with the appearance")
    }

    func testClearingBackgroundColorDropsTheStoredDynamicColor() {
        let view = FlippedView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        StyleEngine.apply(key: "backgroundColor", value: "label", to: view)
        XCTAssertTrue(StyleEngine.hasDynamicColors(view))

        StyleEngine.apply(key: "backgroundColor", value: nil, to: view)
        XCTAssertFalse(StyleEngine.hasDynamicColors(view))
        XCTAssertNil(view.layer?.backgroundColor)
    }

    // MARK: - #7 Content view is not hardcoded black

    func testContentViewControllerUsesWindowBackgroundColor() throws {
        // The fix routes the host content view through StyleEngine's dynamic
        // color path with the `background` semantic name; assert the mapping
        // itself rather than booting a window (which would disturb the
        // single-process NativeBridge shared with other tests).
        XCTAssertEqual(NSColor.fromHex("background"), NSColor.windowBackgroundColor)

        let view = FlippedView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        view.appearance = NSAppearance(named: .aqua)
        StyleEngine.apply(key: "backgroundColor", value: "background", to: view)
        guard let applied = view.layer?.backgroundColor,
              let color = NSColor(cgColor: applied)?.usingColorSpace(.sRGB) else {
            return XCTFail("the content-view background must be applied")
        }
        XCTAssertGreaterThan(color.redComponent, 0.5, "Light Mode must not boot to a black window")
    }

    // MARK: - #14 VInput props declared in TS but dropped on macOS

    func testNumericKeyboardTypeInstallsAFormatter() {
        let factory = VInputFactory()
        let field = factory.createView()
        factory.updateProp(view: field, key: "keyboardType", value: "numeric")

        XCTAssertNotNil((field as? NSTextField)?.formatter, "numeric input must reject non-numeric keystrokes")
        XCTAssertEqual(StyleEngine.getInternalProp("__keyboardType", from: field) as? String, "numeric")
    }

    func testDecimalKeyboardTypeAllowsFloats() {
        let factory = VInputFactory()
        let field = factory.createView()
        factory.updateProp(view: field, key: "keyboardType", value: "decimal-pad")

        let formatter = (field as? NSTextField)?.formatter as? NumberFormatter
        XCTAssertEqual(formatter?.allowsFloats, true)
    }

    func testDefaultKeyboardTypeClearsTheFormatter() {
        let factory = VInputFactory()
        let field = factory.createView()
        factory.updateProp(view: field, key: "keyboardType", value: "numeric")
        factory.updateProp(view: field, key: "keyboardType", value: "default")

        XCTAssertNil((field as? NSTextField)?.formatter)
    }

    /// `returnKeyType` genuinely has no AppKit counterpart, but it must be loud
    /// and inspectable rather than silently dropped.
    func testUnsupportedInputPropsAreRecordedNotSilentlyDropped() {
        let factory = VInputFactory()
        let field = factory.createView()
        factory.updateProp(view: field, key: "returnKeyType", value: "search")
        factory.updateProp(view: field, key: "autoCapitalize", value: "words")

        XCTAssertEqual(StyleEngine.getInternalProp("__returnKeyType", from: field) as? String, "search")
        XCTAssertEqual(StyleEngine.getInternalProp("__autoCapitalize", from: field) as? String, "words")
    }

    func testAutoCorrectIsRecordedOnTheField() {
        let factory = VInputFactory()
        let field = factory.createView()
        factory.updateProp(view: field, key: "autoCorrect", value: false)

        XCTAssertEqual(StyleEngine.getInternalProp("__autoCorrect", from: field) as? Bool, false)
        XCTAssertEqual((field as? VInputTextField)?.autoCorrectEnabled, false)
    }

    // MARK: - #11 autoFocus

    func testAutoFocusIsRecordedAndPendingWhileDetached() {
        let factory = VInputFactory()
        let field = factory.createView()
        factory.updateProp(view: field, key: "autoFocus", value: true)

        XCTAssertEqual(StyleEngine.getInternalProp("__autoFocus", from: field) as? Bool, true)
        XCTAssertEqual((field as? VInputTextField)?.pendingAutoFocus, true,
                       "focus must be deferred until the field reaches a window")
    }

    func testAutoFocusClearsOnceTheFieldReachesAWindow() {
        let factory = VInputFactory()
        let field = factory.createView()
        factory.updateProp(view: field, key: "autoFocus", value: true)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        addTeardownBlock { window.orderOut(nil) }
        window.contentView = FlippedView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        window.contentView?.addSubview(field)

        XCTAssertEqual((field as? VInputTextField)?.pendingAutoFocus, false,
                       "viewDidMoveToWindow must consume the pending focus request")
    }

    /// The secure-cell swap replaces the cell that owns the `keyboardType`
    /// formatter, so it must be carried across.
    func testSecureTextEntryPreservesTheKeyboardTypeFormatter() {
        let factory = VInputFactory()
        let field = factory.createView()
        factory.updateProp(view: field, key: "keyboardType", value: "numeric")
        let formatter = (field as? NSTextField)?.formatter
        XCTAssertNotNil(formatter)

        factory.updateProp(view: field, key: "secureTextEntry", value: true)

        XCTAssertTrue((field as? NSTextField)?.formatter === formatter,
                      "the numeric formatter must survive the secure cell swap")
    }

    // MARK: - #15 refresh is refused loudly, not silently

    func testScrollViewRefreshListenerIsFlaggedUnsupported() {
        let factory = VScrollViewFactory()
        let view = factory.createView()

        factory.addEventListener(view: view, event: "refresh") { _ in
            XCTFail("refresh must never fire on macOS")
        }

        XCTAssertEqual(StyleEngine.getInternalProp("__refreshUnsupported", from: view) as? Bool, true)

        factory.removeEventListener(view: view, event: "refresh")
        XCTAssertNil(StyleEngine.getInternalProp("__refreshUnsupported", from: view))
    }

    /// `scroll` must keep working alongside the refused `refresh`.
    func testScrollViewStillRegistersScroll() {
        let factory = VScrollViewFactory()
        let view = factory.createView()
        factory.addEventListener(view: view, event: "scroll") { _ in }
        XCTAssertNil(StyleEngine.getInternalProp("__refreshUnsupported", from: view))
    }
}
#endif
