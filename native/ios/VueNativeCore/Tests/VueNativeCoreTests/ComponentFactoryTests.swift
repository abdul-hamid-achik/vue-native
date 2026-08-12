#if canImport(UIKit)
import XCTest
import UIKit
import FlexLayout
@testable import VueNativeCore

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

    // MARK: - VViewFactory Tests

    func testVViewFactoryCreatesUIView() {
        let factory = VViewFactory()
        let view = factory.createView()
        XCTAssertNotNil(view, "VViewFactory should create a UIView")
        // Should be a plain UIView (not a subclass like UILabel, UISwitch etc.)
        XCTAssertTrue(type(of: view) == UIView.self, "VViewFactory should create a plain UIView")
    }

    func testVViewFactoryAppliesStyleProps() {
        let factory = VViewFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "opacity", value: 0.5)
        XCTAssertEqual(view.alpha, 0.5, accuracy: 0.001, "opacity prop should set alpha")

        factory.updateProp(view: view, key: "backgroundColor", value: "#ff0000")
        XCTAssertNotNil(view.backgroundColor, "backgroundColor should be set via StyleEngine")
    }

    func testVViewFactoryRegistersPressTapGesture() {
        let factory = VViewFactory()
        let view = factory.createView()

        factory.addEventListener(view: view, event: "press") { _ in }

        XCTAssertTrue(view.isUserInteractionEnabled, "User interaction should be enabled after adding press event")
        let tapRecognizers = view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer } ?? []
        XCTAssertFalse(tapRecognizers.isEmpty, "Should have a UITapGestureRecognizer for press event")
    }

    func testVViewFactoryRemovesPressEvent() {
        let factory = VViewFactory()
        let view = factory.createView()

        factory.addEventListener(view: view, event: "press") { _ in }
        let countBefore = view.gestureRecognizers?.count ?? 0
        XCTAssertGreaterThan(countBefore, 0, "Should have gesture recognizers after addEventListener")

        factory.removeEventListener(view: view, event: "press")
        let tapRecognizers = view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer } ?? []
        XCTAssertTrue(tapRecognizers.isEmpty, "Tap gesture recognizer should be removed")
    }

    /// Regression test: `attachForceTouchHandler` used to only store a weak
    /// reference to the target view and never add the handler to the view
    /// hierarchy, so `touchesBegan`/`touchesMoved` never fired and force touch
    /// events never reached JS. The handler must be an actual subview.
    func testVViewFactoryForceTouchHandlerAttachesToViewHierarchy() {
        let factory = VViewFactory()
        let view = factory.createView()
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)

        factory.addEventListener(view: view, event: "forceTouch") { _ in }

        XCTAssertEqual(view.subviews.count, 1, "forceTouch should attach its handler as a subview of the target view")
        let handlerView = view.subviews[0]
        XCTAssertTrue(handlerView.isUserInteractionEnabled, "the force-touch overlay must accept touches to receive touchesBegan/Moved")
        XCTAssertEqual(handlerView.frame, view.bounds, "the force-touch overlay should cover the full bounds of the target view")
    }

    // MARK: - VTextFactory Tests

    func testVTextFactoryCreatesUILabel() {
        let factory = VTextFactory()
        let view = factory.createView()
        XCTAssertTrue(view is UILabel, "VTextFactory should create a UILabel")
    }

    func testVTextFactoryLabelDefaultsMultiLine() {
        let factory = VTextFactory()
        let view = factory.createView() as! UILabel
        XCTAssertEqual(view.numberOfLines, 0, "Label should default to multi-line (numberOfLines = 0)")
    }

    func testVTextFactorySetsText() {
        let factory = VTextFactory()
        let label = factory.createView() as! UILabel

        factory.updateProp(view: label, key: "text", value: "Hello World")
        XCTAssertEqual(label.text, "Hello World", "text prop should set the label's text")
    }

    func testVTextFactorySetsFontSize() {
        let factory = VTextFactory()
        let label = factory.createView() as! UILabel

        factory.updateProp(view: label, key: "fontSize", value: 24.0)
        XCTAssertEqual(label.font.pointSize, 24.0, accuracy: 0.1, "fontSize prop should set point size")
    }

    func testVTextFactorySetsTextColor() {
        let factory = VTextFactory()
        let label = factory.createView() as! UILabel

        factory.updateProp(view: label, key: "color", value: "#0000ff")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        label.textColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(b, 1.0, accuracy: 0.01, "Blue component should be 1.0")
    }

    func testVTextFactorySetsTextAlignment() {
        let factory = VTextFactory()
        let label = factory.createView() as! UILabel

        factory.updateProp(view: label, key: "textAlign", value: "center")
        XCTAssertEqual(label.textAlignment, .center, "textAlign 'center' should set .center alignment")

        factory.updateProp(view: label, key: "textAlign", value: "right")
        XCTAssertEqual(label.textAlignment, .right, "textAlign 'right' should set .right alignment")
    }

    func testVTextFactorySetsNumberOfLines() {
        let factory = VTextFactory()
        let label = factory.createView() as! UILabel

        factory.updateProp(view: label, key: "numberOfLines", value: 3)
        XCTAssertEqual(label.numberOfLines, 3, "numberOfLines prop should set the value")
    }

    func testVTextFactoryTextNilClearsText() {
        let factory = VTextFactory()
        let label = factory.createView() as! UILabel

        factory.updateProp(view: label, key: "text", value: "Hello")
        factory.updateProp(view: label, key: "text", value: nil)
        XCTAssertNil(label.text, "Setting text to nil should clear label.text")
    }

    func testVTextFactoryFontWeightMap() {
        XCTAssertEqual(VTextFactory.fontWeightMap["bold"], .bold, "bold should map to .bold")
        XCTAssertEqual(VTextFactory.fontWeightMap["400"], .regular, "400 should map to .regular")
        XCTAssertEqual(VTextFactory.fontWeightMap["700"], .bold, "700 should map to .bold")
    }

    func testVTextFactoryTextTransformUppercase() {
        let factory = VTextFactory()
        let label = factory.createView() as! UILabel
        factory.updateProp(view: label, key: "text", value: "hello")
        factory.updateProp(view: label, key: "textTransform", value: "uppercase")
        XCTAssertEqual(label.text, "HELLO", "textTransform 'uppercase' should uppercase the text")
    }

    /// Regression test: lineHeight, letterSpacing, and textDecorationLine each
    /// used to rebuild `attributedText` from scratch with only their own
    /// attribute, so setting all three left only the last one applied
    /// (dictionary iteration order is non-deterministic). They must accumulate.
    func testVTextFactoryLineHeightLetterSpacingAndDecorationCoexist() {
        let factory = VTextFactory()
        let label = factory.createView() as! UILabel

        factory.updateProp(view: label, key: "text", value: "Hello")
        factory.updateProp(view: label, key: "lineHeight", value: 24.0)
        factory.updateProp(view: label, key: "letterSpacing", value: 2.0)
        factory.updateProp(view: label, key: "textDecorationLine", value: "underline")

        let attrs = label.attributedText?.attributes(at: 0, effectiveRange: nil) ?? [:]
        let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.minimumLineHeight, 24.0, "lineHeight should survive letterSpacing/textDecorationLine being set afterward")
        XCTAssertEqual(attrs[.kern] as? CGFloat, 2.0, "letterSpacing should survive textDecorationLine being set afterward")
        XCTAssertEqual(attrs[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue, "textDecorationLine should still apply")
    }

    /// Regression test: setting .text (or changing the font) resets
    /// attributedText, which used to silently drop lineHeight/letterSpacing/
    /// textDecorationLine. They must be reapplied from accumulated state.
    func testVTextFactoryAccumulatedAttributesSurviveTextChange() {
        let factory = VTextFactory()
        let label = factory.createView() as! UILabel

        factory.updateProp(view: label, key: "text", value: "Hello")
        factory.updateProp(view: label, key: "lineHeight", value: 24.0)
        factory.updateProp(view: label, key: "text", value: "World")

        XCTAssertEqual(label.text, "World", "text prop should still update the label's text")
        let attrs = label.attributedText?.attributes(at: 0, effectiveRange: nil) ?? [:]
        let paragraphStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.minimumLineHeight, 24.0, "lineHeight should be reapplied after the text prop changes")
    }

    // MARK: - VButtonFactory Tests

    func testVButtonFactoryCreatesTouchableView() {
        let factory = VButtonFactory()
        let view = factory.createView()
        XCTAssertTrue(view is TouchableView, "VButtonFactory should create a TouchableView")
    }

    func testVButtonFactoryDisabledProp() {
        let factory = VButtonFactory()
        let touchable = factory.createView() as! TouchableView

        factory.updateProp(view: touchable, key: "disabled", value: true)
        XCTAssertTrue(touchable.isDisabled, "disabled=true should set isDisabled")
        XCTAssertFalse(touchable.isUserInteractionEnabled, "disabled should disable user interaction")

        factory.updateProp(view: touchable, key: "disabled", value: false)
        XCTAssertFalse(touchable.isDisabled, "disabled=false should unset isDisabled")
    }

    func testVButtonFactoryActiveOpacityProp() {
        let factory = VButtonFactory()
        let touchable = factory.createView() as! TouchableView

        factory.updateProp(view: touchable, key: "activeOpacity", value: 0.3)
        XCTAssertEqual(touchable.activeOpacity, 0.3, accuracy: 0.001, "activeOpacity should be set to 0.3")
    }

    func testVButtonFactoryRegistersPress() {
        let factory = VButtonFactory()
        let touchable = factory.createView() as! TouchableView
        var pressed = false

        factory.addEventListener(view: touchable, event: "press") { _ in
            pressed = true
        }

        // Simulate press by calling onPress directly
        touchable.onPress?()
        XCTAssertTrue(pressed, "press event handler should be called")
    }

    func testVButtonFactoryRemovesPressEvent() {
        let factory = VButtonFactory()
        let touchable = factory.createView() as! TouchableView
        var pressed = false

        factory.addEventListener(view: touchable, event: "press") { _ in
            pressed = true
        }
        factory.removeEventListener(view: touchable, event: "press")

        touchable.onPress?()
        XCTAssertFalse(pressed, "press handler should be nil after remove")
    }

    func testVButtonFactoryDefaultsToButtonAccessibilityTrait() {
        let factory = VButtonFactory()
        let view = factory.createView()
        XCTAssertTrue(
            view.accessibilityTraits.contains(.button),
            "VButton should announce as a button to VoiceOver by default"
        )
    }

    func testVButtonFactoryLaysOutChildrenAsCenteredRow() {
        let factory = VButtonFactory()
        let button = factory.createView()
        button.frame = CGRect(x: 0, y: 0, width: 200, height: 60)

        let icon = UIView()
        icon.flex.width(20).height(20)
        let label = UIView()
        label.flex.width(40).height(20)
        button.flex.addItem(icon)
        button.flex.addItem(label)

        button.flex.layout(mode: .fitContainer)

        // Row direction: the second child sits to the right of the first
        // (a column default would place it below).
        XCTAssertGreaterThan(
            label.frame.minX,
            icon.frame.minX,
            "VButton children should be laid out horizontally (row), matching Android"
        )
        // alignItems center: both children share a vertical centerline.
        XCTAssertEqual(icon.frame.midY, label.frame.midY, accuracy: 0.5, "children should be vertically centered")
    }

    // MARK: - VInputFactory Tests

    /// The registered view is a stable container; the editing control lives inside it.
    private func inputContainer(_ view: UIView) -> VInputContainerView? {
        return view as? VInputContainerView
    }

    func testVInputFactoryCreatesUITextField() {
        let factory = VInputFactory()
        let view = factory.createView()
        let container = inputContainer(view)
        XCTAssertNotNil(container, "VInputFactory should register a VInputContainerView")
        XCTAssertNotNil(container?.textField, "single-line VInput should contain a UITextField by default")
        XCTAssertNil(container?.textView, "single-line VInput should not contain a UITextView")
    }

    func testVInputFactoryKeepsStableViewIdentityAcrossMultilineToggle() {
        let factory = VInputFactory()
        let view = factory.createView()
        // The registered view's identity must not change when multiline toggles,
        // otherwise the bridge's nodeId → view registry would break.
        factory.updateProp(view: view, key: "multiline", value: true)
        XCTAssertTrue(view === inputContainer(view), "registered container identity must survive a multiline toggle")
        factory.updateProp(view: view, key: "multiline", value: false)
        XCTAssertTrue(view === inputContainer(view), "registered container identity must survive toggling back")
    }

    func testVInputFactorySetsText() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "text", value: "Hello Input")
        XCTAssertEqual(inputContainer(view)?.textField?.text, "Hello Input", "text prop should set text field text")
    }

    func testVInputFactorySetsPlaceholder() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "placeholder", value: "Enter text...")
        XCTAssertEqual(inputContainer(view)?.textField?.placeholder, "Enter text...", "placeholder prop should be set")
    }

    func testVInputFactorySetsSecureTextEntry() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "secureTextEntry", value: true)
        XCTAssertEqual(inputContainer(view)?.textField?.isSecureTextEntry, true, "secureTextEntry should be true")

        factory.updateProp(view: view, key: "secureTextEntry", value: false)
        XCTAssertEqual(inputContainer(view)?.textField?.isSecureTextEntry, false, "secureTextEntry should be false")
    }

    func testVInputFactorySetsKeyboardType() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "keyboardType", value: "numeric")
        XCTAssertEqual(inputContainer(view)?.textField?.keyboardType, .numberPad, "keyboardType 'numeric' should set .numberPad")

        factory.updateProp(view: view, key: "keyboardType", value: "email")
        XCTAssertEqual(inputContainer(view)?.textField?.keyboardType, .emailAddress, "keyboardType 'email' should set .emailAddress")
    }

    func testVInputFactoryEditable() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "editable", value: false)
        XCTAssertEqual(inputContainer(view)?.textField?.isEnabled, false, "editable=false should disable the text field")

        factory.updateProp(view: view, key: "editable", value: true)
        XCTAssertEqual(inputContainer(view)?.textField?.isEnabled, true, "editable=true should enable the text field")
    }

    func testVInputFactoryHandlesChangeTextEvent() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.addEventListener(view: view, event: "changetext") { _ in }

        // Verify delegate is set up
        XCTAssertNotNil(inputContainer(view)?.textField?.delegate, "UITextField delegate should be set after addEventListener")
    }

    func testVInputFactoryReturnKeyType() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "returnKeyType", value: "done")
        XCTAssertEqual(inputContainer(view)?.textField?.returnKeyType, .done, "returnKeyType 'done' should set .done")

        factory.updateProp(view: view, key: "returnKeyType", value: "search")
        XCTAssertEqual(inputContainer(view)?.textField?.returnKeyType, .search, "returnKeyType 'search' should set .search")
    }

    func testVInputFactoryMultilineCreatesUITextView() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "multiline", value: true)

        let container = inputContainer(view)
        XCTAssertNotNil(container?.textView, "multiline=true should swap the inner control to a UITextView")
        XCTAssertNil(container?.textField, "multiline=true should remove the inner UITextField")
    }

    func testVInputFactoryMultilineToggleBackCreatesUITextField() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "multiline", value: true)
        factory.updateProp(view: view, key: "multiline", value: false)

        let container = inputContainer(view)
        XCTAssertNotNil(container?.textField, "toggling multiline back off should restore a UITextField")
        XCTAssertNil(container?.textView, "toggling multiline back off should remove the UITextView")
    }

    func testVInputFactoryPreservesTextAcrossMultilineToggle() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "text", value: "preserved text")
        factory.updateProp(view: view, key: "multiline", value: true)
        XCTAssertEqual(inputContainer(view)?.textView?.text, "preserved text", "text should survive the swap to multiline")

        factory.updateProp(view: view, key: "multiline", value: false)
        XCTAssertEqual(inputContainer(view)?.textField?.text, "preserved text", "text should survive the swap back to single-line")
    }

    func testVInputFactoryMultilinePreservesKeyboardTraits() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "keyboardType", value: "email")
        factory.updateProp(view: view, key: "multiline", value: true)

        XCTAssertEqual(inputContainer(view)?.textView?.keyboardType, .emailAddress, "keyboardType should survive the swap to multiline")
    }

    func testVInputFactorySecureMultilineFallsBackToSingleLine() {
        let factory = VInputFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "multiline", value: true)
        factory.updateProp(view: view, key: "secureTextEntry", value: true)

        let container = inputContainer(view)
        XCTAssertNotNil(container?.textField, "secure multiline input falls back to a single-line field (UITextView has no secure mode)")
        XCTAssertEqual(container?.textField?.isSecureTextEntry, true, "fallback field should be secure")
        XCTAssertNil(container?.textView, "secure multiline input must not use a UITextView")
    }

    func testVInputFactoryMultilineChangeTextEvent() {
        let factory = VInputFactory()
        let view = factory.createView()
        factory.updateProp(view: view, key: "multiline", value: true)

        var received: String?
        factory.addEventListener(view: view, event: "changetext") { payload in
            received = payload as? String
        }

        guard let textView = inputContainer(view)?.textView else {
            return XCTFail("multiline input should contain a UITextView")
        }
        guard let delegate = textView.delegate as? InputDelegateProxy else {
            return XCTFail("UITextView delegate should be the InputDelegateProxy after addEventListener")
        }

        textView.text = "typed"
        delegate.textViewDidChange(textView)
        XCTAssertEqual(received, "typed", "changetext should fire for multiline edits")
    }

    func testVInputFactoryMultilineFocusBlurEvents() {
        let factory = VInputFactory()
        let view = factory.createView()
        factory.updateProp(view: view, key: "multiline", value: true)

        var focused = false
        var blurred = false
        factory.addEventListener(view: view, event: "focus") { _ in focused = true }
        factory.addEventListener(view: view, event: "blur") { _ in blurred = true }

        guard let textView = inputContainer(view)?.textView else {
            return XCTFail("multiline input should contain a UITextView")
        }
        guard let delegate = textView.delegate as? InputDelegateProxy else {
            return XCTFail("UITextView delegate should be the InputDelegateProxy after addEventListener")
        }

        delegate.textViewDidBeginEditing(textView)
        XCTAssertTrue(focused, "focus should fire for multiline")

        delegate.textViewDidEndEditing(textView)
        XCTAssertTrue(blurred, "blur should fire for multiline")
    }

    // MARK: - VSwitchFactory Tests

    func testVSwitchFactoryCreatesUISwitch() {
        let factory = VSwitchFactory()
        let view = factory.createView()
        XCTAssertTrue(view is UISwitch, "VSwitchFactory should create a UISwitch")
    }

    func testVSwitchFactorySetsValue() {
        let factory = VSwitchFactory()
        let sw = factory.createView() as! UISwitch

        factory.updateProp(view: sw, key: "value", value: true)
        XCTAssertTrue(sw.isOn, "value=true should set UISwitch on")

        factory.updateProp(view: sw, key: "value", value: false)
        XCTAssertFalse(sw.isOn, "value=false should set UISwitch off")
    }

    func testVSwitchFactorySetsDisabled() {
        let factory = VSwitchFactory()
        let sw = factory.createView() as! UISwitch

        factory.updateProp(view: sw, key: "disabled", value: true)
        XCTAssertFalse(sw.isEnabled, "disabled=true should disable the switch")
    }

    func testVSwitchFactorySetsOnTintColor() {
        let factory = VSwitchFactory()
        let sw = factory.createView() as! UISwitch

        factory.updateProp(view: sw, key: "onTintColor", value: "#00ff00")
        XCTAssertNotNil(sw.onTintColor, "onTintColor should be set")
    }

    func testVSwitchFactorySetsThumbTintColor() {
        let factory = VSwitchFactory()
        let sw = factory.createView() as! UISwitch

        factory.updateProp(view: sw, key: "thumbTintColor", value: "#0000ff")
        XCTAssertNotNil(sw.thumbTintColor, "thumbTintColor should be set")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        sw.thumbTintColor?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(b, 1.0, accuracy: 0.01, "thumbTintColor should be blue")
    }

    func testVSwitchFactoryInvalidTintColorIsIgnored() {
        let factory = VSwitchFactory()
        let sw = factory.createView() as! UISwitch

        factory.updateProp(view: sw, key: "onTintColor", value: "#ff0000")
        factory.updateProp(view: sw, key: "onTintColor", value: "#nothex")

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        sw.onTintColor?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01, "invalid onTintColor should be ignored, keeping the previous red")
        XCTAssertEqual(g, 0.0, accuracy: 0.01)
    }

    func testVSwitchFactoryHandlesChangeEvent() {
        let factory = VSwitchFactory()
        let sw = factory.createView() as! UISwitch

        factory.addEventListener(view: sw, event: "change") { _ in }
        // The change handler is stored as an associated object
    }

    // MARK: - VImageFactory Tests

    func testVImageFactoryCreatesUIImageView() {
        let factory = VImageFactory()
        let view = factory.createView()
        XCTAssertTrue(view is UIImageView, "VImageFactory should create a UIImageView")
    }

    func testVImageFactoryDefaultContentMode() {
        let factory = VImageFactory()
        let imageView = factory.createView() as! UIImageView
        XCTAssertEqual(imageView.contentMode, .scaleAspectFill, "Default content mode should be .scaleAspectFill")
    }

    func testVImageFactoryClipsToBounds() {
        let factory = VImageFactory()
        let imageView = factory.createView() as! UIImageView
        XCTAssertTrue(imageView.clipsToBounds, "Image view should clip to bounds by default")
    }

    func testVImageFactorySetsResizeMode() {
        let factory = VImageFactory()
        let imageView = factory.createView() as! UIImageView

        factory.updateProp(view: imageView, key: "resizeMode", value: "contain")
        XCTAssertEqual(imageView.contentMode, .scaleAspectFit, "resizeMode 'contain' should set .scaleAspectFit")

        factory.updateProp(view: imageView, key: "resizeMode", value: "stretch")
        XCTAssertEqual(imageView.contentMode, .scaleToFill, "resizeMode 'stretch' should set .scaleToFill")

        factory.updateProp(view: imageView, key: "resizeMode", value: "center")
        XCTAssertEqual(imageView.contentMode, .center, "resizeMode 'center' should set .center")
    }

    func testVImageFactoryClearsImageOnNilSource() {
        let factory = VImageFactory()
        let imageView = factory.createView() as! UIImageView

        // Set a source with invalid data to test nil handling
        factory.updateProp(view: imageView, key: "source", value: nil)
        XCTAssertNil(imageView.image, "Nil source should clear the image")
    }

    func testVImageFactoryClearingSourceCancelsInFlightRequest() {
        let requestStarted = expectation(description: "image request started")
        let requestCancelled = expectation(description: "image request cancelled")
        let staleError = expectation(description: "cancelled request does not emit an error")
        staleError.isInverted = true
        VImageURLProtocolStub.onStart = { _ in requestStarted.fulfill() }
        VImageURLProtocolStub.onStop = { requestCancelled.fulfill() }

        let session = makeVImageTestSession()
        defer {
            VImageURLProtocolStub.reset()
            session.invalidateAndCancel()
        }
        let factory = VImageFactory(urlSession: session)
        let imageView = factory.createView() as! UIImageView
        imageView.image = UIImage()
        factory.addEventListener(view: imageView, event: "error") { _ in
            staleError.fulfill()
        }

        factory.updateProp(
            view: imageView,
            key: "source",
            value: ["uri": "https://example.invalid/old.png"]
        )
        wait(for: [requestStarted], timeout: 1)

        factory.updateProp(view: imageView, key: "source", value: nil)

        wait(for: [requestCancelled], timeout: 1)
        wait(for: [staleError], timeout: 0.1)
        XCTAssertNil(imageView.image)
    }

    func testVImageFactoryReplacingSourceCancelsPreviousRequest() {
        let firstRequestStarted = expectation(description: "first image request started")
        let secondRequestStarted = expectation(description: "second image request started")
        let firstRequestCancelled = expectation(description: "first image request cancelled")
        let lock = NSLock()
        var requestCount = 0
        VImageURLProtocolStub.onStart = { _ in
            lock.lock()
            requestCount += 1
            let currentRequest = requestCount
            lock.unlock()

            if currentRequest == 1 {
                firstRequestStarted.fulfill()
            } else if currentRequest == 2 {
                secondRequestStarted.fulfill()
            }
        }
        VImageURLProtocolStub.onStop = { firstRequestCancelled.fulfill() }

        let session = makeVImageTestSession()
        defer {
            VImageURLProtocolStub.reset()
            session.invalidateAndCancel()
        }
        let factory = VImageFactory(urlSession: session)
        let imageView = factory.createView() as! UIImageView

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
    }

    func testVImageFactoryDestroyViewCancelsInFlightRequest() {
        let requestStarted = expectation(description: "image request started")
        let requestCancelled = expectation(description: "image request cancelled")
        let staleError = expectation(description: "destroyed request does not emit an error")
        staleError.isInverted = true
        VImageURLProtocolStub.onStart = { _ in requestStarted.fulfill() }
        VImageURLProtocolStub.onStop = { requestCancelled.fulfill() }

        let session = makeVImageTestSession()
        defer {
            VImageURLProtocolStub.reset()
            session.invalidateAndCancel()
        }
        let factory = VImageFactory(urlSession: session)
        let imageView = factory.createView() as! UIImageView
        factory.addEventListener(view: imageView, event: "error") { _ in
            staleError.fulfill()
        }

        factory.updateProp(
            view: imageView,
            key: "source",
            value: ["uri": "https://example.invalid/destroyed.png"]
        )
        wait(for: [requestStarted], timeout: 1)

        factory.destroyView(view: imageView)

        wait(for: [requestCancelled], timeout: 1)
        wait(for: [staleError], timeout: 0.1)
    }

    // MARK: - VScrollViewFactory Tests

    func testVScrollViewFactoryCreatesUIScrollView() {
        let factory = VScrollViewFactory()
        let view = factory.createView()
        XCTAssertTrue(view is UIScrollView, "VScrollViewFactory should create a UIScrollView")
    }

    func testVScrollViewFactoryHasContentView() {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! UIScrollView

        let contentView = VScrollViewFactory.contentView(for: scrollView)
        XCTAssertNotNil(contentView, "VScrollView should have a content view")
    }

    func testVScrollViewFactoryDefaultProperties() {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! UIScrollView

        XCTAssertTrue(scrollView.showsVerticalScrollIndicator, "Should show vertical scroll indicator by default")
        XCTAssertFalse(scrollView.showsHorizontalScrollIndicator, "Should hide horizontal scroll indicator by default")
        XCTAssertTrue(scrollView.alwaysBounceVertical, "Should always bounce vertically by default")
        XCTAssertTrue(scrollView.clipsToBounds, "Should clip to bounds by default")
    }

    func testVScrollViewFactorySetsHorizontal() {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! UIScrollView

        factory.updateProp(view: scrollView, key: "horizontal", value: true)
        XCTAssertTrue(scrollView.alwaysBounceHorizontal, "horizontal=true should enable horizontal bouncing")
        XCTAssertFalse(scrollView.alwaysBounceVertical, "horizontal=true should disable vertical bouncing")
    }

    func testVScrollViewFactorySetsScrollEnabled() {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! UIScrollView

        factory.updateProp(view: scrollView, key: "scrollEnabled", value: false)
        XCTAssertFalse(scrollView.isScrollEnabled, "scrollEnabled=false should disable scrolling")
    }

    func testVScrollViewFactorySetsBounces() {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! UIScrollView

        factory.updateProp(view: scrollView, key: "bounces", value: false)
        XCTAssertFalse(scrollView.bounces, "bounces=false should disable bouncing")
    }

    func testVScrollViewFactorySetsPagingEnabled() {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! UIScrollView

        factory.updateProp(view: scrollView, key: "pagingEnabled", value: true)
        XCTAssertTrue(scrollView.isPagingEnabled, "pagingEnabled=true should enable paging")
    }

    func testVScrollViewFactoryVerticalContentSizeGrowsHeight() {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! UIScrollView
        scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 200)

        let contentView = VScrollViewFactory.contentView(for: scrollView)!
        let child = UIView()
        child.flex.width(100).height(500)
        contentView.flex.addItem(child)

        VScrollViewFactory.layoutContentView(for: scrollView)

        XCTAssertEqual(scrollView.contentSize.width, 100, accuracy: 0.5, "vertical scroll view's contentSize.width should match bounds width")
        XCTAssertEqual(scrollView.contentSize.height, 500, accuracy: 0.5, "vertical scroll view's contentSize.height should grow to fit a child taller than the scroll view's bounds")
    }

    /// Regression test for a bug where the "horizontal" prop only toggled
    /// bounce flags but `layoutContentView` always pinned the content view's
    /// width to the scroll view's bounds, so `contentSize.width` could never
    /// exceed the visible width and horizontal scrolling never engaged.
    func testVScrollViewFactoryHorizontalContentSizeGrowsWidth() {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! UIScrollView
        scrollView.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
        factory.updateProp(view: scrollView, key: "horizontal", value: true)

        let contentView = VScrollViewFactory.contentView(for: scrollView)!
        let child = UIView()
        child.flex.width(300).height(50)
        contentView.flex.addItem(child)

        VScrollViewFactory.layoutContentView(for: scrollView)

        XCTAssertEqual(scrollView.contentSize.width, 300, accuracy: 0.5, "horizontal scroll view's contentSize.width should grow to fit a child wider than the scroll view's bounds")
        XCTAssertEqual(scrollView.contentSize.height, 200, accuracy: 0.5, "horizontal scroll view's contentSize.height should match the scroll view's bounds height")
    }

    // MARK: - VListFactory Tests

    func testVListFactoryCreatesVListContainerView() {
        let factory = VListFactory()
        let view = factory.createView()
        XCTAssertTrue(view is VListContainerView, "VListFactory should create a VListContainerView")
    }

    func testVListContainerViewHasTableView() {
        let factory = VListFactory()
        let container = factory.createView() as! VListContainerView
        XCTAssertNotNil(container.tableView, "VListContainerView should have a tableView")
    }

    func testVListFactorySetsEstimatedItemHeight() {
        let factory = VListFactory()
        let container = factory.createView() as! VListContainerView

        factory.updateProp(view: container, key: "estimatedItemHeight", value: 80.0)
        XCTAssertEqual(container.estimatedItemHeight, 80.0, accuracy: 0.001, "estimatedItemHeight should be 80")
    }

    func testVListFactorySetsShowsScrollIndicator() {
        let factory = VListFactory()
        let container = factory.createView() as! VListContainerView

        factory.updateProp(view: container, key: "showsScrollIndicator", value: false)
        XCTAssertFalse(container.tableView.showsVerticalScrollIndicator, "Should hide scroll indicator")
    }

    func testVListFactorySetsBounces() {
        let factory = VListFactory()
        let container = factory.createView() as! VListContainerView

        factory.updateProp(view: container, key: "bounces", value: false)
        XCTAssertFalse(container.tableView.bounces, "Should disable bouncing")
    }

    func testVListFactoryDefaultItemViewsEmpty() {
        let factory = VListFactory()
        let container = factory.createView() as! VListContainerView
        XCTAssertTrue(container.itemViews.isEmpty, "itemViews should start empty")
    }

    func testVListContainerMeasuresRowHeightLazily() {
        let factory = VListFactory()
        let container = factory.createView() as! VListContainerView
        container.frame = CGRect(x: 0, y: 0, width: 320, height: 480)

        let item = UIView()
        item.flex.width(320).height(75)
        container.itemViews.append(item)

        // The item has not been laid out yet; measuredHeight runs Yoga on demand
        // at the container width and returns the computed height.
        let height = container.measuredHeight(forRow: 0)
        XCTAssertEqual(height, 75, accuracy: 0.5, "measuredHeight should compute the item height lazily")
        XCTAssertEqual(item.frame.size.width, 320, accuracy: 0.5, "measuredHeight should size the item to the container width")

        // Out-of-range rows fall back to the estimated height instead of crashing.
        XCTAssertEqual(container.measuredHeight(forRow: 5), container.estimatedItemHeight)
    }

    // MARK: - VSectionListFactory Tests

    func testVSectionListFactoryHonorsInsertBeforeOrder() {
        let factory = VSectionListFactory()
        let container = factory.createView() as! VSectionListContainerView
        let first = UIView()
        let second = UIView()
        let moved = UIView()

        factory.insertChild(first, into: container, before: nil)
        factory.insertChild(second, into: container, before: nil)
        factory.insertChild(moved, into: container, before: first)

        XCTAssertTrue(container.allChildren[0] === moved)
        XCTAssertTrue(container.allChildren[1] === first)
        XCTAssertTrue(container.allChildren[2] === second)
    }

    // MARK: - VSliderFactory Tests

    func testVSliderFactoryCreatesUISlider() {
        let factory = VSliderFactory()
        let view = factory.createView()
        XCTAssertTrue(view is UISlider, "VSliderFactory should create a UISlider")
    }

    func testVSliderFactoryDefaultRange() {
        let factory = VSliderFactory()
        let slider = factory.createView() as! UISlider
        XCTAssertEqual(slider.minimumValue, 0, "Default minimum should be 0")
        XCTAssertEqual(slider.maximumValue, 1, "Default maximum should be 1")
    }

    func testVSliderFactorySetsValue() {
        let factory = VSliderFactory()
        let slider = factory.createView() as! UISlider

        factory.updateProp(view: slider, key: "value", value: 0.5)
        XCTAssertEqual(slider.value, 0.5, accuracy: 0.001, "value prop should set slider value")
    }

    func testVSliderFactorySetsMinMax() {
        let factory = VSliderFactory()
        let slider = factory.createView() as! UISlider

        factory.updateProp(view: slider, key: "minimumValue", value: 10.0)
        XCTAssertEqual(slider.minimumValue, 10.0, accuracy: 0.001, "minimumValue should be set")

        factory.updateProp(view: slider, key: "maximumValue", value: 100.0)
        XCTAssertEqual(slider.maximumValue, 100.0, accuracy: 0.001, "maximumValue should be set")
    }

    func testVSliderFactoryHandlesChangeEvent() {
        let factory = VSliderFactory()
        let slider = factory.createView() as! UISlider

        factory.addEventListener(view: slider, event: "change") { _ in }
        // Verify the event was wired (target/action stored)
    }

    func testVSliderFactoryRemovesChangeEvent() {
        let factory = VSliderFactory()
        let slider = factory.createView() as! UISlider

        factory.addEventListener(view: slider, event: "change") { _ in }
        factory.removeEventListener(view: slider, event: "change")
        // Should not crash
    }

    // MARK: - VPickerFactory Tests

    func testVPickerFactoryUsesThePublicDateTimeModes() {
        let factory = VPickerFactory()
        let picker = factory.createView() as! UIDatePicker

        factory.updateProp(view: picker, key: "mode", value: "time")
        XCTAssertEqual(picker.datePickerMode, .time)

        factory.updateProp(view: picker, key: "mode", value: "datetime")
        XCTAssertEqual(picker.datePickerMode, .dateAndTime)

        factory.updateProp(view: picker, key: "mode", value: nil)
        XCTAssertEqual(picker.datePickerMode, .date)
    }

    func testVPickerFactoryClearsDateBoundsAndNormalizesMinuteIntervals() {
        let factory = VPickerFactory()
        let picker = factory.createView() as! UIDatePicker

        factory.updateProp(view: picker, key: "minimumDate", value: 1_725_043_755_000.0)
        XCTAssertNotNil(picker.minimumDate)
        factory.updateProp(view: picker, key: "minimumDate", value: nil)
        XCTAssertNil(picker.minimumDate)

        factory.updateProp(view: picker, key: "minuteInterval", value: 7)
        XCTAssertEqual(picker.minuteInterval, 1)
    }

    // MARK: - VModalFactory Tests

    func testVModalFactoryCreatesPlaceholderView() {
        let factory = VModalFactory()
        let view = factory.createView()
        XCTAssertNotNil(view, "VModalFactory should create a view")
        XCTAssertTrue(view.isHidden, "Modal placeholder should be hidden")
    }

    func testVModalFactoryPlaceholderIsZeroSize() {
        let factory = VModalFactory()
        let view = factory.createView()
        // The placeholder has flex width(0) height(0) — verify it's created
        XCTAssertNotNil(view, "Placeholder should exist")
    }

    func testVModalFactoryAppliesStyleToVisibleOverlay() {
        let factory = VModalFactory()
        let placeholder = factory.createView()

        factory.updateProp(view: placeholder, key: "backgroundColor", value: "#ff0000")
        let child = UIView()
        factory.insertChild(child, into: placeholder, before: nil)

        XCTAssertEqual(child.superview?.backgroundColor, UIColor.red)
        XCTAssertNil(placeholder.backgroundColor)
    }

    // MARK: - VActivityIndicatorFactory Tests

    func testVActivityIndicatorFactoryCreatesUIActivityIndicatorView() {
        let factory = VActivityIndicatorFactory()
        let view = factory.createView()
        XCTAssertTrue(view is UIActivityIndicatorView,
                      "VActivityIndicatorFactory should create a UIActivityIndicatorView")
    }

    func testVActivityIndicatorFactoryStartsAnimating() {
        let factory = VActivityIndicatorFactory()
        let indicator = factory.createView() as! UIActivityIndicatorView
        XCTAssertTrue(indicator.isAnimating, "Activity indicator should start animating by default")
    }

    func testVActivityIndicatorFactoryHidesWhenStopped() {
        let factory = VActivityIndicatorFactory()
        let indicator = factory.createView() as! UIActivityIndicatorView
        XCTAssertTrue(indicator.hidesWhenStopped, "Should hide when stopped by default")
    }

    func testVActivityIndicatorFactoryStopsAnimating() {
        let factory = VActivityIndicatorFactory()
        let indicator = factory.createView() as! UIActivityIndicatorView

        factory.updateProp(view: indicator, key: "animating", value: false)
        XCTAssertFalse(indicator.isAnimating, "animating=false should stop animation")
    }

    func testVActivityIndicatorFactorySetsColor() {
        let factory = VActivityIndicatorFactory()
        let indicator = factory.createView() as! UIActivityIndicatorView

        factory.updateProp(view: indicator, key: "color", value: "#ff0000")
        XCTAssertNotNil(indicator.color, "color prop should set indicator color")
    }

    func testVActivityIndicatorFactorySetsSize() {
        let factory = VActivityIndicatorFactory()
        let indicator = factory.createView() as! UIActivityIndicatorView

        factory.updateProp(view: indicator, key: "size", value: "large")
        XCTAssertEqual(indicator.style, .large, "size 'large' should set .large style")
    }

    func testVActivityIndicatorFactorySetsHidesWhenStoppedProp() {
        let factory = VActivityIndicatorFactory()
        let indicator = factory.createView() as! UIActivityIndicatorView

        factory.updateProp(view: indicator, key: "hidesWhenStopped", value: false)
        XCTAssertFalse(indicator.hidesWhenStopped, "hidesWhenStopped=false should be set")
    }
}
#endif
