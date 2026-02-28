import AppKit
import ObjectiveC

/// Factory for VSlider — a continuous slider control.
/// Maps to NSSlider with throttled change events (~60fps).
final class VSliderFactory: NativeComponentFactory {

    private static var changeHandlerKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let slider = NSSlider()
        slider.isContinuous = true
        slider.minValue = 0
        slider.maxValue = 1
        slider.doubleValue = 0
        slider.wantsLayer = true
        slider.ensureLayoutNode()
        return slider
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let slider = view as? NSSlider else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "value":
            if let val = value as? Double {
                if slider.doubleValue != val {
                    slider.doubleValue = val
                }
            } else if let val = value as? Int {
                slider.doubleValue = Double(val)
            }

        case "minimumValue", "min":
            if let val = value as? Double {
                slider.minValue = val
            } else if let val = value as? Int {
                slider.minValue = Double(val)
            }

        case "maximumValue", "max":
            if let val = value as? Double {
                slider.maxValue = val
            } else if let val = value as? Int {
                slider.maxValue = Double(val)
            }

        case "minimumTrackTintColor":
            if #available(macOS 14.0, *) {
                if let colorStr = value as? String {
                    slider.trackFillColor = NSColor.fromHex(colorStr)
                } else {
                    slider.trackFillColor = nil
                }
            }

        case "maximumTrackTintColor":
            // No direct NSSlider API for max track color
            break

        case "disabled":
            if let disabled = value as? Bool {
                slider.isEnabled = !disabled
            } else if let disabled = value as? Int {
                slider.isEnabled = disabled == 0
            } else {
                slider.isEnabled = true
            }

        case "enabled":
            if let enabled = value as? Bool {
                slider.isEnabled = enabled
            } else if let enabled = value as? Int {
                slider.isEnabled = enabled != 0
            } else {
                slider.isEnabled = true
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let slider = view as? NSSlider, event == "change" else { return }

        let throttle = EventThrottle { payload in
            handler(payload)
        }
        let proxy = SliderActionProxy(slider: slider, throttle: throttle)
        slider.target = proxy
        slider.action = #selector(SliderActionProxy.valueChanged(_:))
        objc_setAssociatedObject(
            slider,
            &VSliderFactory.changeHandlerKey,
            proxy,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    func removeEventListener(view: NSView, event: String) {
        guard let slider = view as? NSSlider, event == "change" else { return }

        slider.target = nil
        slider.action = nil
        objc_setAssociatedObject(slider, &VSliderFactory.changeHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - SliderActionProxy

/// Target-action proxy that routes NSSlider value changes through an EventThrottle.
final class SliderActionProxy: NSObject {

    private weak var slider: NSSlider?
    private let throttle: EventThrottle

    init(slider: NSSlider, throttle: EventThrottle) {
        self.slider = slider
        self.throttle = throttle
    }

    @objc func valueChanged(_ sender: NSSlider) {
        throttle.fire(["value": sender.doubleValue])
    }
}
