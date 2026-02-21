#if canImport(UIKit)
import UIKit
import FlexLayout
import ObjectiveC

private var segOnChangeKey: UInt8 = 0
private var segTargetKey: UInt8 = 1

final class VSegmentedControlFactory: NativeComponentFactory {

    func createView() -> UIView {
        let seg = UISegmentedControl()
        _ = seg.flex
        return seg
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let seg = view as? UISegmentedControl else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }
        switch key {
        case "values":
            guard let items = value as? [String] else { return }
            seg.removeAllSegments()
            for (i, item) in items.enumerated() {
                seg.insertSegment(withTitle: item, at: i, animated: false)
            }
        case "selectedIndex":
            let idx = (value as? Int) ?? (value as? NSNumber)?.intValue ?? 0
            seg.selectedSegmentIndex = idx
        case "tintColor":
            if let str = value as? String { seg.selectedSegmentTintColor = UIColor.fromHex(str) }
        case "enabled":
            seg.isEnabled = (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? true
        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard event == "change", let seg = view as? UISegmentedControl else { return }
        objc_setAssociatedObject(view, &segOnChangeKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        let target = SegmentedTarget(view: view)
        objc_setAssociatedObject(view, &segTargetKey, target, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        seg.addTarget(target, action: #selector(SegmentedTarget.handleChange(_:)), for: .valueChanged)
    }

    func removeEventListener(view: UIView, event: String) {
        if event == "change" {
            objc_setAssociatedObject(view, &segOnChangeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private final class SegmentedTarget: NSObject {
    private weak var view: UIView?
    init(view: UIView) { self.view = view }

    @objc func handleChange(_ seg: UISegmentedControl) {
        guard let view = view else { return }
        if let handler = objc_getAssociatedObject(view, &segOnChangeKey) as? ((Any?) -> Void) {
            handler(["selectedIndex": seg.selectedSegmentIndex, "value": seg.titleForSegment(at: seg.selectedSegmentIndex) ?? ""])
        }
    }
}
#endif
