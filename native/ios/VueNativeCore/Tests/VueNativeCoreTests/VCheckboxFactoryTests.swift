#if canImport(UIKit)
import UIKit
import XCTest
@testable import VueNativeCore

/// C1-9: VCheckbox was invisible to VoiceOver. The container must be the single
/// accessibility element, carrying the label, a button trait, and a checked
/// value that follows the `value` prop.
@MainActor
final class VCheckboxFactoryTests: XCTestCase {

    func testContainerIsTheAccessibilityElementWithButtonTrait() {
        let factory = VCheckboxFactory()
        let view = factory.createView()

        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertTrue(view.accessibilityTraits.contains(.button))
    }

    func testLabelPropBecomesTheAccessibilityLabelAndTracksChanges() {
        let factory = VCheckboxFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "label", value: "I accept the terms")
        XCTAssertEqual(view.accessibilityLabel, "I accept the terms")

        factory.updateProp(view: view, key: "label", value: "Subscribe")
        XCTAssertEqual(view.accessibilityLabel, "Subscribe")

        factory.updateProp(view: view, key: "label", value: "")
        XCTAssertNil(view.accessibilityLabel)
    }

    func testAccessibilityValueFollowsTheCheckedState() {
        let factory = VCheckboxFactory()
        let view = factory.createView()
        XCTAssertEqual(view.accessibilityValue, "unchecked")

        factory.updateProp(view: view, key: "value", value: true)
        XCTAssertEqual(view.accessibilityValue, "checked")

        factory.updateProp(view: view, key: "value", value: false)
        XCTAssertEqual(view.accessibilityValue, "unchecked")
    }

    func testDisabledAddsNotEnabledWithoutDroppingTheButtonTrait() {
        let factory = VCheckboxFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "disabled", value: true)
        XCTAssertTrue(view.accessibilityTraits.contains(.notEnabled))
        XCTAssertTrue(view.accessibilityTraits.contains(.button))

        factory.updateProp(view: view, key: "disabled", value: false)
        XCTAssertFalse(view.accessibilityTraits.contains(.notEnabled))
        XCTAssertTrue(view.accessibilityTraits.contains(.button))
    }
}
#endif
