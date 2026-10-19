#if canImport(UIKit)
import XCTest
import AVFoundation
@testable import VueNativeCore

/// An `AVAudioRecorder` whose start result is scripted, so the failure and success
/// paths of `startRecording` can be exercised without a microphone.
private final class ScriptedRecorder: AVAudioRecorder {
    var prepareResult = true
    var recordResult = true
    private(set) var stopCount = 0

    override func prepareToRecord() -> Bool { prepareResult }
    override func record() -> Bool { recordResult }
    override func stop() { stopCount += 1 }
}

private struct StubFailure: Error {}

final class AudioModuleRecordingTests: XCTestCase {
    private var module: AudioModule!
    private var factoryCalls = 0
    private var scripted: ScriptedRecorder?

    override func setUp() {
        super.setUp()
        module = AudioModule(bridge: NativeBridge.shared)
        factoryCalls = 0
        scripted = nil
        module.recorderFactory = { [unowned self] url, settings in
            self.factoryCalls += 1
            let recorder = try ScriptedRecorder(url: url, settings: settings)
            self.scripted = recorder
            return recorder
        }
    }

    override func tearDown() {
        module.destroy()
        module = nil
        super.tearDown()
    }

    private func startRecording(
        _ options: [String: Any] = [:], timeout: TimeInterval = 5
    ) -> (result: [String: Any]?, error: String?) {
        let done = expectation(description: "startRecording callback")
        var result: [String: Any]?
        var error: String?
        module.invoke(method: "startRecording", args: [options]) { value, message in
            result = value as? [String: Any]
            error = message
            done.fulfill()
        }
        wait(for: [done], timeout: timeout)
        return (result, error)
    }

    // MARK: - Permission

    func testDeniedPermissionRejectsWithoutCreatingARecorder() {
        module.microphoneStatus = { .denied }
        module.requestMicrophoneAccess = { _ in XCTFail("must not prompt when already denied") }

        let outcome = startRecording()

        XCTAssertNil(outcome.result)
        XCTAssertTrue(outcome.error?.hasPrefix(AudioModule.permissionDeniedCode) == true, outcome.error ?? "nil")
        XCTAssertEqual(factoryCalls, 0)
        XCTAssertFalse(module.isRecordingActive)
    }

    func testUndeterminedPermissionWaitsForTheAnswerBeforeRecording() {
        module.microphoneStatus = { .undetermined }
        var answer: ((Bool) -> Void)?
        module.requestMicrophoneAccess = { answer = $0 }

        let done = expectation(description: "startRecording callback")
        var result: [String: Any]?
        var error: String?
        module.invoke(method: "startRecording", args: [[String: Any]()]) { value, message in
            result = value as? [String: Any]
            error = message
            done.fulfill()
        }

        // The prompt is up: nothing may have started yet.
        let prompted = expectation(description: "prompt shown")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { prompted.fulfill() }
        wait(for: [prompted], timeout: 2)
        XCTAssertNotNil(answer)
        XCTAssertEqual(factoryCalls, 0)
        XCTAssertFalse(module.isRecordingActive)

        answer?(true)
        wait(for: [done], timeout: 5)
        XCTAssertNil(error)
        XCTAssertNotNil(result?["uri"])
        XCTAssertEqual(factoryCalls, 1)
        XCTAssertTrue(module.isRecordingActive)
    }

    func testUndeterminedPermissionThenDeniedRejects() {
        module.microphoneStatus = { .undetermined }
        module.requestMicrophoneAccess = { $0(false) }

        let outcome = startRecording()

        XCTAssertNil(outcome.result)
        XCTAssertTrue(outcome.error?.hasPrefix(AudioModule.permissionDeniedCode) == true, outcome.error ?? "nil")
        XCTAssertEqual(factoryCalls, 0)
        XCTAssertFalse(module.isRecordingActive)
    }

    // MARK: - Failed starts

    func testRecorderCreationFailureRejects() {
        module.microphoneStatus = { .granted }
        module.recorderFactory = { _, _ in throw StubFailure() }

        let outcome = startRecording()

        XCTAssertNil(outcome.result)
        XCTAssertTrue(outcome.error?.hasPrefix("Failed to start recording") == true, outcome.error ?? "nil")
        XCTAssertFalse(module.isRecordingActive)
    }

    func testRecordReturningFalseRejectsAndCleansUp() throws {
        module.microphoneStatus = { .granted }
        module.recorderFactory = { [unowned self] url, settings in
            let recorder = try ScriptedRecorder(url: url, settings: settings)
            recorder.recordResult = false
            self.scripted = recorder
            return recorder
        }

        let outcome = startRecording()

        XCTAssertNil(outcome.result)
        XCTAssertTrue(outcome.error?.hasPrefix("Failed to start recording") == true, outcome.error ?? "nil")
        XCTAssertFalse(module.isRecordingActive)
        XCTAssertEqual(try XCTUnwrap(scripted).stopCount, 1)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
    }

    func testPrepareToRecordReturningFalseRejectsAndCleansUp() throws {
        module.microphoneStatus = { .granted }
        module.recorderFactory = { [unowned self] url, settings in
            let recorder = try ScriptedRecorder(url: url, settings: settings)
            recorder.prepareResult = false
            self.scripted = recorder
            return recorder
        }

        let outcome = startRecording()

        XCTAssertNil(outcome.result)
        XCTAssertNotNil(outcome.error)
        XCTAssertFalse(module.isRecordingActive)
        XCTAssertEqual(try XCTUnwrap(scripted).stopCount, 1)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
    }

    // MARK: - play() during a recording

    func testPlaySessionConfigurationKeepsInputWhileRecording() {
        let recording = AudioModule.playSessionConfiguration(recording: true)
        XCTAssertEqual(recording.category, .playAndRecord)
        XCTAssertTrue(recording.options.contains(.defaultToSpeaker))

        let idle = AudioModule.playSessionConfiguration(recording: false)
        XCTAssertEqual(idle.category, .playback)
    }

    func testPlayDuringRecordingKeepsPlayAndRecordUntilStop() {
        module.microphoneStatus = { .granted }
        XCTAssertNotNil(startRecording().result)
        XCTAssertTrue(module.isRecordingActive)

        // The clip does not exist: play() still configures the session first, then fails.
        let played = expectation(description: "play callback")
        module.invoke(method: "play", args: ["file:///definitely/not/here.mp3"]) { _, _ in played.fulfill() }
        wait(for: [played], timeout: 5)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playAndRecord)
        XCTAssertTrue(AVAudioSession.sharedInstance().categoryOptions.contains(.defaultToSpeaker))
        XCTAssertTrue(module.isRecordingActive)

        let stopped = expectation(description: "stopRecording callback")
        module.invoke(method: "stopRecording", args: []) { _, _ in stopped.fulfill() }
        wait(for: [stopped], timeout: 5)
        XCTAssertFalse(module.isRecordingActive)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)

        // With no recording, play() is back to the playback category.
        let playedAgain = expectation(description: "play callback")
        module.invoke(method: "play", args: ["file:///definitely/not/here.mp3"]) { _, _ in playedAgain.fulfill() }
        wait(for: [playedAgain], timeout: 5)
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
    }
}
#endif
