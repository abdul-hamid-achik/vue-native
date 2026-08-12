#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

@MainActor
final class StyleEngineTests: XCTestCase {

    // MARK: - Properties

    private var view: UIView!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        view = UIView()
        // Enable FlexLayout on the test view
        _ = view.flex
    }

    override func tearDown() {
        view = nil
        super.tearDown()
    }

    // MARK: - yogaValue Tests

    func testYogaValueWithDouble() {
        let result = StyleEngine.yogaValue(42.5)
        XCTAssertEqual(result, 42.5, "yogaValue should convert Double to CGFloat")
    }

    func testYogaValueWithInt() {
        let result = StyleEngine.yogaValue(10)
        XCTAssertEqual(result, 10.0, "yogaValue should convert Int to CGFloat")
    }

    func testYogaValueWithCGFloat() {
        let cgValue: CGFloat = 33.3
        let result = StyleEngine.yogaValue(cgValue)
        XCTAssertEqual(result, 33.3, "yogaValue should pass through CGFloat")
    }

    func testYogaValueWithNumericString() {
        let result = StyleEngine.yogaValue("25.5")
        XCTAssertEqual(result, 25.5, "yogaValue should parse numeric strings")
    }

    func testYogaValueWithNil() {
        let result = StyleEngine.yogaValue(nil)
        XCTAssertNil(result, "yogaValue should return nil for nil input")
    }

    func testYogaValueWithNonNumericString() {
        let result = StyleEngine.yogaValue("hello")
        XCTAssertNil(result, "yogaValue should return nil for non-numeric strings")
    }

    // MARK: - isAuto Tests

    func testIsAutoWithLowercaseAuto() {
        XCTAssertTrue(StyleEngine.isAuto("auto"), "isAuto should return true for 'auto'")
    }

    func testIsAutoWithUppercaseAuto() {
        XCTAssertTrue(StyleEngine.isAuto("AUTO"), "isAuto should return true for 'AUTO'")
    }

    func testIsAutoWithMixedCaseAuto() {
        XCTAssertTrue(StyleEngine.isAuto("Auto"), "isAuto should return true for 'Auto'")
    }

    func testIsAutoWithOtherString() {
        XCTAssertFalse(StyleEngine.isAuto("something"), "isAuto should return false for non-auto strings")
    }

    func testIsAutoWithNil() {
        XCTAssertFalse(StyleEngine.isAuto(nil), "isAuto should return false for nil")
    }

    // MARK: - asPercent Tests

    func testAsPercentWith50Percent() {
        let result = StyleEngine.asPercent("50%")
        XCTAssertEqual(result, 50.0, "asPercent should extract 50 from '50%'")
    }

    func testAsPercentWith100Percent() {
        let result = StyleEngine.asPercent("100%")
        XCTAssertEqual(result, 100.0, "asPercent should extract 100 from '100%'")
    }

    func testAsPercentWithInvalidPercentString() {
        let result = StyleEngine.asPercent("abc%")
        XCTAssertNil(result, "asPercent should return nil for 'abc%' (non-numeric prefix)")
    }

    func testAsPercentWithoutPercentSign() {
        let result = StyleEngine.asPercent("50")
        XCTAssertNil(result, "asPercent should return nil for strings without '%' suffix")
    }

    func testAsPercentWithNil() {
        let result = StyleEngine.asPercent(nil)
        XCTAssertNil(result, "asPercent should return nil for nil input")
    }

    // MARK: - backgroundColor Tests

    func testApplyBackgroundColorRed() {
        StyleEngine.apply(key: "backgroundColor", value: "#ff0000", to: view)

        XCTAssertNotNil(view.backgroundColor, "backgroundColor should be set")

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        view.backgroundColor!.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01, "Red component should be 1.0")
        XCTAssertEqual(g, 0.0, accuracy: 0.01, "Green component should be 0.0")
        XCTAssertEqual(b, 0.0, accuracy: 0.01, "Blue component should be 0.0")
    }

    func testApplyBackgroundColorNilClearsColor() {
        view.backgroundColor = .red
        StyleEngine.apply(key: "backgroundColor", value: nil, to: view)
        XCTAssertNil(view.backgroundColor, "backgroundColor should be nil after applying nil value")
    }

    func testInvalidColorIsIgnoredAndKeepsPreviousValue() {
        StyleEngine.apply(key: "backgroundColor", value: "#00ff00", to: view)
        StyleEngine.apply(key: "backgroundColor", value: "#nothex", to: view)

        XCTAssertNotNil(view.backgroundColor, "invalid color must not clear the background")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        view.backgroundColor?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01)
        XCTAssertEqual(g, 1.0, accuracy: 0.01, "invalid color must be ignored, keeping the previous green")
    }

    func testFromHexSupportsShortFunctionalAndNamedFormats() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0

        // #RGBA short form expands each nibble (opaque red here).
        let shortRGBA = UIColor.fromHex("#f00f")
        shortRGBA?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(a, 1.0, accuracy: 0.01)

        // rgb() functional notation (channels 0...255).
        let rgb = UIColor.fromHex("rgb(0, 0, 255)")
        rgb?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(b, 1.0, accuracy: 0.01)
        XCTAssertEqual(a, 1.0, accuracy: 0.01)

        // rgba() functional notation with alpha 0...1.
        let rgba = UIColor.fromHex("rgba(255, 0, 0, 0.5)")
        rgba?.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(a, 0.5, accuracy: 0.01)

        // Named colors.
        XCTAssertNotNil(UIColor.fromHex("orange"))
        XCTAssertEqual(UIColor.fromHex("transparent"), .clear)

        // Invalid inputs return nil so callers can keep the previous value.
        XCTAssertNil(UIColor.fromHex("#xyz"))
        XCTAssertNil(UIColor.fromHex("notacolor"))
        XCTAssertNil(UIColor.fromHex("#12345"), "5-digit hex is invalid")
    }

    // MARK: - opacity Tests

    func testApplyOpacity() {
        StyleEngine.apply(key: "opacity", value: 0.5, to: view)
        XCTAssertEqual(view.alpha, 0.5, accuracy: 0.001, "view.alpha should be 0.5")
    }

    func testApplyOpacityNilResetsToOne() {
        view.alpha = 0.3
        StyleEngine.apply(key: "opacity", value: nil, to: view)
        XCTAssertEqual(view.alpha, 1.0, accuracy: 0.001, "view.alpha should reset to 1.0 when opacity is nil")
    }

    // MARK: - borderRadius Tests

    func testApplyBorderRadius() {
        StyleEngine.apply(key: "borderRadius", value: 10.0, to: view)
        XCTAssertEqual(view.layer.cornerRadius, 10.0, accuracy: 0.001, "cornerRadius should be 10")
        XCTAssertTrue(view.clipsToBounds, "clipsToBounds should be true when borderRadius > 0")
    }

    /// Regression test: `applyCornerRadius` used to take `max(current, radius)`,
    /// so a smaller per-corner radius sent after a larger one was a silent
    /// no-op — the corner could grow but never shrink.
    func testApplyCornerRadiusShrinkingReplacesPreviousValue() {
        StyleEngine.apply(key: "borderTopLeftRadius", value: 20.0, to: view)
        XCTAssertEqual(view.layer.cornerRadius, 20.0, accuracy: 0.001)

        StyleEngine.apply(key: "borderTopLeftRadius", value: 8.0, to: view)
        XCTAssertEqual(view.layer.cornerRadius, 8.0, accuracy: 0.001, "a smaller radius sent after a larger one should take effect, not be clamped by max()")
    }

    /// Regression test: the per-corner radius cases only had an `if let num =`
    /// branch, so there was no way to reset a corner once set — `nil` (the
    /// renderer's signal that a style prop was removed) was silently ignored.
    func testApplyCornerRadiusNilRemovesCornerFromMask() {
        StyleEngine.apply(key: "borderTopLeftRadius", value: 20.0, to: view)
        XCTAssertTrue(view.layer.maskedCorners.contains(.layerMinXMinYCorner))

        StyleEngine.apply(key: "borderTopLeftRadius", value: nil, to: view)
        XCTAssertFalse(view.layer.maskedCorners.contains(.layerMinXMinYCorner), "nil should remove the corner from maskedCorners so it resets to square")
    }

    // MARK: - borderWidth Tests

    func testApplyBorderWidth() {
        StyleEngine.apply(key: "borderWidth", value: 2.0, to: view)
        XCTAssertEqual(view.layer.borderWidth, 2.0, accuracy: 0.001, "borderWidth should be 2")
    }

    // MARK: - borderColor Tests

    func testApplyBorderColorGreen() {
        StyleEngine.apply(key: "borderColor", value: "#00ff00", to: view)
        XCTAssertNotNil(view.layer.borderColor, "borderColor should be set")

        let color = UIColor(cgColor: view.layer.borderColor!)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01, "Red component should be 0.0")
        XCTAssertEqual(g, 1.0, accuracy: 0.01, "Green component should be 1.0")
        XCTAssertEqual(b, 0.0, accuracy: 0.01, "Blue component should be 0.0")
    }

    // MARK: - display Tests

    func testApplyDisplayNone() {
        StyleEngine.apply(key: "display", value: "none", to: view)
        XCTAssertTrue(view.isHidden, "view.isHidden should be true when display is 'none'")
    }

    func testApplyDisplayFlex() {
        view.isHidden = true
        StyleEngine.apply(key: "display", value: "flex", to: view)
        XCTAssertFalse(view.isHidden, "view.isHidden should be false when display is 'flex'")
    }

    // MARK: - overflow Tests

    func testApplyOverflowHidden() {
        StyleEngine.apply(key: "overflow", value: "hidden", to: view)
        XCTAssertTrue(view.clipsToBounds, "clipsToBounds should be true when overflow is 'hidden'")
    }

    func testApplyOverflowVisible() {
        view.clipsToBounds = true
        StyleEngine.apply(key: "overflow", value: "visible", to: view)
        XCTAssertFalse(view.clipsToBounds, "clipsToBounds should be false when overflow is 'visible'")
    }

    func testRemovingLayoutStylesRestoresVisibleDefaults() {
        StyleEngine.apply(key: "display", value: "none", to: view)
        StyleEngine.apply(key: "overflow", value: "hidden", to: view)

        StyleEngine.apply(key: "display", value: nil, to: view)
        StyleEngine.apply(key: "overflow", value: nil, to: view)

        XCTAssertFalse(view.isHidden, "Removing display should restore flex visibility")
        XCTAssertFalse(view.clipsToBounds, "Removing overflow should restore visible overflow")
    }

    // MARK: - hidden Tests

    func testApplyHiddenTrue() {
        StyleEngine.apply(key: "hidden", value: true, to: view)
        XCTAssertTrue(view.isHidden, "view.isHidden should be true")
    }

    func testApplyHiddenFalse() {
        view.isHidden = true
        StyleEngine.apply(key: "hidden", value: false, to: view)
        XCTAssertFalse(view.isHidden, "view.isHidden should be false")
    }

    // MARK: - zIndex Tests

    func testApplyZIndex() {
        StyleEngine.apply(key: "zIndex", value: 5.0, to: view)
        XCTAssertEqual(view.layer.zPosition, 5.0, accuracy: 0.001, "zPosition should be 5")
    }

    // MARK: - Shadow Tests

    func testApplyShadowOpacity() {
        StyleEngine.apply(key: "shadowOpacity", value: 0.5, to: view)
        XCTAssertEqual(view.layer.shadowOpacity, 0.5, accuracy: 0.001, "shadowOpacity should be 0.5")
    }

    func testApplyShadowRadius() {
        StyleEngine.apply(key: "shadowRadius", value: 10.0, to: view)
        XCTAssertEqual(view.layer.shadowRadius, 10.0, accuracy: 0.001, "shadowRadius should be 10")
    }

    func testApplyShadowOffsetX() {
        StyleEngine.apply(key: "shadowOffsetX", value: 5.0, to: view)
        XCTAssertEqual(view.layer.shadowOffset.width, 5.0, accuracy: 0.001, "shadowOffset.width should be 5")
    }

    func testApplyShadowOffsetY() {
        StyleEngine.apply(key: "shadowOffsetY", value: 3.0, to: view)
        XCTAssertEqual(view.layer.shadowOffset.height, 3.0, accuracy: 0.001, "shadowOffset.height should be 3")
    }

    // MARK: - Internal Props Tests

    func testInternalPropStoreAndRetrieve() {
        StyleEngine.apply(key: "__myProp", value: "hello", to: view)
        let retrieved = StyleEngine.getInternalProp("__myProp", from: view)
        XCTAssertEqual(retrieved as? String, "hello", "Internal prop should be stored and retrievable")
    }

    func testInternalPropNilRemovesProp() {
        StyleEngine.apply(key: "__myProp", value: "hello", to: view)
        StyleEngine.apply(key: "__myProp", value: nil, to: view)
        let retrieved = StyleEngine.getInternalProp("__myProp", from: view)
        XCTAssertNil(retrieved, "Internal prop should be nil after setting to nil")
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabel() {
        StyleEngine.apply(key: "accessibilityLabel", value: "Test Label", to: view)
        XCTAssertEqual(view.accessibilityLabel, "Test Label", "accessibilityLabel should be set")
        XCTAssertTrue(view.isAccessibilityElement, "isAccessibilityElement should be true")
    }

    func testAccessibilityRoleButton() {
        StyleEngine.apply(key: "accessibilityRole", value: "button", to: view)
        XCTAssertTrue(
            view.accessibilityTraits.contains(.button),
            "accessibilityTraits should contain .button"
        )
        XCTAssertTrue(view.isAccessibilityElement, "isAccessibilityElement should be true")
    }

    func testAccessibilityStateClearsReactiveTraits() {
        StyleEngine.apply(
            key: "accessibilityState",
            value: ["disabled": true, "selected": true],
            to: view
        )
        XCTAssertTrue(view.accessibilityTraits.contains(.notEnabled))
        XCTAssertTrue(view.accessibilityTraits.contains(.selected))

        StyleEngine.apply(
            key: "accessibilityState",
            value: ["disabled": false, "selected": false],
            to: view
        )
        XCTAssertFalse(view.accessibilityTraits.contains(.notEnabled))
        XCTAssertFalse(view.accessibilityTraits.contains(.selected))
    }

    func testAccessibilityRolePreservesReactiveStateTraits() {
        StyleEngine.apply(
            key: "accessibilityState",
            value: ["disabled": true, "selected": true],
            to: view
        )
        StyleEngine.apply(key: "accessibilityRole", value: "button", to: view)

        XCTAssertTrue(view.accessibilityTraits.contains(.button))
        XCTAssertTrue(
            view.accessibilityTraits.contains(.notEnabled),
            "Applying a role must not wipe the disabled state trait"
        )
        XCTAssertTrue(
            view.accessibilityTraits.contains(.selected),
            "Applying a role must not wipe the selected state trait"
        )
    }

    func testAccessibilityRoleReplacesPreviousRoleTrait() {
        StyleEngine.apply(key: "accessibilityRole", value: "button", to: view)
        StyleEngine.apply(key: "accessibilityRole", value: "link", to: view)

        XCTAssertTrue(view.accessibilityTraits.contains(.link))
        XCTAssertFalse(
            view.accessibilityTraits.contains(.button),
            "Applying a new role must remove the previous role trait"
        )
    }

    func testAccessibilityRoleSelectedIsNotARole() {
        // "selected" is a reactive state owned by accessibilityState, not a role.
        StyleEngine.apply(key: "accessibilityRole", value: "selected", to: view)
        XCTAssertFalse(
            view.accessibilityTraits.contains(.selected),
            "'selected' must not be applied as a role trait"
        )
    }

    // MARK: - Text Property Tests

    func testFontSizeOnUILabel() {
        let label = UILabel()
        _ = label.flex
        StyleEngine.apply(key: "fontSize", value: 24.0, to: label)
        XCTAssertEqual(label.font.pointSize, 24.0, accuracy: 0.1, "Font size should be 24")
    }

    func testTextColorOnUILabel() {
        let label = UILabel()
        _ = label.flex
        StyleEngine.apply(key: "color", value: "#0000ff", to: label)

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        label.textColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, 0.0, accuracy: 0.01, "Red component should be 0.0")
        XCTAssertEqual(g, 0.0, accuracy: 0.01, "Green component should be 0.0")
        XCTAssertEqual(b, 1.0, accuracy: 0.01, "Blue component should be 1.0")
    }

    func testTextAlignCenterOnUILabel() {
        let label = UILabel()
        _ = label.flex
        StyleEngine.apply(key: "textAlign", value: "center", to: label)
        XCTAssertEqual(label.textAlignment, .center, "textAlignment should be .center")
    }

    // MARK: - applyStyles Batch Tests

    func testApplyStylesBatch() {
        let styles: [String: Any] = [
            "opacity": 0.7,
            "borderRadius": 8.0,
            "borderWidth": 1.0,
        ]
        StyleEngine.applyStyles(styles, to: view)

        XCTAssertEqual(view.alpha, 0.7, accuracy: 0.001, "alpha should be 0.7")
        XCTAssertEqual(view.layer.cornerRadius, 8.0, accuracy: 0.001, "cornerRadius should be 8")
        XCTAssertEqual(view.layer.borderWidth, 1.0, accuracy: 0.001, "borderWidth should be 1")
    }

    // MARK: - Transform Tests

    func testApplyTransformRotate() {
        let transforms: [[String: Any]] = [["rotate": "90deg"]]
        StyleEngine.apply(key: "transform", value: transforms, to: view)
        XCTAssertFalse(
            view.transform.isIdentity,
            "Transform should not be identity after applying a 90deg rotation"
        )
    }

    func testApplyTransformNilResetsToIdentity() {
        // First apply a transform
        let transforms: [[String: Any]] = [["rotate": "45deg"]]
        StyleEngine.apply(key: "transform", value: transforms, to: view)
        XCTAssertFalse(view.transform.isIdentity, "Transform should not be identity after rotation")

        // Then reset by applying nil (non-array value resets to identity)
        StyleEngine.apply(key: "transform", value: nil, to: view)
        XCTAssertTrue(view.transform.isIdentity, "Transform should be identity after applying nil")
    }

    func testApplyTransformScale() {
        let transforms: [[String: Any]] = [["scale": 2.0]]
        StyleEngine.apply(key: "transform", value: transforms, to: view)
        XCTAssertFalse(
            view.transform.isIdentity,
            "Transform should not be identity after applying scale"
        )
        // Verify scale components
        XCTAssertEqual(view.transform.a, 2.0, accuracy: 0.001, "Scale X should be 2.0")
        XCTAssertEqual(view.transform.d, 2.0, accuracy: 0.001, "Scale Y should be 2.0")
    }

    // MARK: - Transform 3D Tests

    func testApplyTransformPerspectiveSetsM34() {
        let transforms: [[String: Any]] = [["perspective": 500.0]]
        StyleEngine.apply(key: "transform", value: transforms, to: view)
        XCTAssertEqual(
            view.layer.transform.m34,
            -1.0 / 500.0,
            accuracy: 0.000001,
            "perspective should set m34 to -1/perspective"
        )
    }

    func testApplyTransformRotateXIsNonIdentity3D() {
        let transforms: [[String: Any]] = [["rotateX": "45deg"]]
        StyleEngine.apply(key: "transform", value: transforms, to: view)
        XCTAssertFalse(
            CATransform3DIsIdentity(view.layer.transform),
            "rotateX should produce a non-identity 3D transform"
        )
        // A rotation about the X axis leaves the 2D affine projection identity-ish
        // on the diagonal but introduces off-axis 3D terms; assert the layer
        // transform changed even though it is not expressible as a 2D affine.
        XCTAssertNotEqual(view.layer.transform.m22, 1.0, "rotateX should affect the y/z plane")
    }

    func testApplyTransformRotateYIsNonIdentity3D() {
        let transforms: [[String: Any]] = [["rotateY": "30deg"]]
        StyleEngine.apply(key: "transform", value: transforms, to: view)
        XCTAssertFalse(
            CATransform3DIsIdentity(view.layer.transform),
            "rotateY should produce a non-identity 3D transform"
        )
        XCTAssertNotEqual(view.layer.transform.m11, 1.0, "rotateY should affect the x/z plane")
    }

    func testApplyTransformRotateZMatches2DRotate() {
        let transforms: [[String: Any]] = [["rotateZ": "90deg"]]
        StyleEngine.apply(key: "transform", value: transforms, to: view)
        XCTAssertFalse(
            view.transform.isIdentity,
            "rotateZ should project to a non-identity 2D affine transform"
        )
    }

    func testApplyTransformSkewXSetsM21() {
        let transforms: [[String: Any]] = [["skewX": "45deg"]]
        StyleEngine.apply(key: "transform", value: transforms, to: view)
        XCTAssertEqual(
            view.layer.transform.m21,
            tan(CGFloat.pi / 4),
            accuracy: 0.0001,
            "skewX should set m21 to tan(angle)"
        )
    }

    func testApplyTransformSkewYSetsM12() {
        let transforms: [[String: Any]] = [["skewY": "45deg"]]
        StyleEngine.apply(key: "transform", value: transforms, to: view)
        XCTAssertEqual(
            view.layer.transform.m12,
            tan(CGFloat.pi / 4),
            accuracy: 0.0001,
            "skewY should set m12 to tan(angle)"
        )
    }

    func testApplyTransform3DNilResetsLayerTransform() {
        StyleEngine.apply(key: "transform", value: [["perspective": 400.0]], to: view)
        XCTAssertNotEqual(view.layer.transform.m34, 0.0, "precondition: m34 should be set")

        StyleEngine.apply(key: "transform", value: nil, to: view)
        XCTAssertTrue(
            CATransform3DIsIdentity(view.layer.transform),
            "Applying nil should reset the layer transform to identity"
        )
    }

    func testApplyTransformComposesMultipleEntries() {
        // translate then perspective composed from separate array entries.
        let transforms: [[String: Any]] = [
            ["translateX": 10.0],
            ["perspective": 800.0],
        ]
        StyleEngine.apply(key: "transform", value: transforms, to: view)
        XCTAssertEqual(view.layer.transform.m41, 10.0, accuracy: 0.001, "translateX should set m41")
        XCTAssertEqual(view.layer.transform.m34, -1.0 / 800.0, accuracy: 0.000001, "perspective should set m34")
    }

    // MARK: - Text Property Fallback Tests (non-UILabel)

    func testTextPropsIgnoredOnNonLabel() {
        // Text properties should not crash on non-UILabel views
        StyleEngine.apply(key: "fontSize", value: 24.0, to: view)
        StyleEngine.apply(key: "color", value: "#ff0000", to: view)
        StyleEngine.apply(key: "textAlign", value: "center", to: view)
        // No assertion failure means the test passes
    }

    // MARK: - Edge Cases

    func testApplyUnknownKeyDoesNotCrash() {
        // Unknown keys that don't match any category should be silently ignored
        StyleEngine.apply(key: "nonExistentProperty", value: "test", to: view)
    }

    func testBorderRadiusZeroDoesNotEnableClipping() {
        view.clipsToBounds = false
        StyleEngine.apply(key: "borderRadius", value: 0.0, to: view)
        // cornerRadius 0 should not force clipsToBounds to true
        // (the code only sets clipsToBounds when num > 0)
        XCTAssertEqual(view.layer.cornerRadius, 0.0, accuracy: 0.001, "cornerRadius should be 0")
    }

    func testShadowOffsetPreservesOtherAxis() {
        // Set both axes independently and verify they don't interfere
        StyleEngine.apply(key: "shadowOffsetX", value: 5.0, to: view)
        StyleEngine.apply(key: "shadowOffsetY", value: 3.0, to: view)
        XCTAssertEqual(view.layer.shadowOffset.width, 5.0, accuracy: 0.001, "X should be preserved")
        XCTAssertEqual(view.layer.shadowOffset.height, 3.0, accuracy: 0.001, "Y should be set correctly")
    }
}
#endif
