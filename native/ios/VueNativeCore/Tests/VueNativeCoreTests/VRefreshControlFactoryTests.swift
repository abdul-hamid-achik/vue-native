#if canImport(UIKit)
import XCTest
import UIKit
@testable import VueNativeCore

/// Regression coverage for the `style` prop now reaching native factories
/// (previously dropped before it left TS). `VRefreshControlFactory`'s wrapper
/// view is a zero-size, hidden placeholder -- the visible widget is the
/// `UIRefreshControl` attached to the parent scroll view -- so style props
/// have no visual home here. This asserts the factory tolerates them (no
/// crash, no unexpected UIRefreshControl mutation) whether they arrive as a
/// single `"style"` dict (the generic `updateProp` path) or pre-flattened
/// into individual keys (the `updateStyle` op's path -- see
/// `NativeBridge.handleUpdateStyle`).
@MainActor
final class VRefreshControlFactoryTests: XCTestCase {

    func testUpdatePropWithStyleDictLeavesWrapperAndControlUntouched() {
        let factory = VRefreshControlFactory()
        let view = factory.createView()
        let control = VRefreshControlFactory.refreshControl(for: view)

        // `updateProp` handles only refreshing/tintColor/title and has
        // `default: break` — it never falls through to StyleEngine — so a
        // `"style"` dict must leave both the wrapper and its control exactly as
        // they were. Snapshot first so "unchanged" is measured, not assumed.
        let backgroundBefore = view.backgroundColor
        let alphaBefore = view.alpha
        let tintBefore = control?.tintColor
        let titleBefore = control?.attributedTitle

        factory.updateProp(view: view, key: "style", value: [
            "backgroundColor": "#ff0000",
            "padding": 8,
            "width": 100,
        ])

        // The wrapper stays hidden/zero-sized -- style has no visual effect
        // on this placeholder view, only recognized props (refreshing/
        // tintColor/title) do.
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(view.frame, .zero)
        XCTAssertEqual(view.backgroundColor, backgroundBefore, "the style dict must not paint the wrapper")
        XCTAssertNotEqual(view.backgroundColor, UIColor.fromHex("#ff0000"), "backgroundColor from the dict must not land")
        XCTAssertEqual(view.alpha, alphaBefore, accuracy: 0.001, "the style dict must not change the wrapper's alpha")
        XCTAssertEqual(control?.tintColor, tintBefore, "the style dict must not retint the UIRefreshControl")
        XCTAssertEqual(control?.attributedTitle, titleBefore, "the style dict must not retitle the UIRefreshControl")

        // Control: the very same call path *does* mutate when the key is
        // recognized, so the equalities above are not vacuous.
        factory.updateProp(view: view, key: "title", value: "Loading")
        XCTAssertEqual(control?.attributedTitle?.string, "Loading")
    }

    func testUpdatePropWithFlattenedStyleKeysLeavesWrapperAndControlUntouched() {
        // Mirrors how `NativeBridge.handleUpdateStyle` actually delivers a
        // style object: one `updateProp` call per key. None of these keys are
        // recognized by this factory, so none of them may reach the wrapper or
        // the control.
        let factory = VRefreshControlFactory()
        let view = factory.createView()
        let control = VRefreshControlFactory.refreshControl(for: view)
        let backgroundBefore = view.backgroundColor
        let tintBefore = control?.tintColor

        factory.updateProp(view: view, key: "backgroundColor", value: "#ff0000")
        factory.updateProp(view: view, key: "padding", value: 8)
        factory.updateProp(view: view, key: "opacity", value: 0.5)

        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(view.frame, .zero, "a flattened width/padding must not resize the placeholder")
        XCTAssertEqual(view.backgroundColor, backgroundBefore, "backgroundColor is not a prop of this factory")
        XCTAssertNotEqual(view.backgroundColor, UIColor.fromHex("#ff0000"))
        XCTAssertEqual(view.alpha, 1.0, accuracy: 0.001, "opacity must not be applied to the placeholder")
        XCTAssertEqual(control?.tintColor, tintBefore, "unrecognized keys must not retint the UIRefreshControl")

        // Control: recognized keys still land on the control through this path.
        factory.updateProp(view: view, key: "tintColor", value: "#00ff00")
        XCTAssertEqual(control?.tintColor, UIColor.fromHex("#00ff00"))
    }

