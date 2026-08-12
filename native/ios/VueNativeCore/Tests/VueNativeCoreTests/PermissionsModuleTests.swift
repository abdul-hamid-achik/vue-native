#if canImport(UIKit)
import XCTest
import UIKit
import Contacts
import EventKit
@testable import VueNativeCore

/// Tests for `PermissionsModule`'s `contacts`/`calendar` authorization-status
/// mapping. `CNAuthorizationStatus`/`EKAuthorizationStatus` can be constructed
/// directly (they are plain enums), so the pure mapping functions are
/// exercised per case without touching the Contacts/EventKit frameworks
/// themselves -- mirroring how `HotReloadStatusViewTests` tests its mapping.
@MainActor
final class PermissionsModuleTests: XCTestCase {

    // MARK: - Contacts

    func testContactsAuthorizedMapsToGranted() {
        XCTAssertEqual(PermissionsModule.statusString(contactsStatus: .authorized), "granted")
    }

    func testContactsDeniedMapsToDenied() {
        XCTAssertEqual(PermissionsModule.statusString(contactsStatus: .denied), "denied")
    }

    func testContactsRestrictedMapsToRestricted() {
        // Regression: restricted must stay distinct from denied (parental
        // controls vs. an explicit user choice read very differently in UI).
        XCTAssertEqual(PermissionsModule.statusString(contactsStatus: .restricted), "restricted")
    }

    func testContactsNotDeterminedMapsToNotDetermined() {
        XCTAssertEqual(PermissionsModule.statusString(contactsStatus: .notDetermined), "notDetermined")
    }

    func testContactsLimitedMapsToLimited() throws {
        guard #available(iOS 18.0, *) else {
            throw XCTSkip("CNAuthorizationStatus.limited requires iOS 18")
        }
        XCTAssertEqual(PermissionsModule.statusString(contactsStatus: .limited), "limited")
    }

    // MARK: - Calendar

    func testCalendarRestrictedMapsToRestricted() {
        XCTAssertEqual(PermissionsModule.statusString(calendarStatus: .restricted), "restricted")
    }

    func testCalendarDeniedMapsToDenied() {
        XCTAssertEqual(PermissionsModule.statusString(calendarStatus: .denied), "denied")
    }

    func testCalendarNotDeterminedMapsToNotDetermined() {
        XCTAssertEqual(PermissionsModule.statusString(calendarStatus: .notDetermined), "notDetermined")
    }

    func testCalendarFullAccessMapsToGranted() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("EKAuthorizationStatus.fullAccess requires iOS 17")
        }
        XCTAssertEqual(PermissionsModule.statusString(calendarStatus: .fullAccess), "granted")
    }

    func testCalendarWriteOnlyMapsToLimited() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("EKAuthorizationStatus.writeOnly requires iOS 17")
        }
        XCTAssertEqual(PermissionsModule.statusString(calendarStatus: .writeOnly), "limited")
    }

    // MARK: - Recognized methods (contract parity)

    /// `check` must recognize "contacts"/"calendar" as valid permission
    /// types -- i.e. return a `PermissionStatus` string rather than falling
    /// through to the "unrecognized permission" `notDetermined` default.
    /// Modeled on `ModuleContractParityTest`.
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
