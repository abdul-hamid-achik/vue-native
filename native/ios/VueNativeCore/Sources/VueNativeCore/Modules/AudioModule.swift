#if canImport(UIKit)
import UIKit
import AVFoundation

/// Native module for audio playback and recording.
///
/// Methods:
///   - play(uri: String, options?: Object)  -- play audio from URI. Options: volume (0–1),
///                                             loop (Bool), rate (0.5–2.0, 1.0 = normal speed).
///                                             Resolves `{ cancelled: true }` when a later
///                                             play()/stop() superseded it before it started.
///   - pause()                              -- pause playback
///   - resume()                             -- resume playback
///   - stop()                               -- stop playback and release player
///   - seek(position: Number)               -- seek to position in seconds
///   - setVolume(volume: Number)            -- set volume 0.0–1.0
///   - startRecording(options?: Object)     -- start audio recording
///   - stopRecording()                      -- stop recording, returns { uri, duration }
///   - pauseRecording()                     -- pause recording
///   - resumeRecording()                    -- resume recording
///   - getStatus()                          -- returns current playback status
///
/// Events (via bridge.dispatchGlobalEvent):
///   - audio:progress { currentTime, duration }
///   - audio:complete {}
///   - audio:error { message }
///   - audio:recordingLevel { level, power, currentTime } -- ~12×/s while recording with
///     `startRecording({ metering: true })`; level is 0…1 (−50 dB…0 dB), power in dBFS
final class AudioModule: NSObject, NativeModule {
    let moduleName = "Audio"

    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var displayLink: CADisplayLink?
    private var isPlaying = false
    private weak var bridge: NativeBridge?

    /// Monotonic play generation. Bumped by `play()` and `stop()`; an asynchronous
    /// remote download only starts playback when the generation it was started in is
    /// still current, so a stopped or superseded clip never begins playing later.
    private var playToken = 0
    private var downloadTask: URLSessionDataTask?

    /// Test seam: observes every global event this module dispatches.
    var eventObserver: ((String, [String: Any]) -> Void)?

    private func emit(_ event: String, _ payload: [String: Any] = [:]) {
        eventObserver?(event, payload)
        DispatchQueue.main.async { [weak self] in
            self?.bridge?.dispatchGlobalEvent(event, payload: payload)
        }
    }

    /// Result for a play() that was superseded by a later play()/stop(). It resolves
    /// (instead of rejecting) so callers do not see an error for a clip they cancelled;
    /// the JS `useAudio().play` leaves its state untouched when it sees this.
    private static let cancelledResult: [String: Any] = ["cancelled": true]

    /// Reads the optional playback `rate` option, clamped to AVAudioPlayer's supported
    /// 0.5–2.0 range. `nil` when absent or not a number.
    static func playbackRate(from options: [String: Any]) -> Float? {
        guard let number = options["rate"] as? NSNumber else { return nil }
        let rate = number.floatValue
        guard rate.isFinite else { return nil }
        return min(2.0, max(0.5, rate))
    }

    init(bridge: NativeBridge) {
        self.bridge = bridge
        super.init()
    }

    // MARK: - Delegate to forward completion events
    private var playerDelegate: AudioPlayerDelegate?

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "play":
            let uri = args.first as? String ?? ""
            let options = (args.count > 1 ? args[1] as? [String: Any] : nil) ?? [:]
            play(uri: uri, options: options, callback: callback)

        case "pause":
            pause(callback: callback)

        case "resume":
            resume(callback: callback)

        case "stop":
            stop(callback: callback)

        case "seek":
            let position = (args.first as? Double) ?? (args.first as? Int).map(Double.init) ?? 0
            seek(position: position, callback: callback)

        case "setVolume":
            let volume = (args.first as? Double) ?? (args.first as? Int).map(Double.init) ?? 1.0
            setVolume(Float(volume), callback: callback)

        case "startRecording":
            let options = args.first as? [String: Any] ?? [:]
            startRecording(options: options, callback: callback)

        case "stopRecording":
            stopRecording(callback: callback)

        case "pauseRecording":
            pauseRecording(callback: callback)

        case "resumeRecording":
            resumeRecording(callback: callback)

        case "getStatus":
            getStatus(callback: callback)

