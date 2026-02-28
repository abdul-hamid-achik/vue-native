import AppKit
import AVFoundation
import AVKit
import ObjectiveC

// File-level keys used in non-isolated contexts (e.g. deinit).
private nonisolated(unsafe) var _timeObserverKey: UInt8 = 7
private nonisolated(unsafe) var _endObserverKey: UInt8 = 9

/// Factory for VVideo — video playback via AVPlayer + AVPlayerLayer on macOS.
final class VVideoFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var onReadyKey: UInt8 = 0
    private static var onPlayKey: UInt8 = 1
    private static var onPauseKey: UInt8 = 2
    private static var onEndKey: UInt8 = 3
    private static var onErrorKey: UInt8 = 4
    private static var onProgressKey: UInt8 = 5
    private static var playerKey: UInt8 = 6
    private static var statusObserverKey: UInt8 = 8

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

        case "paused":
            let paused = value as? Bool ?? false
            if paused {
                container.player?.pause()
            } else {
                container.player?.play()
            }

        case "muted":
            container.player?.isMuted = value as? Bool ?? false

        case "volume":
            if let vol = value as? Double {
                container.player?.volume = Float(max(0, min(1, vol)))
            } else if let vol = value as? Int {
                container.player?.volume = Float(max(0, min(1, Double(vol))))
            }

        case "repeat", "loop":
            container.loop = value as? Bool ?? false

        case "resizeMode":
            let gravity: AVLayerVideoGravity
            switch value as? String {
            case "contain": gravity = .resizeAspect
            case "stretch": gravity = .resize
            default:        gravity = .resizeAspectFill // "cover"
            }
            container.playerLayer?.videoGravity = gravity

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

    // MARK: - Player setup

    private func setupPlayer(url: URL, in container: VideoContainerView) {
        cleanupPlayer(for: container)

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        container.player = player

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = container.bounds
        container.layer?.addSublayer(playerLayer)
        container.playerLayer = playerLayer

        // Observe item status for ready/error
        let statusObserver = playerItem.observe(\.status, options: [.new]) { [weak container] item, _ in
            DispatchQueue.main.async {
                guard let container = container else { return }
                switch item.status {
                case .readyToPlay:
                    let duration = CMTimeGetSeconds(item.duration)
                    self.fireEvent(for: container, key: &VVideoFactory.onReadyKey,
                                   payload: ["duration": duration.isFinite ? duration : 0])
                case .failed:
                    let message = item.error?.localizedDescription ?? "Unknown playback error"
                    self.fireEvent(for: container, key: &VVideoFactory.onErrorKey,
                                   payload: ["message": message])
                default:
                    break
                }
            }
        }
        objc_setAssociatedObject(container, &VVideoFactory.statusObserverKey, statusObserver, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Periodic time observer for progress
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak container] time in
            guard let container = container,
                  let duration = container.player?.currentItem?.duration else { return }
            let currentTime = CMTimeGetSeconds(time)
            let dur = CMTimeGetSeconds(duration)
            if currentTime.isFinite && dur.isFinite {
                self.fireEvent(for: container, key: &VVideoFactory.onProgressKey,
                               payload: ["currentTime": currentTime, "duration": dur])
            }
        }
        objc_setAssociatedObject(container, &_timeObserverKey, timeObserver as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // End-of-playback observer
        let endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak container] _ in
            guard let container = container else { return }
            self.fireEvent(for: container, key: &VVideoFactory.onEndKey, payload: nil)
            if container.loop {
                container.player?.seek(to: .zero)
                container.player?.play()
            }
        }
        objc_setAssociatedObject(container, &_endObserverKey, endObserver as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func cleanupPlayer(for container: VideoContainerView) {
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

    private func fireEvent(for view: NSView, key: inout UInt8, payload: Any?) {
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
