import XCTest
@testable import VueNativeMacOS

/// Tests for `AnimationModule`'s keyframe property-to-CALayer-keyPath mapping.
///
/// `keyPaths(forKeyframeProperty:)` is a pure static function extracted from
/// `animateKeyframes` specifically so this mapping can be verified without
/// spinning up a live NSView + CAAnimation pipeline.
final class AnimationModuleTests: XCTestCase {

    func testAnimationModuleName() {
        let module = AnimationModule(viewLookup: { _ in nil })
        XCTAssertEqual(module.moduleName, "Animation", "AnimationModule should be named 'Animation'")
    }

    /// Regression test: keyframe "scale" used to map to only
    /// "transform.scale.x", so a uniform scale keyframe stretched the view on
    /// the x axis instead of scaling it uniformly. It must drive both axes.
    func testAnimationModuleKeyframeScaleDrivesBothAxes() {
        XCTAssertEqual(
            AnimationModule.keyPaths(forKeyframeProperty: "scale"),
            ["transform.scale.x", "transform.scale.y"],
            "a uniform 'scale' keyframe should animate both the x and y scale axes"
        )
    }

    func testAnimationModuleKeyframeScaleXIsXAxisOnly() {
        XCTAssertEqual(AnimationModule.keyPaths(forKeyframeProperty: "scaleX"), ["transform.scale.x"])
    }

    func testAnimationModuleKeyframeScaleYIsYAxisOnly() {
        XCTAssertEqual(AnimationModule.keyPaths(forKeyframeProperty: "scaleY"), ["transform.scale.y"])
    }

    func testAnimationModuleKeyframeUnknownPropertyReturnsNil() {
        XCTAssertNil(AnimationModule.keyPaths(forKeyframeProperty: "unknownProp"), "an unrecognized keyframe property should not produce an animation")
    }
}
