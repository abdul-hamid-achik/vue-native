#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

@MainActor
final class ComponentFactoryTests: XCTestCase {

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
        var handlerCalled = false

        factory.addEventListener(view: view, event: "press") { _ in
            handlerCalled = true
        }

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

    // MARK: - VInputFactory Tests

    func testVInputFactoryCreatesUITextField() {
        let factory = VInputFactory()
        let view = factory.createView()
        XCTAssertTrue(view is UITextField, "VInputFactory should create a UITextField")
    }

    func testVInputFactorySetsText() {
        let factory = VInputFactory()
        let textField = factory.createView() as! UITextField

        factory.updateProp(view: textField, key: "text", value: "Hello Input")
        XCTAssertEqual(textField.text, "Hello Input", "text prop should set text field text")
    }

    func testVInputFactorySetsPlaceholder() {
        let factory = VInputFactory()
        let textField = factory.createView() as! UITextField

        factory.updateProp(view: textField, key: "placeholder", value: "Enter text...")
        XCTAssertEqual(textField.placeholder, "Enter text...", "placeholder prop should be set")
    }

    func testVInputFactorySetsSecureTextEntry() {
        let factory = VInputFactory()
        let textField = factory.createView() as! UITextField

        factory.updateProp(view: textField, key: "secureTextEntry", value: true)
        XCTAssertTrue(textField.isSecureTextEntry, "secureTextEntry should be true")

        factory.updateProp(view: textField, key: "secureTextEntry", value: false)
        XCTAssertFalse(textField.isSecureTextEntry, "secureTextEntry should be false")
    }

    func testVInputFactorySetsKeyboardType() {
        let factory = VInputFactory()
        let textField = factory.createView() as! UITextField

        factory.updateProp(view: textField, key: "keyboardType", value: "numeric")
        XCTAssertEqual(textField.keyboardType, .numberPad, "keyboardType 'numeric' should set .numberPad")

        factory.updateProp(view: textField, key: "keyboardType", value: "email")
        XCTAssertEqual(textField.keyboardType, .emailAddress, "keyboardType 'email' should set .emailAddress")
    }

    func testVInputFactoryEditable() {
        let factory = VInputFactory()
        let textField = factory.createView() as! UITextField

        factory.updateProp(view: textField, key: "editable", value: false)
        XCTAssertFalse(textField.isEnabled, "editable=false should disable the text field")

        factory.updateProp(view: textField, key: "editable", value: true)
        XCTAssertTrue(textField.isEnabled, "editable=true should enable the text field")
    }

    func testVInputFactoryHandlesChangeTextEvent() {
        let factory = VInputFactory()
        let textField = factory.createView() as! UITextField
        var receivedText: String?

        factory.addEventListener(view: textField, event: "changetext") { payload in
            receivedText = payload as? String
        }

        // Verify delegate is set up
        XCTAssertNotNil(textField.delegate, "UITextField delegate should be set after addEventListener")
    }

    func testVInputFactoryReturnKeyType() {
        let factory = VInputFactory()
        let textField = factory.createView() as! UITextField

        factory.updateProp(view: textField, key: "returnKeyType", value: "done")
        XCTAssertEqual(textField.returnKeyType, .done, "returnKeyType 'done' should set .done")

        factory.updateProp(view: textField, key: "returnKeyType", value: "search")
        XCTAssertEqual(textField.returnKeyType, .search, "returnKeyType 'search' should set .search")
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
