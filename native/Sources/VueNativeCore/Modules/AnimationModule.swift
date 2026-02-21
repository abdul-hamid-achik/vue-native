#if canImport(UIKit)
import UIKit

/// Native module for UIView animations.
/// Exposes timing, spring, keyframe, sequence, and parallel animations to JS composables.
final class AnimationModule: NativeModule {

    let moduleName = "Animation"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "timing":
            handleTiming(args: args, callback: callback)
        case "spring":
            handleSpring(args: args, callback: callback)
        case "keyframe":
            guard let viewId = args[safe: 0] as? Int,
                  let keyframesData = args[safe: 1] as? [[String: Any]],
                  let options = args[safe: 2] as? [String: Any] else {
                callback(nil, "Invalid args"); return
            }
            let duration = options["duration"] as? Double ?? 300
            animateKeyframes(viewId: viewId, keyframes: keyframesData, duration: duration / 1000.0, callback: callback)
        case "sequence":
            guard let animationsData = args[safe: 0] as? [[String: Any]] else {
                callback(nil, "Invalid args"); return
            }
            runSequence(animationsData: animationsData, index: 0, callback: callback)
        case "parallel":
            guard let animationsData = args[safe: 0] as? [[String: Any]] else {
                callback(nil, "Invalid args"); return
            }
            runParallel(animationsData: animationsData, callback: callback)
        default:
            callback(nil, "AnimationModule: unknown method '\(method)'")
        }
    }

    func invokeSync(method: String, args: [Any]) -> Any? {
        return nil
    }

    // MARK: - timing(viewId, styles, options)
    // args[0]: Int (viewId)
    // args[1]: [String: Any] (target styles, only numeric values like opacity, transform offsets)
    // args[2]: [String: Any] (options: duration, delay, easing)

    private func handleTiming(args: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let viewId = args.first.flatMap({ $0 as? Int ?? ($0 as? Double).map(Int.init) }),
              let styles = args.count > 1 ? args[1] as? [String: Any] : [:] else {
            callback(nil, "timing: invalid arguments")
            return
        }

        let options = args.count > 2 ? (args[2] as? [String: Any] ?? [:]) : [:]
        let duration = (options["duration"] as? Double ?? 300) / 1000.0
        let delay = (options["delay"] as? Double ?? 0) / 1000.0
        let easing = options["easing"] as? String ?? "ease"

        let curve: UIView.AnimationOptions
        switch easing {
        case "linear": curve = .curveLinear
        case "ease-in", "easeIn": curve = .curveEaseIn
        case "ease-out", "easeOut": curve = .curveEaseOut
        default: curve = .curveEaseInOut
        }

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let view = NativeBridge.shared.view(forId: viewId) else {
                    callback(nil, "timing: view \(viewId) not found")
                    return
                }

                UIView.animate(
                    withDuration: duration,
                    delay: delay,
                    options: [curve],
                    animations: { [styles] in
                        MainActor.assumeIsolated {
                            for (key, value) in styles {
                                StyleEngine.apply(key: key, value: value, to: view)
                            }
                        }
                    },
                    completion: { _ in
                        callback(true, nil)
                    }
                )
            }
        }
    }

    // MARK: - spring(viewId, styles, options)
    // args[0]: Int (viewId)
    // args[1]: [String: Any] (target styles)
    // args[2]: [String: Any] (options: damping, stiffness/duration, mass)

    private func handleSpring(args: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let viewId = args.first.flatMap({ $0 as? Int ?? ($0 as? Double).map(Int.init) }),
              let styles = args.count > 1 ? args[1] as? [String: Any] : [:] else {
            callback(nil, "spring: invalid arguments")
            return
        }

        let options = args.count > 2 ? (args[2] as? [String: Any] ?? [:]) : [:]
        let damping = CGFloat(options["damping"] as? Double ?? 0.7)
        let duration = (options["duration"] as? Double ?? 500) / 1000.0
        let delay = (options["delay"] as? Double ?? 0) / 1000.0

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let view = NativeBridge.shared.view(forId: viewId) else {
                    callback(nil, "spring: view \(viewId) not found")
                    return
                }

                UIView.animate(
                    withDuration: duration,
                    delay: delay,
                    usingSpringWithDamping: damping,
                    initialSpringVelocity: 0,
                    options: [],
                    animations: { [styles] in
                        MainActor.assumeIsolated {
                            for (key, value) in styles {
                                StyleEngine.apply(key: key, value: value, to: view)
                            }
                        }
                    },
                    completion: { _ in
                        callback(true, nil)
                    }
                )
            }
        }
    }

    // MARK: - keyframe(viewId, keyframes, options)

    private func animateKeyframes(viewId: Int, keyframes: [[String: Any]], duration: TimeInterval, callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            guard let view = NativeBridge.shared.view(forId: viewId) else {
                callback(nil, "View not found for id \(viewId)"); return
            }

            // Build CAKeyframeAnimation for each animated property
            // Group them with CAAnimationGroup
            let group = CAAnimationGroup()
            group.duration = duration
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false

            var animations: [CAAnimation] = []

            // Collect all property names from keyframes
            var propertyKeys = Set<String>()
            for kf in keyframes { propertyKeys.formUnion(kf.keys.filter { $0 != "offset" }) }

            for propKey in propertyKeys {
                let keyPath: String
                var values: [Any] = []
                var keyTimes: [NSNumber] = []

                switch propKey {
                case "opacity":
                    keyPath = "opacity"
                    for kf in keyframes {
                        if let v = kf[propKey] as? Double {
                            values.append(v)
                            keyTimes.append(NSNumber(value: kf["offset"] as? Double ?? 0))
                        }
                    }
                case "translateX":
                    keyPath = "transform.translation.x"
                    for kf in keyframes {
                        if let v = kf[propKey] as? Double {
                            values.append(v)
                            keyTimes.append(NSNumber(value: kf["offset"] as? Double ?? 0))
                        }
                    }
                case "translateY":
                    keyPath = "transform.translation.y"
                    for kf in keyframes {
                        if let v = kf[propKey] as? Double {
                            values.append(v)
                            keyTimes.append(NSNumber(value: kf["offset"] as? Double ?? 0))
                        }
                    }
                case "scale", "scaleX":
                    keyPath = "transform.scale.x"
                    for kf in keyframes {
                        if let v = kf[propKey] as? Double {
                            values.append(v)
                            keyTimes.append(NSNumber(value: kf["offset"] as? Double ?? 0))
                        }
                    }
                case "scaleY":
                    keyPath = "transform.scale.y"
                    for kf in keyframes {
                        if let v = kf[propKey] as? Double {
                            values.append(v)
                            keyTimes.append(NSNumber(value: kf["offset"] as? Double ?? 0))
                        }
                    }
                default:
                    continue
                }

                if !values.isEmpty {
                    let anim = CAKeyframeAnimation(keyPath: keyPath)
                    anim.values = values
                    anim.keyTimes = keyTimes
                    anim.duration = duration
                    animations.append(anim)
                }
            }

            if animations.isEmpty { callback(nil, nil); return }
            group.animations = animations

            CATransaction.begin()
            CATransaction.setCompletionBlock { callback(nil, nil) }
            view.layer.add(group, forKey: "keyframeAnimation")
            CATransaction.commit()
        }
    }

    // MARK: - sequence([animData])

    private func runSequence(animationsData: [[String: Any]], index: Int, callback: @escaping (Any?, String?) -> Void) {
        guard index < animationsData.count else { callback(nil, nil); return }
        let animData = animationsData[index]
        let method = animData["type"] as? String ?? "timing"
        let viewId = animData["viewId"] as? Int ?? 0
        let toStyles = animData["toStyles"] as? [String: Any] ?? [:]
        let options = animData["options"] as? [String: Any] ?? [:]

        runSingleAnimation(method: method, viewId: viewId, toStyles: toStyles, options: options) { [weak self] _, error in
            if let error = error { callback(nil, error); return }
            self?.runSequence(animationsData: animationsData, index: index + 1, callback: callback)
        }
    }

    private func runSingleAnimation(method: String, viewId: Int, toStyles: [String: Any], options: [String: Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "timing":
            let argsArr: [Any] = [viewId, toStyles, options]
            invoke(method: "timing", args: argsArr, callback: callback)
        case "spring":
            let argsArr: [Any] = [viewId, toStyles, options]
            invoke(method: "spring", args: argsArr, callback: callback)
        default:
            callback(nil, "Unknown animation type: \(method)")
        }
    }

    // MARK: - parallel([animData])

    private func runParallel(animationsData: [[String: Any]], callback: @escaping (Any?, String?) -> Void) {
        guard !animationsData.isEmpty else { callback(nil, nil); return }
        let total = animationsData.count
        var completed = 0
        let lock = NSLock()

        for animData in animationsData {
            let method = animData["type"] as? String ?? "timing"
            let viewId = animData["viewId"] as? Int ?? 0
            let toStyles = animData["toStyles"] as? [String: Any] ?? [:]
            let options = animData["options"] as? [String: Any] ?? [:]

            runSingleAnimation(method: method, viewId: viewId, toStyles: toStyles, options: options) { _, _ in
                lock.lock()
                completed += 1
                let allDone = completed == total
                lock.unlock()
                if allDone { callback(nil, nil) }
            }
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}
#endif
