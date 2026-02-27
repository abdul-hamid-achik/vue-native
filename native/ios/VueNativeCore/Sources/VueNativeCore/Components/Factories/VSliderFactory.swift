#if canImport(UIKit)
import UIKit
import FlexLayout
import ObjectiveC

/// Factory for VSlider — maps to UISlider.
final class VSliderFactory: NativeComponentFactory {

    private static var onChangeKey: UInt8 = 0

    func createView() -> UIView {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        _ = slider.flex
        return slider
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let slider = view as? UISlider else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }
        switch key {
        case "value":
            slider.value = Float(value as? Double ?? Double(value as? Float ?? 0))
        case "minimumValue", "min":
            slider.minimumValue = Float(value as? Double ?? 0)
        case "maximumValue", "max":
            slider.maximumValue = Float(value as? Double ?? 1)
        case "minimumTrackTintColor":
            slider.minimumTrackTintColor = UIColor.fromHex(value as? String ?? "")
        case "maximumTrackTintColor":
            slider.maximumTrackTintColor = UIColor.fromHex(value as? String ?? "")
        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard event == "change", let slider = view as? UISlider else { return }
        let target = SliderTarget(handler: handler)
        slider.addTarget(target, action: #selector(SliderTarget.handleValueChanged(_:)), for: .valueChanged)
        objc_setAssociatedObject(slider, &VSliderFactory.onChangeKey, target, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func removeEventListener(view: UIView, event: String) {
        guard event == "change", let slider = view as? UISlider else { return }
        if let target = objc_getAssociatedObject(slider, &VSliderFactory.onChangeKey) as? SliderTarget {
            slider.removeTarget(target, action: #selector(SliderTarget.handleValueChanged(_:)), for: .valueChanged)
        }
        objc_setAssociatedObject(slider, &VSliderFactory.onChangeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

/// Throttled target for UISlider .valueChanged events.
/// Limits bridge round-trips to ~60/s during continuous slider dragging.
private final class SliderTarget: NSObject {
    private let throttle: EventThrottle
    init(handler: @escaping (Any?) -> Void) {
        self.throttle = EventThrottle(interval: 0.016, handler: handler)
        super.init()
    }
    @objc func handleValueChanged(_ slider: UISlider) {
        throttle.fire(["value": Double(slider.value)])
    }
}
#endif
