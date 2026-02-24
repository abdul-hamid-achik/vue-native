#if canImport(UIKit)
import UIKit
import AVFoundation

/// Native module for audio playback and recording.
///
/// Methods:
///   - play(uri: String, options?: Object)  -- play audio from URI
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
final class AudioModule: NativeModule {
    let moduleName = "Audio"

    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var displayLink: CADisplayLink?
    private var isPlaying = false
    private var bridge: NativeBridge? { NativeBridge.shared }

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

            // Stop any existing playback
            self.stopProgressReporting()
            self.player?.stop()

            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                callback(nil, "Failed to set audio session: \(error.localizedDescription)")
                return
            }

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
                    self.bridge?.dispatchGlobalEvent("audio:error", payload: ["message": error.localizedDescription])
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

        let delegate = AudioPlayerDelegate { [weak self] successfully in
            guard let self = self else { return }
            self.isPlaying = false
            self.stopProgressReporting()
            self.bridge?.dispatchGlobalEvent("audio:complete", payload: [:])
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
        guard let player = player, isPlaying else { return }
        bridge?.dispatchGlobalEvent("audio:progress", payload: [
            "currentTime": player.currentTime,
            "duration": player.duration,
        ])
    }

    // MARK: - Recording

    private func startRecording(options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
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
