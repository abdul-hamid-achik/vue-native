import AppKit
import ObjectiveC

/// Factory for VSegmentedControl — a segmented control for mutually exclusive choices.
/// Maps to NSSegmentedControl.
final class VSegmentedControlFactory: NativeComponentFactory {

    private static var changeHandlerKey: UInt8 = 0
    nonisolated(unsafe) static var valuesKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let control = NSSegmentedControl()
        control.segmentStyle = .rounded
        control.trackingMode = .selectOne
        control.wantsLayer = true
        control.ensureLayoutNode()
        return control
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let control = view as? NSSegmentedControl else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "values":
            if let labels = value as? [String] {
                control.segmentCount = labels.count
                for (i, label) in labels.enumerated() {
                    control.setLabel(label, forSegment: i)
                    control.setWidth(0, forSegment: i) // Auto-size
                }
                objc_setAssociatedObject(control, &VSegmentedControlFactory.valuesKey, labels, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }

        case "selectedIndex":
            if let idx = value as? Int {
                if idx >= 0 && idx < control.segmentCount {
                    control.selectedSegment = idx
                }
            } else if let idx = value as? Double {
                let i = Int(idx)
                if i >= 0 && i < control.segmentCount {
                    control.selectedSegment = i
                }
            }

        case "tintColor":
            if let colorStr = value as? String {
                if #available(macOS 10.14, *) {
                    control.selectedSegmentBezelColor = NSColor.fromHex(colorStr)
                }
            }

        case "enabled":
            if let enabled = value as? Bool {
                control.isEnabled = enabled
            } else {
                control.isEnabled = true
            }

        case "disabled":
            if let disabled = value as? Bool {
                control.isEnabled = !disabled
            } else if let disabled = value as? Int {
                control.isEnabled = disabled == 0
            } else {
                control.isEnabled = true
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let control = view as? NSSegmentedControl, event == "change" else { return }

        let proxy = SegmentedActionProxy(control: control, handler: handler)
        control.target = proxy
        control.action = #selector(SegmentedActionProxy.selectionChanged(_:))
        objc_setAssociatedObject(
            control,
            &VSegmentedControlFactory.changeHandlerKey,
            proxy,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    func removeEventListener(view: NSView, event: String) {
        guard let control = view as? NSSegmentedControl, event == "change" else { return }

        control.target = nil
        control.action = nil
        objc_setAssociatedObject(control, &VSegmentedControlFactory.changeHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - SegmentedActionProxy

/// Target-action proxy that routes NSSegmentedControl selection changes to a closure handler.
final class SegmentedActionProxy: NSObject {

    private weak var control: NSSegmentedControl?
    private let handler: (Any?) -> Void

    init(control: NSSegmentedControl, handler: @escaping (Any?) -> Void) {
        self.control = control
        self.handler = handler
    }

    @objc func selectionChanged(_ sender: NSSegmentedControl) {
        let index = sender.selectedSegment
        let labels = objc_getAssociatedObject(sender, &VSegmentedControlFactory.valuesKey) as? [String]
        let label = labels?[safe: index] ?? ""

        handler([
            "selectedIndex": index,
            "value": label
        ])
    }
}
