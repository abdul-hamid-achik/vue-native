#if canImport(UIKit)
import UIKit
import AVFoundation
import AVKit
import FlexLayout
import ObjectiveC

/// Factory for VVideo — the video playback component.
/// Uses AVPlayer + AVPlayerLayer for inline video playback.
final class VVideoFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var onReadyKey: UInt8 = 0
    private static var onPlayKey: UInt8 = 1
    private static var onPauseKey: UInt8 = 2
    private static var onEndKey: UInt8 = 3
    private static var onErrorKey: UInt8 = 4
    private static var onProgressKey: UInt8 = 5
    private static var playerKey: UInt8 = 6
    private static var timeObserverKey: UInt8 = 7
    private static var statusObserverKey: UInt8 = 8
    private static var endObserverKey: UInt8 = 9

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let view = VideoContainerView()
        _ = view.flex
        view.clipsToBounds = true
        return view
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let container = view as? VideoContainerView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "source":
            guard let sourceDict = value as? [String: Any],
                  let uriString = sourceDict["uri"] as? String,
                  let url = URL(string: uriString) else {
                cleanupPlayer(for: container)
                return
            }
            setupPlayer(url: url, in: container)

        case "autoplay":
            // Handled during source setup; store as flag
            container.autoplay = value as? Bool ?? false

        case "loop":
            container.loop = value as? Bool ?? false

        case "muted":
            let muted = value as? Bool ?? false
            container.player?.isMuted = muted

        case "paused":
            let paused = value as? Bool ?? false
            if paused {
                container.player?.pause()
            } else {
                container.player?.play()
            }

        case "controls":
            // For inline playback we don't show native controls
            // This is a placeholder for future AVPlayerViewController integration
            break

        case "resizeMode":
            let gravity: AVLayerVideoGravity
            switch value as? String {
            case "contain": gravity = .resizeAspect
            case "stretch": gravity = .resize
            case "center":  gravity = .resizeAspect
            default:        gravity = .resizeAspectFill // "cover"
            }
            container.playerLayer?.videoGravity = gravity

        case "volume":
            if let vol = value as? Double {
                container.player?.volume = Float(max(0, min(1, vol)))
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
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

    func removeEventListener(view: UIView, event: String) {
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
        container.layer.addSublayer(playerLayer)
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
                    if container.autoplay {
                        container.player?.play()
                    }
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
        objc_setAssociatedObject(container, &VVideoFactory.timeObserverKey, timeObserver as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // End observer
        let endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndOfTime,
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
        objc_setAssociatedObject(container, &VVideoFactory.endObserverKey, endObserver as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func cleanupPlayer(for container: VideoContainerView) {
        // Remove time observer
        if let timeObserver = objc_getAssociatedObject(container, &VVideoFactory.timeObserverKey) {
            container.player?.removeTimeObserver(timeObserver)
            objc_setAssociatedObject(container, &VVideoFactory.timeObserverKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        // Remove end observer
        if let endObserver = objc_getAssociatedObject(container, &VVideoFactory.endObserverKey) {
            NotificationCenter.default.removeObserver(endObserver)
            objc_setAssociatedObject(container, &VVideoFactory.endObserverKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        // Remove status observer
        objc_setAssociatedObject(container, &VVideoFactory.statusObserverKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        container.player?.pause()
        container.player = nil
        container.playerLayer?.removeFromSuperlayer()
        container.playerLayer = nil
    }

    private func fireEvent(for view: UIView, key: inout UInt8, payload: Any?) {
        if let handler = objc_getAssociatedObject(view, &key) as? ((Any?) -> Void) {
            handler(payload)
        }
    }
}

// MARK: - VideoContainerView

/// Custom UIView that holds AVPlayerLayer and resizes it on layout.
private class VideoContainerView: UIView {
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var autoplay: Bool = false
    var loop: Bool = false

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    deinit {
        // Clean up player resources
        if let timeObserver = objc_getAssociatedObject(self, &VVideoFactory.timeObserverKey) {
            player?.removeTimeObserver(timeObserver)
        }
        if let endObserver = objc_getAssociatedObject(self, &VVideoFactory.endObserverKey) {
            NotificationCenter.default.removeObserver(endObserver)
        }
        player?.pause()
        player = nil
        playerLayer?.removeFromSuperlayer()
    }
}
#endif
