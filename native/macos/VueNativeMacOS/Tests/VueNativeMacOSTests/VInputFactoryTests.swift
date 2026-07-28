import XCTest
@testable import VueNativeMacOS

/// VInputFactory tests: secure text entry (cell swap to NSSecureTextFieldCell)
/// and multiline wrapping — both must preserve the view instance the bridge
/// references, along with text, placeholder, and delegate state.
@MainActor
final class VInputFactoryTests: XCTestCase {

    private func makeField() -> (VInputFactory, NSTextField) {
        let factory = VInputFactory()
        let view = factory.createView()
        guard let field = view as? NSTextField else {
            XCTFail("VInput must create an NSTextField")
            fatalError()
        }
        return (factory, field)
    }

    // MARK: - Secure text entry

    func testSecureTextEntrySwapsToSecureCell() {
        let (factory, field) = makeField()
        XCTAssertFalse(field.cell is NSSecureTextFieldCell, "starts non-secure")

        factory.updateProp(view: field, key: "secureTextEntry", value: true)
        XCTAssertTrue(field.cell is NSSecureTextFieldCell, "secure cell installed")

        factory.updateProp(view: field, key: "secureTextEntry", value: false)
        XCTAssertFalse(field.cell is NSSecureTextFieldCell, "secure cell removed")
    }

    func testSecureTextEntryPreservesTextAndPlaceholder() {
        let (factory, field) = makeField()
        factory.updateProp(view: field, key: "text", value: "hunter2")
        factory.updateProp(view: field, key: "placeholder", value: "Password")

        factory.updateProp(view: field, key: "secureTextEntry", value: true)

        XCTAssertEqual(field.stringValue, "hunter2", "text survives the cell swap")
        XCTAssertEqual(field.placeholderString, "Password", "placeholder survives the cell swap")
    }

    func testSecureTextEntryPreservesDelegate() {
        let (factory, field) = makeField()
        factory.addEventListener(view: field, event: "changetext") { _ in }
        let delegate = field.delegate
        XCTAssertNotNil(delegate)

        factory.updateProp(view: field, key: "secureTextEntry", value: true)

        XCTAssertTrue(field.delegate === delegate, "delegate must survive the cell swap")
    }

    func testSecureTextEntryAcceptsIntAndIsIdempotent() {
        let (factory, field) = makeField()
        factory.updateProp(view: field, key: "text", value: "abc")

        factory.updateProp(view: field, key: "secureTextEntry", value: 1)
        XCTAssertTrue(field.cell is NSSecureTextFieldCell)

        // Applying again must not lose state.
        factory.updateProp(view: field, key: "secureTextEntry", value: true)
        XCTAssertTrue(field.cell is NSSecureTextFieldCell)
        XCTAssertEqual(field.stringValue, "abc")
    }

    // MARK: - Multiline

    func testMultilineEnablesWrapping() {
        let (factory, field) = makeField()
        factory.updateProp(view: field, key: "multiline", value: true)

        let cell = field.cell as? NSTextFieldCell
        XCTAssertEqual(cell?.wraps, true)
        XCTAssertEqual(cell?.isScrollable, false)
        XCTAssertEqual(field.maximumNumberOfLines, 0, "unlimited lines when multiline")
    }

    func testMultilineDisableRestoresSingleLine() {
        let (factory, field) = makeField()
        factory.updateProp(view: field, key: "multiline", value: true)
        factory.updateProp(view: field, key: "multiline", value: false)

        let cell = field.cell as? NSTextFieldCell
        XCTAssertEqual(cell?.wraps, false)
        XCTAssertEqual(field.maximumNumberOfLines, 1)
    }

    func testSecureAndMultilineCompose() {
        let (factory, field) = makeField()
        factory.updateProp(view: field, key: "multiline", value: true)
        factory.updateProp(view: field, key: "secureTextEntry", value: true)

        // The secure cell swap must retain the multiline wrapping configuration.
        let cell = field.cell as? NSTextFieldCell
        XCTAssertTrue(field.cell is NSSecureTextFieldCell)
        XCTAssertEqual(cell?.wraps, true, "wrapping survives the secure cell swap")
    }
}