    func testRecognizedPropsStillWorkAlongsideUnknownStyleKeys() {
        let factory = VRefreshControlFactory()
        let view = factory.createView()

        factory.updateProp(view: view, key: "backgroundColor", value: "#ff0000")
        factory.updateProp(view: view, key: "tintColor", value: "#00ff00")

        let refreshControl = VRefreshControlFactory.refreshControl(for: view)
        XCTAssertNotNil(refreshControl)
        XCTAssertEqual(refreshControl?.tintColor, UIColor.fromHex("#00ff00"))
    }

    // MARK: - Installation on a scroll view
    //
    // Regression: the wrapper's UIRefreshControl used to be created and stored as an
    // associated object, but never assigned to any `UIScrollView.refreshControl`, so
    // `<VRefreshControl>` rendered nothing and pull-to-refresh never fired. The old
    // test asserted only that the associated object existed, which is why that
    // shipped. These assert the control is actually installed.

    /// A scroll view built the way the bridge builds one: the factory creates it with
    /// an inner content view, and children are inserted into that content view.
    private struct ScrollViewFixture {
        let factory: VScrollViewFactory
        let scrollView: UIScrollView
        let contentView: UIView
    }

    private func makeScrollView() -> ScrollViewFixture {
        let factory = VScrollViewFactory()
        let scrollView = factory.createView() as! UIScrollView
        let contentView = VScrollViewFactory.contentView(for: scrollView)!
        return ScrollViewFixture(factory: factory, scrollView: scrollView, contentView: contentView)
    }

    func testInsertingWrapperIntoScrollViewInstallsRefreshControl() {
        let fixture = makeScrollView()
        let refreshFactory = VRefreshControlFactory()
        let wrapper = refreshFactory.createView()
        let control = VRefreshControlFactory.refreshControl(for: wrapper)
        XCTAssertNotNil(control, "the wrapper must own a UIRefreshControl")
        XCTAssertNil(fixture.scrollView.refreshControl, "precondition: nothing installed yet")

        // `NativeBridge.moveChild` routes an insertion through the *parent's* factory
        // and passes the scroll view's inner content view as the container.
        fixture.factory.insertChild(wrapper, into: fixture.contentView, before: nil)

        XCTAssertTrue(
            fixture.scrollView.refreshControl === control,
            "inserting a <VRefreshControl> must install its UIRefreshControl on the enclosing scroll view"
        )
    }

    func testRemovingWrapperDetachesRefreshControl() {
        let fixture = makeScrollView()
        let refreshFactory = VRefreshControlFactory()
        let wrapper = refreshFactory.createView()
        fixture.factory.insertChild(wrapper, into: fixture.contentView, before: nil)
        XCTAssertNotNil(fixture.scrollView.refreshControl)

        fixture.factory.removeChild(wrapper, from: fixture.contentView)

        XCTAssertNil(
            fixture.scrollView.refreshControl,
            "removing the <VRefreshControl> must detach the control it installed"
        )
    }

    func testWrapperInsertedThroughItsOwnFactoryReachesAncestorScrollView() {
        // Defensive path: `VRefreshControlFactory.insertChild` only runs when the
        // wrapper is itself the parent, but it must still reach the scroll view.
        let fixture = makeScrollView()
        let refreshFactory = VRefreshControlFactory()
        let wrapper = refreshFactory.createView()
        fixture.contentView.addSubview(wrapper)

        refreshFactory.insertChild(UIView(), into: wrapper, before: nil)

        XCTAssertTrue(
            fixture.scrollView.refreshControl === VRefreshControlFactory.refreshControl(for: wrapper),
            "the wrapper's own insertChild path must install its control on the ancestor scroll view"
        )
    }

    func testDestroyViewDetachesRefreshControl() {
        let fixture = makeScrollView()
        let refreshFactory = VRefreshControlFactory()
        let wrapper = refreshFactory.createView()
        fixture.factory.insertChild(wrapper, into: fixture.contentView, before: nil)
        XCTAssertNotNil(fixture.scrollView.refreshControl)

        refreshFactory.destroyView(view: wrapper)

        XCTAssertNil(
            fixture.scrollView.refreshControl,
            "permanent removal must not leave the control installed"
        )
    }

    // MARK: - Target lifetime
    //
    // Regression (P0): `UIControl` does not retain its targets. Both refresh paths
    // used to build a fresh target per `addEventListener` and store it with
    // `OBJC_ASSOCIATION_RETAIN_NONATOMIC`, which released the previous one while the
    // control still held an unretained pointer to it. Vue rebinds a listener whenever
    // the handler closure's identity changes, so this was reachable in normal use and
    // crashed with EXC_BAD_ACCESS on the next pull.

