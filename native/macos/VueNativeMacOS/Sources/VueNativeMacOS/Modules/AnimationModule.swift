import AppKit
import VueNativeShared

/// Native module for NSView animations.
/// Exposes timing, spring, keyframe, sequence, and parallel animations to JS composables.
final class AnimationModule: NativeModule {

    let moduleName = "Animation"
    private let viewLookup: (Int) -> NSView?

    init(viewLookup: @escaping (Int) -> NSView?) {
        self.viewLookup = viewLookup
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "timing":
            handleTiming(args: args, callback: callback)
        case "spring":
            handleSpring(args: args, callback: callback)
        case "keyframe":
            guard args.count >= 3,
                  let viewId = coerceInt(args[0]),
                  let keyframesData = args[1] as? [[String: Any]],
                  let options = args[2] as? [String: Any] else {
                callback(nil, "Invalid args"); return
            }
            let duration = (options["duration"] as? Double ?? 300) / 1000.0
            animateKeyframes(viewId: viewId, keyframes: keyframesData, duration: duration, callback: callback)
        case "sequence":
            guard let animationsData = args.first as? [[String: Any]] else {
                callback(nil, "Invalid args"); return
            }
            runSequence(animationsData: animationsData, index: 0, callback: callback)
        case "parallel":
            guard let animationsData = args.first as? [[String: Any]] else {
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

    private func handleTiming(args: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let viewId = args.first.flatMap({ coerceInt($0) }) else {
            callback(nil, "timing: invalid arguments")
            return
        }

        let styles = args.count > 1 ? (args[1] as? [String: Any] ?? [:]) : [:]
        let options = args.count > 2 ? (args[2] as? [String: Any] ?? [:]) : [:]
        let duration = (options["duration"] as? Double ?? 300) / 1000.0
        let easing = options["easing"] as? String ?? "ease"

        let timingFunction: CAMediaTimingFunction
        switch easing {
        case "linear": timingFunction = CAMediaTimingFunction(name: .linear)
        case "ease-in", "easeIn": timingFunction = CAMediaTimingFunction(name: .easeIn)
        case "ease-out", "easeOut": timingFunction = CAMediaTimingFunction(name: .easeOut)
        default: timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        }

        DispatchQueue.main.async { [weak self] in
            guard let view = self?.viewLookup(viewId) else {
                callback(nil, "timing: view \(viewId) not found")
                return
            }

            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = duration
                ctx.timingFunction = timingFunction
                ctx.allowsImplicitAnimation = true

                for (key, value) in styles {
                    self?.applyAnimatableStyle(key: key, value: value, to: view)
                }
                view.layoutSubtreeIfNeeded()
            }, completionHandler: {
                callback(nil, nil)
            })
        }
    }

    // MARK: - spring(viewId, styles, options)

    private func handleSpring(args: [Any], callback: @escaping (Any?, String?) -> Void) {
        guard let viewId = args.first.flatMap({ coerceInt($0) }) else {
            callback(nil, "spring: invalid arguments")
            return
        }

        let styles = args.count > 1 ? (args[1] as? [String: Any] ?? [:]) : [:]
        let options = args.count > 2 ? (args[2] as? [String: Any] ?? [:]) : [:]
        let duration = (options["duration"] as? Double ?? 500) / 1000.0
        let damping = CGFloat(options["damping"] as? Double ?? 0.7)

        DispatchQueue.main.async { [weak self] in
            guard let view = self?.viewLookup(viewId) else {
                callback(nil, "spring: view \(viewId) not found")
                return
            }

            // Use CASpringAnimation for true spring physics
            let springAnim = CASpringAnimation(keyPath: "transform")
            springAnim.damping = damping * 20 // scale to CA range
            springAnim.duration = duration
            springAnim.isRemovedOnCompletion = false
            springAnim.fillMode = .forwards

            // Fall back to NSAnimationContext for property changes
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = duration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                ctx.allowsImplicitAnimation = true

                for (key, value) in styles {
                    self?.applyAnimatableStyle(key: key, value: value, to: view)
                }
                view.layoutSubtreeIfNeeded()
            }, completionHandler: {
                callback(nil, nil)
            })
        }
    }

    // MARK: - keyframe(viewId, keyframes, options)

    private func animateKeyframes(viewId: Int, keyframes: [[String: Any]], duration: TimeInterval, callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let view = self?.viewLookup(viewId) else {
                callback(nil, "View not found for id \(viewId)"); return
            }

            guard let layer = view.layer else {
                callback(nil, "View has no layer"); return
            }

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
            layer.add(group, forKey: "keyframeAnimation")
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
            invoke(method: "timing", args: [viewId, toStyles, options], callback: callback)
        case "spring":
            invoke(method: "spring", args: [viewId, toStyles, options], callback: callback)
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

    // MARK: - Helpers

    private func coerceInt(_ value: Any) -> Int? {
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        return nil
    }

    /// Apply an animatable style property to an NSView.
    /// For full style application, the bridge's StyleEngine should be used;
    /// this handles the common animatable subset.
    private func applyAnimatableStyle(key: String, value: Any?, to view: NSView) {
        guard let layer = view.layer else { return }
        switch key {
        case "opacity":
            if let v = value as? Double {
                view.alphaValue = CGFloat(v)
            }
        case "backgroundColor":
            if let hex = value as? String {
                layer.backgroundColor = NSColor.fromHex(hex)?.cgColor
            }
        case "translateX":
            if let v = value as? Double {
                var transform = view.layer?.affineTransform() ?? .identity
                transform.tx = CGFloat(v)
                view.layer?.setAffineTransform(transform)
            }
        case "translateY":
            if let v = value as? Double {
                var transform = view.layer?.affineTransform() ?? .identity
                transform.ty = CGFloat(v)
                view.layer?.setAffineTransform(transform)
            }
        case "scale":
            if let v = value as? Double {
                let cv = CGFloat(v)
                view.layer?.setAffineTransform(CGAffineTransform(scaleX: cv, y: cv))
            }
        case "borderRadius":
            if let v = value as? Double {
                layer.cornerRadius = CGFloat(v)
            }
        default:
            break
        }
    }
}

// MARK: - NSColor hex helper

private extension NSColor {
    static func fromHex(_ hex: String) -> NSColor? {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") { hexString.removeFirst() }

        var rgb: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgb) else { return nil }

        switch hexString.count {
        case 6:
            return NSColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                blue: CGFloat(rgb & 0xFF) / 255.0,
                alpha: 1.0
            )
        case 8:
            return NSColor(
                red: CGFloat((rgb >> 24) & 0xFF) / 255.0,
                green: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                blue: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                alpha: CGFloat(rgb & 0xFF) / 255.0
            )
        default:
            return nil
        }
    }
}
