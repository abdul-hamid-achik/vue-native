import Foundation
import AVFoundation

/// Native module for audio playback and recording.
/// Uses AVFoundation which is available on both iOS and macOS.
///
/// Methods:
///   - play(uri: String, options?: Object)  -- play audio from URI
///   - pause()                              -- pause playback
///   - resume()                             -- resume playback
///   - stop()                               -- stop playback and release player
///   - seek(position: Number)               -- seek to position in seconds
///   - setVolume(volume: Number)            -- set volume 0.0-1.0
///   - startRecording(options?: Object)     -- start audio recording
///   - stopRecording()                      -- stop recording, returns { uri, duration }
///   - pauseRecording()                     -- pause recording
///   - resumeRecording()                    -- resume recording
///   - getStatus()                          -- returns current playback status
///
/// Events (via eventDispatcher.dispatchGlobalEvent):
///   - audio:progress { currentTime, duration }
///   - audio:complete {}
///   - audio:error { message }
public final class AudioModule: NSObject, NativeModule {
    public let moduleName = "Audio"

    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var progressTimer: Timer?
    private var isPlaying = false
    private weak var eventDispatcher: NativeEventDispatcher?

    // MARK: - Delegate to forward completion events
    private var playerDelegate: AudioPlayerDelegateImpl?

    public init(eventDispatcher: NativeEventDispatcher) {
        self.eventDispatcher = eventDispatcher
        super.init()
    }

    public func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
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

            // Stop any existing playback
            self.stopProgressReporting()
            self.player?.stop()

            guard let url = URL(string: uri) else {
                callback(nil, "Invalid audio URI: \(uri)")
                return
            }

            // Check if it's a remote URL — download first
            if url.scheme == "http" || url.scheme == "https" {
                self.downloadAndPlay(url: url, options: options, callback: callback)
            } else {
                self.playLocal(url: url, options: options, callback: callback)
            }
        }
    }

    private func downloadAndPlay(url: URL, options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    callback(nil, "Failed to download audio: \(error.localizedDescription)")
                    self.eventDispatcher?.dispatchGlobalEvent("audio:error", payload: ["message": error.localizedDescription])
                    return
                }
                guard let data = data else {
                    callback(nil, "No audio data received")
                    return
                }
                do {
                    let player = try AVAudioPlayer(data: data)
                    self.setupPlayer(player, options: options, callback: callback)
                } catch {
                    callback(nil, "Failed to initialize player: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    private func playLocal(url: URL, options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            setupPlayer(player, options: options, callback: callback)
        } catch {
            callback(nil, "Failed to play audio: \(error.localizedDescription)")
        }
    }

    private func setupPlayer(_ player: AVAudioPlayer, options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        let volume = Float(options["volume"] as? Double ?? 1.0)
        let loop = options["loop"] as? Bool ?? false

        player.volume = volume
        player.numberOfLoops = loop ? -1 : 0

        let delegate = AudioPlayerDelegateImpl { [weak self] successfully in
            guard let self = self else { return }
            self.isPlaying = false
            self.stopProgressReporting()
            DispatchQueue.main.async { [weak self] in
                self?.eventDispatcher?.dispatchGlobalEvent("audio:complete", payload: [:])
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

    // MARK: - Progress Reporting (Timer-based, cross-platform)

    private func startProgressReporting() {
        stopProgressReporting()
        // Report at ~4 Hz using a Timer (cross-platform, no CADisplayLink dependency)
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.reportProgress()
        }
        RunLoop.main.add(progressTimer!, forMode: .common)
    }

    private func stopProgressReporting() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func reportProgress() {
        guard player != nil, isPlaying else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let player = self.player else { return }
            self.eventDispatcher?.dispatchGlobalEvent("audio:progress", payload: [
                "currentTime": player.currentTime,
                "duration": player.duration,
            ])
        }
    }

    // MARK: - Recording

    private func startRecording(options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

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
                recorder.prepareToRecord()
                recorder.record()
                self.recorder = recorder
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
            recorder.stop()
            self.recorder = nil
            callback(["uri": uri, "duration": duration], nil)
        }
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
}

// MARK: - AVAudioPlayerDelegate wrapper

private final class AudioPlayerDelegateImpl: NSObject, AVAudioPlayerDelegate {
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
