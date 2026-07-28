import XCTest
@testable import VueNativeMacOS

/// StyleEngine tests for the macOS target: color parsing (all supported formats
/// + invalid handling), layout prop routing, and accessibility mapping.
@MainActor
final class StyleEngineTests: XCTestCase {

    // MARK: - Color parsing helpers

    private func rgba(_ color: NSColor?) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        guard let color = color?.usingColorSpace(.sRGB) else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    // MARK: - Color: hex formats

    func testColorHex8IsRRGGBBAA() {
        // 8 digits = alpha LAST. #FF000080 = opaque-ish red (alpha 0x80).
        guard let c = rgba(NSColor.fromHex("#FF000080")) else {
            return XCTFail("expected #FF000080 to parse")
        }
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0.0, accuracy: 0.01)
        XCTAssertEqual(c.a, CGFloat(0x80) / 255.0, accuracy: 0.01)
    }

    func testColorHex6IsOpaque() {
        guard let c = rgba(NSColor.fromHex("#00FF00")) else {
            return XCTFail("expected #00FF00 to parse")
        }
        XCTAssertEqual(c.g, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.a, 1.0, accuracy: 0.01)
    }

    func testColorHex3Expands() {
        // #F00 -> #FF0000
        guard let c = rgba(NSColor.fromHex("#F00")) else {
            return XCTFail("expected #F00 to parse")
        }
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.g, 0.0, accuracy: 0.01)
        XCTAssertEqual(c.b, 0.0, accuracy: 0.01)
        XCTAssertEqual(c.a, 1.0, accuracy: 0.01)
    }

    func testColorHex4IsRGBA() {
        // #F008 -> red with alpha 8/15
        guard let c = rgba(NSColor.fromHex("#F008")) else {
            return XCTFail("expected #F008 to parse")
        }
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.a, 8.0 / 15.0, accuracy: 0.01)
    }

    // MARK: - Color: functional notation

    func testColorRgbFunction() {
        guard let c = rgba(NSColor.fromHex("rgb(0, 0, 255)")) else {
            return XCTFail("expected rgb() to parse")
        }
        XCTAssertEqual(c.b, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.a, 1.0, accuracy: 0.01)
    }

    func testColorRgbaFunctionAlphaZeroOne() {
        guard let c = rgba(NSColor.fromHex("rgba(255, 0, 0, 0.25)")) else {
            return XCTFail("expected rgba() to parse")
        }
        XCTAssertEqual(c.r, 1.0, accuracy: 0.01)
        XCTAssertEqual(c.a, 0.25, accuracy: 0.01)
    }

    // MARK: - Color: named

    func testColorNamedColors() {
        let names = [
            "transparent", "white", "black", "red", "blue", "green",
            "gray", "grey", "orange", "yellow", "purple", "cyan",
            "magenta", "brown",
        ]
        for name in names {
            XCTAssertNotNil(NSColor.fromHex(name), "named color '\(name)' should parse")
        }
        // grey maps to the same color as gray
        XCTAssertEqual(NSColor.fromHex("grey"), NSColor.fromHex("gray"))
        XCTAssertEqual(NSColor.fromHex("transparent"), .clear)
    }

    // MARK: - Color: invalid

    func testColorInvalidReturnsNil() {
        XCTAssertNil(NSColor.fromHex("notacolor"))
        XCTAssertNil(NSColor.fromHex("#GGGGGG"))
        XCTAssertNil(NSColor.fromHex("#12345"))   // 5 digits: unsupported
        XCTAssertNil(NSColor.fromHex("rgb(1,2)")) // wrong arity
    }

    func testInvalidBackgroundColorIsIgnored() {
        let view = FlippedView()
        view.wantsLayer = true

        StyleEngine.apply(key: "backgroundColor", value: "#00FF00", to: view)
        let green = view.layer?.backgroundColor
        XCTAssertNotNil(green)

        // An invalid color must NOT overwrite the existing value.
        StyleEngine.apply(key: "backgroundColor", value: "bogus", to: view)
        XCTAssertEqual(view.layer?.backgroundColor, green)
    }

    func testInvalidTextColorIsIgnored() {
        let label = NSTextField(labelWithString: "hi")
        label.textColor = .red
        StyleEngine.apply(key: "color", value: "bogus", to: label)
        XCTAssertEqual(label.textColor, .red)
    }

    // MARK: - Layout prop routing

    func testWidthPointsAndPercent() {
        let view = FlippedView()
        let node = view.ensureLayoutNode()

        StyleEngine.apply(key: "width", value: 120.0, to: view)
        XCTAssertEqual(node.width, .points(120))

        StyleEngine.apply(key: "width", value: "50%", to: view)
        XCTAssertEqual(node.width, .percent(50))

        StyleEngine.apply(key: "width", value: "auto", to: view)
        XCTAssertEqual(node.width, .auto)
    }

    func testFlexDirectionRouting() {
        let view = FlippedView()
        let node = view.ensureLayoutNode()

        StyleEngine.apply(key: "flexDirection", value: "row", to: view)
        XCTAssertEqual(node.flexDirection, .row)

        StyleEngine.apply(key: "flexDirection", value: "column", to: view)
        XCTAssertEqual(node.flexDirection, .column)
    }

    func testPaddingRouting() {
        let view = FlippedView()
        let node = view.ensureLayoutNode()

        StyleEngine.apply(key: "padding", value: 8.0, to: view)
        XCTAssertEqual(node.padding, EdgeInsets(top: 8, right: 8, bottom: 8, left: 8))

        StyleEngine.apply(key: "paddingHorizontal", value: 4.0, to: view)
        XCTAssertEqual(node.padding.left, 4)
        XCTAssertEqual(node.padding.right, 4)
    }

    // MARK: - Accessibility

    func testImportantForAccessibilityNo() {
        let view = FlippedView()
        view.setAccessibilityElement(true)
        StyleEngine.apply(key: "importantForAccessibility", value: "no", to: view)
        XCTAssertFalse(view.isAccessibilityElement())
    }

    func testImportantForAccessibilityYes() {
        let view = FlippedView()
        view.setAccessibilityElement(false)
        StyleEngine.apply(key: "importantForAccessibility", value: "yes", to: view)
        XCTAssertTrue(view.isAccessibilityElement())
    }

    func testImportantForAccessibilityNoHideDescendants() {
        let parent = FlippedView()
        let child = FlippedView()
        parent.addSubview(child)

        StyleEngine.apply(key: "importantForAccessibility", value: "no-hide-descendants", to: parent)

        XCTAssertTrue(parent.isAccessibilityElement())
        XCTAssertEqual(parent.accessibilityChildren()?.count ?? -1, 0)
    }

    func testAccessibilityRoleMapping() {
        let view = FlippedView()
        StyleEngine.apply(key: "accessibilityRole", value: "button", to: view)
        XCTAssertEqual(view.accessibilityRole(), NSAccessibility.Role.button)
    }

    // MARK: - Default a11y roles on controls

    func testVButtonHasButtonRoleAndRowLayout() {
        let factory = VButtonFactory()
        let view = factory.createView()
        XCTAssertEqual(view.accessibilityRole(), NSAccessibility.Role.button)
        // Button content lays out as a centered row.
        XCTAssertEqual(view.layoutNode?.flexDirection, .row)
        XCTAssertEqual(view.layoutNode?.justifyContent, .center)
        XCTAssertEqual(view.layoutNode?.alignItems, .center)
    }

    func testVImageHasImageRole() {
        let factory = VImageFactory()
        let view = factory.createView()
        XCTAssertEqual(view.accessibilityRole(), NSAccessibility.Role.image)
    }

    // MARK: - 3D transforms

    func testTransformPerspectiveSetsM34OnLayer() {
        let view = FlippedView()
        StyleEngine.apply(key: "transform", value: [["perspective": 1000.0]], to: view)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer transform after applying perspective")
        }
        XCTAssertEqual(transform.m34, -1.0 / 1000.0, accuracy: 0.0001)
    }

    func testTransformNonArrayResetsToIdentity() {
        let view = FlippedView()
        StyleEngine.apply(key: "transform", value: [["perspective": 500.0]], to: view)
        StyleEngine.apply(key: "transform", value: nil, to: view)

        guard let transform = view.layer?.transform else {
            return XCTFail("expected a layer transform after reset")
        }
        XCTAssertTrue(CATransform3DIsIdentity(transform))
    }

    func testComposeTransformRotateX() {
        let transform = StyleEngine.composeTransform3D([["rotateX": "90deg"]])
        // Rotation about X by 90deg: m23 = sin = 1, m32 = -sin = -1.
        XCTAssertEqual(transform.m23, 1.0, accuracy: 0.001)
        XCTAssertEqual(transform.m32, -1.0, accuracy: 0.001)
        XCTAssertEqual(transform.m22, 0.0, accuracy: 0.001)
        XCTAssertEqual(transform.m33, 0.0, accuracy: 0.001)
    }

    func testComposeTransformRotateY() {
        let transform = StyleEngine.composeTransform3D([["rotateY": "90deg"]])
        // Rotation about Y by 90deg: m13 = -sin = -1, m31 = sin = 1.
        XCTAssertEqual(transform.m13, -1.0, accuracy: 0.001)
        XCTAssertEqual(transform.m31, 1.0, accuracy: 0.001)
        XCTAssertEqual(transform.m11, 0.0, accuracy: 0.001)
        XCTAssertEqual(transform.m33, 0.0, accuracy: 0.001)
    }

    func testComposeTransformRotateZMatchesRotate() {
        let viaRotate = StyleEngine.composeTransform3D([["rotate": "45deg"]])
        let viaRotateZ = StyleEngine.composeTransform3D([["rotateZ": "45deg"]])
        XCTAssertEqual(viaRotate.m11, viaRotateZ.m11, accuracy: 0.0001)
        XCTAssertEqual(viaRotate.m12, viaRotateZ.m12, accuracy: 0.0001)
        XCTAssertEqual(viaRotate.m21, viaRotateZ.m21, accuracy: 0.0001)
        XCTAssertEqual(viaRotate.m22, viaRotateZ.m22, accuracy: 0.0001)
    }

    func testComposeTransformSkewX() {
        let transform = StyleEngine.composeTransform3D([["skewX": "45deg"]])
        // skewX sets m21 = tan(45deg) = 1.
        XCTAssertEqual(transform.m21, 1.0, accuracy: 0.001)
        XCTAssertEqual(transform.m12, 0.0, accuracy: 0.001)
    }

    func testComposeTransformSkewY() {
        let transform = StyleEngine.composeTransform3D([["skewY": "45deg"]])
        // skewY sets m12 = tan(45deg) = 1.
        XCTAssertEqual(transform.m12, 1.0, accuracy: 0.001)
        XCTAssertEqual(transform.m21, 0.0, accuracy: 0.001)
    }

    func testComposeTransformTranslateAndScale() {
        let transform = StyleEngine.composeTransform3D([
            ["translateX": 10.0],
            ["translateY": 20.0],
            ["scaleX": 2.0],
            ["scaleY": 3.0],
        ])
        XCTAssertEqual(transform.m41, 10.0, accuracy: 0.001)
        XCTAssertEqual(transform.m42, 20.0, accuracy: 0.001)
        XCTAssertEqual(transform.m11, 2.0, accuracy: 0.001)
        XCTAssertEqual(transform.m22, 3.0, accuracy: 0.001)
    }
}
