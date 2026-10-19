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
        case "measureView":
            guard let viewId = args.first.flatMap({ $0 as? Int ?? ($0 as? Double).map(Int.init) }) else {
                callback(nil, "measureView: invalid view ID")
                return
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let view = NativeBridge.shared.view(forId: viewId) else {
                        callback(nil, "measureView: view \(viewId) not found")
                        return
                    }
                    let frame = view.convert(view.bounds, to: view.window)
                    callback([
                        "x": frame.origin.x,
                        "y": frame.origin.y,
                        "width": frame.size.width,
                        "height": frame.size.height,
                    ], nil)
                }
            }
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
                    options: AnimationModule.interactiveOptions.union(curve),
                    animations: { [styles] in
                        MainActor.assumeIsolated {
                            AnimationModule.applyAnimatedStyles(styles, to: view)
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
                    options: AnimationModule.interactiveOptions,
                    animations: { [styles] in
                        MainActor.assumeIsolated {
                            AnimationModule.applyAnimatedStyles(styles, to: view)
                        }
                    },
                    completion: { _ in
                        callback(true, nil)
                    }
                )
            }
        }
    }

    // MARK: - Animated style application

    /// Options shared by timing and spring animations.
    /// - `.allowUserInteraction`: the view stays tappable while it animates (without it
    ///   UIKit disables hit testing on the animating view for the whole duration).
    /// - `.beginFromCurrentState`: an animation started while another one is running on
    ///   the same view continues from the on-screen (presentation) value instead of
    ///   snapping to the model value first, and does not wait for the earlier one.
    static let interactiveOptions: UIView.AnimationOptions = [.allowUserInteraction, .beginFromCurrentState]

    /// Style keys that are not StyleEngine keys: StyleEngine only reads translate/scale
    /// inside its `transform` list, so these are applied here through `view.transform`.
    private static let transformKeys: Set<String> = ["translateX", "translateY", "scale", "scaleX", "scaleY"]

    /// Applies animatable styles inside an animation block. Regular keys (`opacity`,
    /// `backgroundColor`, ...) go through `StyleEngine`; `translateX`, `translateY`,
    /// `scale`, `scaleX` and `scaleY` are composed into `view.transform`. Any of the
    /// transform components that is not specified keeps its current value.
    @MainActor
    static func applyAnimatedStyles(_ styles: [String: Any], to view: UIView) {
        for (key, value) in styles where !transformKeys.contains(key) {
            StyleEngine.apply(key: key, value: value, to: view)
        }
        guard styles.keys.contains(where: transformKeys.contains) else { return }

        let uniformScale = number(styles["scale"])
        view.transform = composedTransform(
            from: view.transform,
            translateX: number(styles["translateX"]),
            translateY: number(styles["translateY"]),
            scaleX: number(styles["scaleX"]) ?? uniformScale,
            scaleY: number(styles["scaleY"]) ?? uniformScale
        )
    }

    /// Returns `current` with the given components replaced; `nil` components are kept.
    /// Translation is replaced directly. Scale is replaced per axis by rescaling the
    /// matrix columns, so a rotation already present in `current` is preserved.
    static func composedTransform(
        from current: CGAffineTransform,
        translateX: CGFloat?,
        translateY: CGFloat?,
        scaleX: CGFloat?,
        scaleY: CGFloat?
    ) -> CGAffineTransform {
        var result = current
        if let translateX { result.tx = translateX }
        if let translateY { result.ty = translateY }
        if let scaleX {
            let currentX = hypot(current.a, current.b)
            if currentX > 0 {
                result.a = current.a / currentX * scaleX
                result.b = current.b / currentX * scaleX
            } else {
                result.a = scaleX
                result.b = 0
            }
        }
        if let scaleY {
            let currentY = hypot(current.c, current.d)
            if currentY > 0 {
                result.c = current.c / currentY * scaleY
                result.d = current.d / currentY * scaleY
            } else {
                result.c = 0
                result.d = scaleY
            }
        }
        return result
    }

    private static func number(_ value: Any?) -> CGFloat? {
        guard let number = value as? NSNumber else { return nil }
        return CGFloat(number.doubleValue)
    }

    // MARK: - keyframe(viewId, keyframes, options)

    /// Maps a keyframe animation property name to the CALayer key path(s) it
    /// drives. `nil` for an unrecognized property. Exposed (internal, not
    /// private) so the mapping — in particular that `"scale"` drives both
    /// axes uniformly instead of stretching the view on the x axis only —
    /// can be unit tested without spinning up a live view/animation.
    static func keyPaths(forKeyframeProperty propKey: String) -> [String]? {
        switch propKey {
        case "opacity": return ["opacity"]
        case "translateX": return ["transform.translation.x"]
        case "translateY": return ["transform.translation.y"]
        case "scale": return ["transform.scale.x", "transform.scale.y"]
        case "scaleX": return ["transform.scale.x"]
        case "scaleY": return ["transform.scale.y"]
        default: return nil
        }
    }

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
                guard let keyPaths = AnimationModule.keyPaths(forKeyframeProperty: propKey) else { continue }

                var values: [Any] = []
                var keyTimes: [NSNumber] = []
                for kf in keyframes {
                    if let v = kf[propKey] as? Double {
                        values.append(v)
                        keyTimes.append(NSNumber(value: kf["offset"] as? Double ?? 0))
                    }
                }
                guard !values.isEmpty else { continue }

                for keyPath in keyPaths {
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

#endif
