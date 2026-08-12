#if canImport(AppKit)
import XCTest
import AppKit
import Contacts
import EventKit
@testable import VueNativeMacOS

/// Tests for `PermissionsModule`'s `contacts`/`calendar` authorization-status
/// mapping. `CNAuthorizationStatus`/`EKAuthorizationStatus` can be constructed
/// directly (they are plain enums), so the pure mapping functions are
/// exercised per case without touching the Contacts/EventKit frameworks
/// themselves. NSApplication-independent (no permission prompts).
@MainActor
final class PermissionsModuleTests: XCTestCase {

    // MARK: - Contacts

    func testContactsAuthorizedMapsToGranted() {
        XCTAssertEqual(PermissionsModule.mapContactsStatus(.authorized), "granted")
    }

    func testContactsDeniedMapsToDenied() {
        XCTAssertEqual(PermissionsModule.mapContactsStatus(.denied), "denied")
    }

    func testContactsRestrictedMapsToRestricted() {
        // Regression: the pre-existing macOS mapping collapsed restricted
        // into denied; the shared PermissionStatus contract keeps them apart.
        XCTAssertEqual(PermissionsModule.mapContactsStatus(.restricted), "restricted")
    }

    func testContactsNotDeterminedMapsToNotDetermined() {
        XCTAssertEqual(PermissionsModule.mapContactsStatus(.notDetermined), "notDetermined")
    }

    // Note: `CNAuthorizationStatus.limited` is `@available(macOS, unavailable)`
    // -- macOS has no equivalent to iOS 18's limited-contacts picker -- so
    // there is no macOS test for it (mirrors the source's intentional gap).

    // MARK: - Calendar

    func testCalendarRestrictedMapsToRestricted() {
        XCTAssertEqual(PermissionsModule.mapCalendarStatus(.restricted), "restricted")
    }

    func testCalendarDeniedMapsToDenied() {
        XCTAssertEqual(PermissionsModule.mapCalendarStatus(.denied), "denied")
    }

    func testCalendarNotDeterminedMapsToNotDetermined() {
        XCTAssertEqual(PermissionsModule.mapCalendarStatus(.notDetermined), "notDetermined")
    }

    func testCalendarFullAccessMapsToGranted() throws {
        guard #available(macOS 14.0, *) else {
            throw XCTSkip("EKAuthorizationStatus.fullAccess requires macOS 14")
        }
        XCTAssertEqual(PermissionsModule.mapCalendarStatus(.fullAccess), "granted")
    }

    func testCalendarWriteOnlyMapsToLimited() throws {
        guard #available(macOS 14.0, *) else {
            throw XCTSkip("EKAuthorizationStatus.writeOnly requires macOS 14")
        }
        XCTAssertEqual(PermissionsModule.mapCalendarStatus(.writeOnly), "limited")
    }

    // MARK: - Recognized methods (contract parity)

    /// `check` must recognize "contacts"/"calendar" as valid permission
    /// types -- i.e. return a `PermissionStatus` string rather than the
    /// "Unsupported permission type" error.
    @discardableResult
    private func invoke(
        _ module: PermissionsModule,
        _ method: String,
        args: [Any] = [],
        timeout: TimeInterval = 3
    ) -> (result: Any?, error: String?) {
        let completed = expectation(description: "\(method) completes")
        var result: Any?
        var error: String?
        module.invoke(method: method, args: args) { value, callbackError in
            result = value
            error = callbackError
            completed.fulfill()
        }
        wait(for: [completed], timeout: timeout)
        return (result, error)
    }

    func testCheckContactsReturnsRecognizedStatusString() {
        let module = PermissionsModule()
        let response = invoke(module, "check", args: ["contacts"])
        XCTAssertNil(response.error)
        let validStatuses: Set<String> = ["granted", "denied", "restricted", "limited", "notDetermined"]
        XCTAssertTrue(validStatuses.contains(response.result as? String ?? ""))
    }

    func testCheckCalendarReturnsRecognizedStatusString() {
        let module = PermissionsModule()
        let response = invoke(module, "check", args: ["calendar"])
        XCTAssertNil(response.error)
        let validStatuses: Set<String> = ["granted", "denied", "restricted", "limited", "notDetermined"]
        XCTAssertTrue(validStatuses.contains(response.result as? String ?? ""))
    }
}
#endif