        default:
            callback(nil, "AudioModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Playback

    private func play(uri: String, options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Supersede any earlier play(): cancel its download and invalidate its token.
            self.playToken += 1
            let token = self.playToken
            self.downloadTask?.cancel()
            self.downloadTask = nil

            // Stop any existing playback
            self.stopProgressReporting()
            self.player?.stop()
            self.player = nil
            self.playerDelegate = nil
            self.isPlaying = false

            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                self.fail("Failed to set audio session: \(error.localizedDescription)", callback: callback)
                return
            }

            guard let url = URL(string: uri) else {
                self.fail("Invalid audio URI: \(uri)", callback: callback)
                return
            }

            // Check if it's a remote URL — download first
            if url.scheme == "http" || url.scheme == "https" {
                self.downloadAndPlay(url: url, token: token, options: options, callback: callback)
            } else {
                self.playLocal(url: url, options: options, callback: callback)
            }
        }
    }

    /// Rejects a play() and tells JS (`audio:error`) so `isPlaying` is reset: the
    /// previous player was already stopped when this is reached.
    private func fail(_ message: String, callback: @escaping (Any?, String?) -> Void) {
        callback(nil, message)
        emit("audio:error", ["message": message])
    }

    private func downloadAndPlay(url: URL, token: Int, options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        let task = CertificatePinning.shared.requestSession.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // A later play()/stop() owns the player now: drop this result.
                guard self.playToken == token else {
                    callback(AudioModule.cancelledResult, nil)
                    return
                }
                self.downloadTask = nil
                if let error = error {
                    self.fail("Failed to download audio: \(error.localizedDescription)", callback: callback)
                    return
                }
                guard let data = data else {
                    self.fail("No audio data received", callback: callback)
                    return
                }
                do {
                    let player = try AVAudioPlayer(data: data)
                    self.setupPlayer(player, options: options, callback: callback)
                } catch {
                    self.fail("Failed to initialize player: \(error.localizedDescription)", callback: callback)
                }
            }
        }
        downloadTask = task
        task.resume()
    }

    private func playLocal(url: URL, options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            setupPlayer(player, options: options, callback: callback)
        } catch {
            fail("Failed to play audio: \(error.localizedDescription)", callback: callback)
        }
    }

    private func setupPlayer(_ player: AVAudioPlayer, options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        let volume = Float(options["volume"] as? Double ?? 1.0)
        let loop = options["loop"] as? Bool ?? false

        player.volume = volume
        player.numberOfLoops = loop ? -1 : 0
        if let rate = AudioModule.playbackRate(from: options) {
            // enableRate must be set before prepareToPlay() for the rate to take effect.
            player.enableRate = true
            player.rate = rate
        }

        let delegate = AudioPlayerDelegate { [weak self] _ in
            guard let self = self else { return }
            self.isPlaying = false
            self.stopProgressReporting()
            DispatchQueue.main.async { [weak self] in
                self?.bridge?.dispatchGlobalEvent("audio:complete", payload: [:])
            }
        }
        player.delegate = delegate
        self.playerDelegate = delegate
        self.player = player

        player.prepareToPlay()
        player.play()
        self.isPlaying = true
        self.startProgressReporting()

        callback([
            "duration": player.duration,
            "currentTime": 0.0,
        ], nil)
    }

    private func pause(callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.player?.pause()
            self?.isPlaying = false
            self?.stopProgressReporting()
            callback(nil, nil)
        }
    }

    private func resume(callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.player?.play()
            self.isPlaying = true
            self.startProgressReporting()
            callback(nil, nil)
        }
    }

    private func stop(callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Invalidate any in-flight download so it can not start playing later.
            self.playToken += 1
            self.downloadTask?.cancel()
            self.downloadTask = nil
            self.player?.stop()
            self.player = nil
            self.playerDelegate = nil
            self.isPlaying = false
            self.stopProgressReporting()
            callback(nil, nil)
        }
    }

    private func seek(position: Double, callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.player?.currentTime = position
            callback(nil, nil)
        }
    }

    private func setVolume(_ volume: Float, callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.player?.volume = max(0, min(1, volume))
            callback(nil, nil)
        }
    }

    // MARK: - Progress Reporting

    private func startProgressReporting() {
        stopProgressReporting()
        let link = CADisplayLink(target: self, selector: #selector(reportProgress))
        // Report at ~4 Hz (every 15 frames at 60fps)
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 4, maximum: 4, preferred: 4)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopProgressReporting() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func reportProgress() {
        guard player != nil, isPlaying else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let player = self.player else { return }
            self.bridge?.dispatchGlobalEvent("audio:progress", payload: [
                "currentTime": player.currentTime,
                "duration": player.duration,
            ])
        }
    }

    // MARK: - Recording

    private func startRecording(options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            do {
                // defaultToSpeaker: playAndRecord otherwise routes playback to the earpiece,
                // so everything played after a recording became nearly inaudible.
                try AVAudioSession.sharedInstance().setCategory(
                    .playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                callback(nil, "Failed to set audio session for recording: \(error.localizedDescription)")
                return
            }

            let quality = options["quality"] as? String ?? "medium"
            let format = options["format"] as? String ?? "m4a"

            let ext = format == "wav" ? "wav" : "m4a"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".\(ext)")

            var settings: [String: Any] = [:]
            if format == "wav" {
                settings = [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVSampleRateKey: quality == "high" ? 44100.0 : 22050.0,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                ]
            } else {
                let sampleRate: Double
                let bitRate: Int
                switch quality {
                case "low":  sampleRate = 22050; bitRate = 32000
                case "high": sampleRate = 44100; bitRate = 128000
                default:     sampleRate = 44100; bitRate = 64000
                }
                settings = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: sampleRate,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
                    AVEncoderBitRateKey: bitRate,
                ]
            }

            do {
                let recorder = try AVAudioRecorder(url: url, settings: settings)
                let metering = options["metering"] as? Bool ?? false
                recorder.isMeteringEnabled = metering
                recorder.prepareToRecord()
                recorder.record()
                self.recorder = recorder
                if metering { self.startMetering() }
                callback(["uri": url.absoluteString], nil)
            } catch {
                callback(nil, "Failed to start recording: \(error.localizedDescription)")
            }
        }
    }

    private func stopRecording(callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let recorder = self.recorder else {
                callback(nil, "No active recording")
                return
            }
            let duration = recorder.currentTime
            let uri = recorder.url.absoluteString
            self.stopMetering()
            recorder.stop()
            self.recorder = nil
            // Back to playback-only so later clips use the normal (speaker) route.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            callback(["uri": uri, "duration": duration], nil)
        }
    }

    /// Normalized input level: −50 dBFS (silence) … 0 dBFS (loud) → 0…1.
    static func normalizedLevel(power: Float) -> Double {
        let floor: Float = -50
        guard power.isFinite else { return 0 }
        return Double(max(0, min(1, (power - floor) / -floor)))
    }

    private func startMetering() {
        stopMetering()
        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder, recorder.isRecording else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0)
            self.bridge?.dispatchGlobalEvent("audio:recordingLevel", payload: [
                "level": Self.normalizedLevel(power: power),
                "power": Double(power.isFinite ? power : -160),
                "currentTime": recorder.currentTime,
            ])
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func pauseRecording(callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.recorder?.pause()
            callback(nil, nil)
        }
    }

    private func resumeRecording(callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            self?.recorder?.record()
            callback(nil, nil)
        }
    }

    // MARK: - Status

    private func getStatus(callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { callback(nil, nil); return }
            var status: [String: Any] = [
                "isPlaying": self.isPlaying,
                "isRecording": self.recorder?.isRecording ?? false,
            ]
            if let player = self.player {
                status["currentTime"] = player.currentTime
                status["duration"] = player.duration
                status["volume"] = player.volume
            }
            callback(status, nil)
        }
    }

    func destroy() {
        let cleanup = {
            self.stopProgressReporting()
            self.player?.stop()
            self.player?.delegate = nil
            self.player = nil
            self.playerDelegate = nil
            self.stopMetering()
            self.recorder?.stop()
            self.recorder = nil
            self.isPlaying = false
            try? AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        }

        if Thread.isMainThread {
            cleanup()
        } else {
            DispatchQueue.main.sync(execute: cleanup)
        }
    }
}

// MARK: - AVAudioPlayerDelegate wrapper

private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onComplete: (Bool) -> Void

    init(onComplete: @escaping (Bool) -> Void) {
        self.onComplete = onComplete
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onComplete(flag)
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        // Treat decode error as completion failure
        onComplete(false)
    }
}
#endif
