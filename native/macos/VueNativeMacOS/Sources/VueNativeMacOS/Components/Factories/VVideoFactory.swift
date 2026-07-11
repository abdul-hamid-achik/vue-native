import AppKit
import AVFoundation
import AVKit
import ObjectiveC

// File-level keys used in non-isolated contexts (e.g. deinit).
nonisolated(unsafe) private var _timeObserverKey: UInt8 = 7
nonisolated(unsafe) private var _endObserverKey: UInt8 = 9

enum VideoPlaybackAction: Equatable {
    case none
    case play
    case pause
}

struct VideoPlaybackState {
    private(set) var autoplay = false
    private(set) var paused = false
    private(set) var isReady = false
    private(set) var volume: Float = 1
    private(set) var muted = false
    private(set) var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    mutating func updateAutoplay(_ value: Bool) -> VideoPlaybackAction {
        autoplay = value
        return isReady && autoplay && !paused ? .play : .none
    }

    mutating func updatePaused(_ value: Bool) -> VideoPlaybackAction {
        paused = value
        guard isReady else { return .none }
        return paused ? .pause : .play
    }

    mutating func didBecomeReady() -> VideoPlaybackAction {
        isReady = true
        return autoplay && !paused ? .play : .none
    }

    mutating func resetForSource() {
        isReady = false
    }

    mutating func updateVolume(_ value: Float) {
        volume = max(0, min(1, value))
    }

    mutating func updateMuted(_ value: Bool) {
        muted = value
    }

    mutating func updateVideoGravity(_ value: AVLayerVideoGravity) {
        videoGravity = value
    }
}

