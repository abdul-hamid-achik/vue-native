#if canImport(UIKit)
import AVFoundation
import XCTest
@testable import VueNativeCore

@MainActor
final class VVideoCleanupTests: XCTestCase {
    func testPlaybackStateDoesNotTreatDefaultPausedFalseAsAutoplay() {
        var state = VideoPlaybackState()

        XCTAssertEqual(state.updatePaused(false), .none)
        XCTAssertEqual(state.didBecomeReady(), .none)
    }

    func testPlaybackStateHonorsAutoplayAndPausedAtReadiness() {
        var autoplaying = VideoPlaybackState()
        XCTAssertEqual(autoplaying.updateAutoplay(true), .none)
        XCTAssertEqual(autoplaying.didBecomeReady(), .play)

        var blocked = VideoPlaybackState()
        XCTAssertEqual(blocked.updateAutoplay(true), .none)
        XCTAssertEqual(blocked.updatePaused(true), .none)
        XCTAssertEqual(blocked.didBecomeReady(), .none)
    }

    func testPlaybackStateAppliesPausedChangesOnlyAfterReadiness() {
        var state = VideoPlaybackState()

        XCTAssertEqual(state.updatePaused(true), .none)
        XCTAssertEqual(state.updatePaused(false), .none)
        XCTAssertEqual(state.didBecomeReady(), .none)
        XCTAssertEqual(state.updatePaused(false), .play)
        XCTAssertEqual(state.updatePaused(true), .pause)

        state.resetForSource()
        XCTAssertEqual(state.updatePaused(false), .none)
    }

    func testPlaybackStateRetainsAudioAndPresentationSettingsAcrossSources() {
        var state = VideoPlaybackState()

        state.updateVolume(0.35)
        state.updateMuted(true)
        state.updateVideoGravity(.resizeAspect)
        state.resetForSource()

        XCTAssertEqual(state.volume, 0.35, accuracy: 0.001)
        XCTAssertTrue(state.muted)
        XCTAssertEqual(state.videoGravity, .resizeAspect)
    }

    func testDestroyViewTwiceRemovesPlayerLayerWithoutLoadingMedia() {
        let factory = VVideoFactory()
        let view = factory.createView()
        let fileURL = URL(fileURLWithPath: "/tmp/vue-native-missing-video.mp4")
        factory.updateProp(view: view, key: "source", value: ["uri": fileURL.absoluteString])

        XCTAssertTrue(view.layer.sublayers?.contains(where: { $0 is AVPlayerLayer }) == true)

        factory.destroyView(view: view)
        factory.destroyView(view: view)

        XCTAssertFalse(view.layer.sublayers?.contains(where: { $0 is AVPlayerLayer }) == true)
    }
}
#endif
