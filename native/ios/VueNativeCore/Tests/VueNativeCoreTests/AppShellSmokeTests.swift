#if canImport(UIKit)
import UIKit
import XCTest
@testable import VueNativeCore

@MainActor
final class AppShellSmokeTests: XCTestCase {

    private final class FixtureViewController: VueNativeViewController {
        override var fixtureBundleURL: URL? { AppShellFixture.url }
    }

    func testViewControllerLoadsFixtureAndExposesStableAccessibilityTree() {
        NativeBridge.shared.reset()

        let controller = FixtureViewController()
        controller.loadViewIfNeeded()
        addTeardownBlock {
            NativeBridge.shared.reset()
        }

        let root = waitForView(in: controller.view, label: AppShellFixture.rootLabel)
        let label = waitForView(in: controller.view, label: AppShellFixture.labelLabel)
        guard let root, let label else {
            return XCTFail("host must attach app-shell-root and app-shell-label")
        }

        XCTAssertTrue(isDescendant(ancestor: root, candidate: label))
        guard let text = label as? UILabel else {
            return XCTFail("app-shell-label must be a UILabel")
        }
        XCTAssertEqual(text.text, AppShellFixture.labelText)
    }

    private func waitForView(in root: UIView, label: String) -> UIView? {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            if let found = findView(in: root, label: label) {
                return found
            }
        }
        return nil
    }

    private func findView(in root: UIView, label: String) -> UIView? {
        if root.accessibilityLabel == label {
            return root
        }
        for child in root.subviews {
            if let found = findView(in: child, label: label) {
                return found
            }
        }
        return nil
    }

    private func isDescendant(ancestor: UIView, candidate: UIView) -> Bool {
        var current: UIView? = candidate
        while let view = current {
            if view === ancestor { return true }
            current = view.superview
        }
        return false
    }
}

enum AppShellFixture {
    static let rootLabel = "app-shell-root"
    static let labelLabel = "app-shell-label"
    static let labelText = "app-shell-ok"

    static var url: URL {
        var directory = URL(fileURLWithPath: #filePath)
        for _ in 0..<16 {
            directory.deleteLastPathComponent()
            let candidate = directory.appendingPathComponent("fixtures/app-shell/vue-native-bundle.js")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        preconditionFailure("fixtures/app-shell/vue-native-bundle.js not found from \(#filePath)")
    }
}
#endif
