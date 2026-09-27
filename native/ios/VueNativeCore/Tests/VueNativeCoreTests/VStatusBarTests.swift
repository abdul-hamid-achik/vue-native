#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Coverage for `<VStatusBar>`, which used to be a complete no-op: the factory
/// posted `VueNativeStatusBarStyleChange` / `VueNativeStatusBarHiddenChange` but
/// nothing anywhere in `native/` observed them, and no view controller overrode
/// `preferredStatusBarStyle` or `prefersStatusBarHidden` — even though the docs
/// advertise `barStyle`, `hidden` and `animated`.
@MainActor
final class VStatusBarTests: XCTestCase {

    // MARK: - Style mapping

    func testBarStyleStringsMapToUIStatusBarStyle() {
        XCTAssertEqual(VStatusBarFactory.uiStyle(for: "light-content"), .lightContent)
        XCTAssertEqual(VStatusBarFactory.uiStyle(for: "dark-content"), .darkContent)
        XCTAssertEqual(VStatusBarFactory.uiStyle(for: "default"), .default)
        XCTAssertEqual(
            VStatusBarFactory.uiStyle(for: "nonsense"), .default,
            "an unrecognized style must fall back to the system default"
        )
    }

    // MARK: - Notification contract

    /// Drive `updateProp` and capture what the factory broadcasts.
    private func captureNotification(
        _ name: Notification.Name,
        props: [(key: String, value: Any?)]
    ) -> Notification? {
        let factory = VStatusBarFactory()
        let view = factory.createView()

        var received: Notification?
        let observer = NotificationCenter.default.addObserver(
            forName: name, object: nil, queue: nil
        ) { notification in
            received = notification
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        for prop in props {
            factory.updateProp(view: view, key: prop.key, value: prop.value)
        }
        return received
    }

    func testBarStylePropPostsStyleAndAnimated() {
        let notification = captureNotification(
            VStatusBarNotification.styleChange,
            props: [(key: "barStyle", value: "light-content")]
        )
        XCTAssertNotNil(notification, "barStyle must broadcast a style-change notification")
        XCTAssertEqual(
            notification?.userInfo?[VStatusBarNotification.styleKey] as? String,
            "light-content"
        )
        XCTAssertEqual(
            notification?.userInfo?[VStatusBarNotification.animatedKey] as? Bool, true,
            "the TS component defaults `animated` to true"
        )
    }

    func testAnimatedPropIsCarriedOnTheNextNotification() {
        // `animated` is declared in the TS component and documented, so it must reach
        // the host rather than being dropped. Prop arrival order is not guaranteed,
        // hence the per-view storage.
        let notification = captureNotification(
            VStatusBarNotification.hiddenChange,
            props: [(key: "animated", value: false), (key: "hidden", value: true)]
        )
        XCTAssertEqual(notification?.userInfo?[VStatusBarNotification.hiddenKey] as? Bool, true)
        XCTAssertEqual(
            notification?.userInfo?[VStatusBarNotification.animatedKey] as? Bool, false,
            "an explicit animated=false must be reported to the host"
        )
    }

    func testHiddenPropAcceptsBridgedNumberShapes() {
        // A JS boolean can arrive through the JSON bridge as Bool, NSNumber or Int.
        for value in [true, NSNumber(value: true), 1] as [Any] {
            let notification = captureNotification(
                VStatusBarNotification.hiddenChange,
                props: [(key: "hidden", value: value)]
            )
            XCTAssertEqual(
                notification?.userInfo?[VStatusBarNotification.hiddenKey] as? Bool, true,
                "hidden=\(value) must coerce to true"
            )
        }
    }

    // MARK: - Host wiring

    /// A host that loads the app-shell fixture, so `loadViewIfNeeded()` does not fail
    /// the bundle load and raise the DEBUG error overlay on the shared key window.
    private final class FixtureHost: VueNativeViewController {
        override var fixtureBundleURL: URL? { AppShellFixture.url }
    }

    /// Let `OperationQueue.main` and the `Task { @MainActor }` hop inside the
    /// observer run to completion.
    private func drainMainActor() {
        let drained = expectation(description: "main actor drained")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { drained.fulfill() }
        waitForExpectations(timeout: 10)
    }

    func testHostAppliesBarStyleFromNotification() {
        NativeBridge.shared.reset()
        let host = FixtureHost()
        host.loadViewIfNeeded()
        addTeardownBlock { NativeBridge.shared.reset() }

        XCTAssertEqual(host.preferredStatusBarStyle, .default, "a fresh host starts at the system default")

        NotificationCenter.default.post(
            name: VStatusBarNotification.styleChange,
            object: nil,
            userInfo: [VStatusBarNotification.styleKey: "light-content",
                       VStatusBarNotification.animatedKey: true]
        )
        drainMainActor()

        XCTAssertEqual(
            host.preferredStatusBarStyle, .lightContent,
            "the host must observe the notification and expose it through preferredStatusBarStyle"
        )
        XCTAssertEqual(host.preferredStatusBarUpdateAnimation, .slide)
    }

    func testHostAppliesHiddenAndNonAnimatedFromNotification() {
        NativeBridge.shared.reset()
        let host = FixtureHost()
        host.loadViewIfNeeded()
        addTeardownBlock { NativeBridge.shared.reset() }

        XCTAssertFalse(host.prefersStatusBarHidden)

        NotificationCenter.default.post(
            name: VStatusBarNotification.hiddenChange,
            object: nil,
            userInfo: [VStatusBarNotification.hiddenKey: true,
                       VStatusBarNotification.animatedKey: false]
        )
        drainMainActor()

        XCTAssertTrue(host.prefersStatusBarHidden)
        XCTAssertEqual(
            host.preferredStatusBarUpdateAnimation, .none,
            "animated=false must select UIStatusBarAnimation.none"
        )
    }

    func testStatusBarStateIsPerHostAndDoesNotLeakBetweenInstances() {
        NativeBridge.shared.reset()
        let first = FixtureHost()
        first.loadViewIfNeeded()
        addTeardownBlock { NativeBridge.shared.reset() }

        NotificationCenter.default.post(
            name: VStatusBarNotification.styleChange,
            object: nil,
            userInfo: [VStatusBarNotification.styleKey: "light-content",
                       VStatusBarNotification.animatedKey: true]
        )
        drainMainActor()
        XCTAssertEqual(first.preferredStatusBarStyle, .lightContent)

        // A second host starts from the defaults: the style applied to one host must
        // not survive into another (which is what "state cleared on host release"
        // protects against, given the state is per-instance).
        let second = FixtureHost()
        second.loadViewIfNeeded()
        XCTAssertEqual(second.preferredStatusBarStyle, .default)
    }
}
#endif