    /// Fire the target-action a control actually holds.
    ///
    /// `UIControl.sendActions(for:)` did not deliver in the headless XCTest host (and
    /// on a `UIRefreshControl` it also drags in the refresh animation, which cost ~5s
    /// per call). Resolving the registered target and invoking the selector directly
    /// still exercises exactly what is under test: that the target the control holds
    /// is alive and wired to the most recently bound handler. In the unfixed code the
    /// first target had been released while the control kept an unretained pointer to
    /// it, so this is where the EXC_BAD_ACCESS would surface.
    private func fireRefreshAction(on control: UIControl) {
        let selector = NSSelectorFromString("handleRefresh")
        for target in control.allTargets {
            guard let object = target as? NSObject else { continue }
            XCTAssertTrue(object.responds(to: selector), "the registered target must expose handleRefresh")
            _ = object.perform(selector)
        }
    }

    /// The single target a control holds, as a reference type. `UIControl.allTargets`
    /// is a `Set<AnyHashable>` in the Swift overlay, so identity comparison needs a
    /// cast first.
    private func onlyTarget(of control: UIControl) -> NSObject? {
        guard let target = control.allTargets.first else { return nil }
        return target as? NSObject
    }

    func testRebindingWrapperRefreshListenerKeepsExactlyOneLiveTarget() {
        let factory = VRefreshControlFactory()
        let wrapper = factory.createView()
        let control = VRefreshControlFactory.refreshControl(for: wrapper)!

        var staleCalls = 0
        var currentCalls = 0
        factory.addEventListener(view: wrapper, event: "refresh") { _ in staleCalls += 1 }
        let targetAfterFirstBind = onlyTarget(of: control)
        factory.addEventListener(view: wrapper, event: "refresh") { _ in currentCalls += 1 }

        XCTAssertEqual(
            control.allTargets.count, 1,
            "rebinding must swap the handler inside one long-lived target, not register a second"
        )
        XCTAssertNotNil(targetAfterFirstBind)
        XCTAssertTrue(
            targetAfterFirstBind === onlyTarget(of: control),
            "rebinding must reuse the same target instance, since UIControl does not retain its targets"
        )

        fireRefreshAction(on: control)
        XCTAssertEqual(currentCalls, 1, "the most recently bound handler must run")
        XCTAssertEqual(staleCalls, 0, "the superseded handler must not run")
    }

    func testRebindingScrollViewRefreshListenerKeepsExactlyOneLiveTarget() {
        let fixture = makeScrollView()
        let factory = VScrollViewFactory()

        var staleCalls = 0
        var currentCalls = 0
        factory.addEventListener(view: fixture.scrollView, event: "refresh") { _ in staleCalls += 1 }
        let control = fixture.scrollView.refreshControl!
        let targetAfterFirstBind = onlyTarget(of: control)
        factory.addEventListener(view: fixture.scrollView, event: "refresh") { _ in currentCalls += 1 }

        XCTAssertEqual(control.allTargets.count, 1, "a rebind must not register a second target")
        XCTAssertNotNil(targetAfterFirstBind)
        XCTAssertTrue(
            targetAfterFirstBind === onlyTarget(of: control),
            "a rebind must reuse the same target instance"
        )

        fireRefreshAction(on: control)
        XCTAssertEqual(currentCalls, 1)
        XCTAssertEqual(staleCalls, 0)
    }

    func testRemovingScrollViewRefreshListenerUnregistersItsTarget() {
        let fixture = makeScrollView()
        let factory = VScrollViewFactory()

        var calls = 0
        factory.addEventListener(view: fixture.scrollView, event: "refresh") { _ in calls += 1 }
        let control = fixture.scrollView.refreshControl!
        XCTAssertFalse(control.allTargets.isEmpty)

        // Regression: this path returned early for any event other than "scroll", so
        // the refresh target was never removed and outlived the listener.
        factory.removeEventListener(view: fixture.scrollView, event: "refresh")

        XCTAssertTrue(
            control.allTargets.isEmpty,
            "removeEventListener(\"refresh\") must unregister the target"
        )
        fireRefreshAction(on: control)
        XCTAssertEqual(calls, 0, "a removed listener must not fire")
    }
}
#endif