/// Factory for VVideo — video playback via AVPlayer + AVPlayerLayer on macOS.
final class VVideoFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    nonisolated(unsafe) private static var onReadyKey: UInt8 = 0
    nonisolated(unsafe) private static var onPlayKey: UInt8 = 1
    nonisolated(unsafe) private static var onPauseKey: UInt8 = 2
    nonisolated(unsafe) private static var onEndKey: UInt8 = 3
    nonisolated(unsafe) private static var onErrorKey: UInt8 = 4
    nonisolated(unsafe) private static var onProgressKey: UInt8 = 5
    nonisolated(unsafe) private static var playerKey: UInt8 = 6
    nonisolated(unsafe) private static var statusObserverKey: UInt8 = 8

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let view = VideoContainerView()
        view.wantsLayer = true
        view.ensureLayoutNode()
        return view
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let container = view as? VideoContainerView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "source":
            if let sourceDict = value as? [String: Any],
               let uriString = sourceDict["uri"] as? String,
               let url = URL(string: uriString) {
                setupPlayer(url: url, in: container)
            } else {
                cleanupPlayer(for: container)
            }

        case "uri":
            if let uriString = value as? String, let url = URL(string: uriString) {
                setupPlayer(url: url, in: container)
            } else {
                cleanupPlayer(for: container)
            }

        case "autoplay":
            let action = container.playbackState.updateAutoplay(value as? Bool ?? false)
            applyPlaybackAction(action, to: container)

        case "paused":
            let action = container.playbackState.updatePaused(value as? Bool ?? false)
            applyPlaybackAction(action, to: container)

        case "muted":
            container.playbackState.updateMuted(value as? Bool ?? false)
            applyAudioState(to: container)

        case "volume":
            if let vol = value as? Double {
                container.playbackState.updateVolume(Float(vol))
                applyAudioState(to: container)
            } else if let vol = value as? Int {
                container.playbackState.updateVolume(Float(vol))
                applyAudioState(to: container)
            }

        case "repeat", "loop":
            container.loop = value as? Bool ?? false

        case "resizeMode":
            let gravity: AVLayerVideoGravity
            switch value as? String {
            case "contain": gravity = .resizeAspect
            case "stretch": gravity = .resize
            case "center":  gravity = .resizeAspect
            default:        gravity = .resizeAspectFill // "cover"
            }
            container.playbackState.updateVideoGravity(gravity)
            applyVideoGravity(to: container)

        case "rate":
            if let rate = value as? Double {
                container.player?.rate = Float(rate)
            } else if let rate = value as? Int {
                container.player?.rate = Float(rate)
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        let keyPtr: UnsafeRawPointer
        switch event {
        case "ready":    keyPtr = UnsafeRawPointer(&VVideoFactory.onReadyKey)
        case "play":     keyPtr = UnsafeRawPointer(&VVideoFactory.onPlayKey)
        case "pause":    keyPtr = UnsafeRawPointer(&VVideoFactory.onPauseKey)
        case "end":      keyPtr = UnsafeRawPointer(&VVideoFactory.onEndKey)
        case "error":    keyPtr = UnsafeRawPointer(&VVideoFactory.onErrorKey)
        case "progress": keyPtr = UnsafeRawPointer(&VVideoFactory.onProgressKey)
        default: return
        }
        objc_setAssociatedObject(view, keyPtr, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func removeEventListener(view: NSView, event: String) {
        let keyPtr: UnsafeRawPointer
        switch event {
        case "ready":    keyPtr = UnsafeRawPointer(&VVideoFactory.onReadyKey)
        case "play":     keyPtr = UnsafeRawPointer(&VVideoFactory.onPlayKey)
        case "pause":    keyPtr = UnsafeRawPointer(&VVideoFactory.onPauseKey)
        case "end":      keyPtr = UnsafeRawPointer(&VVideoFactory.onEndKey)
        case "error":    keyPtr = UnsafeRawPointer(&VVideoFactory.onErrorKey)
        case "progress": keyPtr = UnsafeRawPointer(&VVideoFactory.onProgressKey)
        default: return
        }
        objc_setAssociatedObject(view, keyPtr, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func destroyView(view: NSView) {
        guard let container = view as? VideoContainerView else { return }
        cleanupPlayer(for: container)
        clearEventHandlers(for: container)
    }

    // MARK: - Player setup

    private func setupPlayer(url: URL, in container: VideoContainerView) {
        cleanupPlayer(for: container)

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        container.player = player
        applyAudioState(to: container)

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = container.playbackState.videoGravity
        playerLayer.frame = container.bounds
        container.layer?.addSublayer(playerLayer)
        container.playerLayer = playerLayer

        // Observe item status for ready/error
        let statusObserver = playerItem.observe(\.status, options: [.new]) { [weak container, weak player] item, _ in
            DispatchQueue.main.async { [weak container, weak player] in
                guard let container,
                      let player,
                      container.player === player,
                      player.currentItem === item else { return }
                switch item.status {
                case .readyToPlay:
                    let action = container.playbackState.didBecomeReady()
                    let duration = CMTimeGetSeconds(item.duration)
                    VVideoFactory.fireEvent(
                        for: container,
                        key: &VVideoFactory.onReadyKey,
                        payload: ["duration": duration.isFinite ? duration : 0]
                    )
                    VVideoFactory.applyPlaybackAction(action, to: container)
                case .failed:
                    container.playbackState.resetForSource()
                    let message = item.error?.localizedDescription ?? "Unknown playback error"
                    VVideoFactory.fireEvent(
                        for: container,
                        key: &VVideoFactory.onErrorKey,
                        payload: ["message": message]
                    )
                default:
                    break
                }
            }
        }
        objc_setAssociatedObject(container, &VVideoFactory.statusObserverKey, statusObserver, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Periodic time observer for progress
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak container, weak player] time in
            guard let container,
                  let player,
                  container.player === player,
                  let duration = player.currentItem?.duration else { return }
            let currentTime = CMTimeGetSeconds(time)
            let dur = CMTimeGetSeconds(duration)
            if currentTime.isFinite && dur.isFinite {
                VVideoFactory.fireEvent(
                    for: container,
                    key: &VVideoFactory.onProgressKey,
                    payload: ["currentTime": currentTime, "duration": dur]
                )
            }
        }
        objc_setAssociatedObject(container, &_timeObserverKey, timeObserver as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // End-of-playback observer
        let endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak container, weak player, weak playerItem] notification in
            guard let container,
                  let player,
                  let playerItem,
                  container.player === player,
                  player.currentItem === playerItem,
                  notification.object as AnyObject? === playerItem else { return }
            VVideoFactory.fireEvent(for: container, key: &VVideoFactory.onEndKey, payload: nil)
            if container.loop && !container.playbackState.paused {
                container.player?.seek(to: .zero)
                container.player?.play()
            }
        }
        objc_setAssociatedObject(container, &_endObserverKey, endObserver as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func cleanupPlayer(for container: VideoContainerView) {
        container.playbackState.resetForSource()

        // Remove time observer
        if let timeObserver = objc_getAssociatedObject(container, &_timeObserverKey) {
            container.player?.removeTimeObserver(timeObserver)
            objc_setAssociatedObject(container, &_timeObserverKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        // Remove end observer
        if let endObserver = objc_getAssociatedObject(container, &_endObserverKey) {
            NotificationCenter.default.removeObserver(endObserver)
            objc_setAssociatedObject(container, &_endObserverKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        // Remove status observer
        objc_setAssociatedObject(container, &VVideoFactory.statusObserverKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        container.player?.pause()
        container.player = nil
        container.playerLayer?.removeFromSuperlayer()
        container.playerLayer = nil
    }

    private static func applyPlaybackAction(
        _ action: VideoPlaybackAction,
        to container: VideoContainerView
    ) {
        switch action {
        case .none:
            break
        case .play:
            container.player?.play()
        case .pause:
            container.player?.pause()
        }
    }

    private func applyPlaybackAction(_ action: VideoPlaybackAction, to container: VideoContainerView) {
        Self.applyPlaybackAction(action, to: container)
    }

    private func applyAudioState(to container: VideoContainerView) {
        container.player?.volume = container.playbackState.volume
        container.player?.isMuted = container.playbackState.muted
    }

    private func applyVideoGravity(to container: VideoContainerView) {
        container.playerLayer?.videoGravity = container.playbackState.videoGravity
    }

    private func clearEventHandlers(for container: VideoContainerView) {
        for event in ["ready", "play", "pause", "end", "error", "progress"] {
            removeEventListener(view: container, event: event)
        }
    }

    nonisolated private static func fireEvent(for view: NSView, key: inout UInt8, payload: Any?) {
        if let handler = objc_getAssociatedObject(view, &key) as? ((Any?) -> Void) {
            handler(payload)
        }
    }
}

// MARK: - VideoContainerView

/// Custom NSView that holds AVPlayerLayer and resizes it on layout.
private class VideoContainerView: FlippedView {
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var playbackState = VideoPlaybackState()
    var loop: Bool = false

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }

    deinit {
        // Clean up player resources
        if let timeObserver = objc_getAssociatedObject(self, &_timeObserverKey) {
            player?.removeTimeObserver(timeObserver)
        }
        if let endObserver = objc_getAssociatedObject(self, &_endObserverKey) {
            NotificationCenter.default.removeObserver(endObserver)
        }
        player?.pause()
        player = nil
        playerLayer?.removeFromSuperlayer()
    }
}
