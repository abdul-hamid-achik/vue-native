import JavaScriptCore
import XCTest
@testable import VueNativeShared

/// fetch responses expose a Headers-like object (`response.headers.get(name)`), not a bare dictionary.
final class HeadersFactoryTests: XCTestCase {

    func testHeadersAreCaseInsensitiveAndIterable() throws {
        let context = try XCTUnwrap(JSContext())
        let raw = try XCTUnwrap(context.evaluateScript("({ 'Set-Auth-Token': 'abc', 'Content-Type': 'application/json' })"))
        let headers = SharedJSPolyfills.makeHeaders(raw, in: context)
        context.setObject(headers, forKeyedSubscript: "h" as NSString)

        XCTAssertEqual(context.evaluateScript("h.get('set-auth-token')")?.toString(), "abc")
        XCTAssertEqual(context.evaluateScript("h.get('SET-AUTH-TOKEN')")?.toString(), "abc")
        XCTAssertTrue(context.evaluateScript("h.get('missing') === null")?.toBool() ?? false)
        XCTAssertTrue(context.evaluateScript("h.has('content-type')")?.toBool() ?? false)
        XCTAssertEqual(context.evaluateScript("Array.from(h).map(function (e) { return e[0]; }).join(',')")?.toString(), "content-type,set-auth-token")
        XCTAssertEqual(context.evaluateScript("h['Set-Auth-Token']")?.toString(), "abc", "raw keys stay readable")
        XCTAssertEqual(context.evaluateScript("Object.keys(h).length")?.toInt32(), 2, "methods are not enumerable")
    }
}
