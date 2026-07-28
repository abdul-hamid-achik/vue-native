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

    func testApplyPlaybackActionFiresPlayAndPauseEvents() {
        let factory = VVideoFactory()
        let view = factory.createView()
        guard let container = view as? VideoContainerView else {
            return XCTFail("VVideoFactory.createView() should return a VideoContainerView")
        }

        var playCount = 0
        var pauseCount = 0
        factory.addEventListener(view: view, event: "play") { _ in playCount += 1 }
        factory.addEventListener(view: view, event: "pause") { _ in pauseCount += 1 }

        factory.applyPlaybackAction(.play, to: container)
        XCTAssertEqual(playCount, 1, "a play action should fire the play event")
        XCTAssertEqual(pauseCount, 0, "a play action should not fire the pause event")

        factory.applyPlaybackAction(.pause, to: container)
        XCTAssertEqual(pauseCount, 1, "a pause action should fire the pause event")
        XCTAssertEqual(playCount, 1, "a pause action should not fire the play event")

        factory.applyPlaybackAction(.none, to: container)
        XCTAssertEqual(playCount, 1, "a none action should not fire any playback event")
        XCTAssertEqual(pauseCount, 1, "a none action should not fire any playback event")
    }
}
#endif
