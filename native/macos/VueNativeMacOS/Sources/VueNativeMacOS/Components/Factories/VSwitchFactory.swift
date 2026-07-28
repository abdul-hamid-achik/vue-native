import AppKit
import ObjectiveC

/// Factory for VSwitch — the boolean toggle switch component.
/// Maps to NSSwitch (macOS 10.15+) with a LayoutNode.
/// Supports v-model via the `value` prop and `change` event.
final class VSwitchFactory: NativeComponentFactory {

    private static var changeHandlerKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let sw = NSSwitch()
        sw.wantsLayer = true
        sw.ensureLayoutNode()
        return sw
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let sw = view as? NSSwitch else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "value":
            let newValue: NSControl.StateValue
            if let val = value as? Bool {
                newValue = val ? .on : .off
            } else if let val = value as? Int {
                newValue = val != 0 ? .on : .off
            } else {
                newValue = .off
            }
            if sw.state != newValue {
                sw.state = newValue
            }

        case "disabled":
            if let disabled = value as? Bool {
                sw.isEnabled = !disabled
            } else if let disabled = value as? Int {
                sw.isEnabled = disabled == 0
            } else {
                sw.isEnabled = true
            }

        case "onTintColor":
            // NSSwitch is not an NSButton and exposes no public API to tint the
            // on-state track (NSButton.contentTintColor does not apply here). We
            // accept and store the value for cross-platform parity and inspection
            // rather than silently dropping it, and warn in DEBUG.
            if let colorStr = value as? String, NSColor.fromHex(colorStr) != nil {
                StyleEngine.setInternalPropDirect("__onTintColor", value: colorStr, on: view)
                #if DEBUG
                NSLog("[VueNative macOS] VSwitch: 'onTintColor' (\(colorStr)) is stored but NSSwitch has no public track-tint API")
                #endif
            } else {
                StyleEngine.setInternalPropDirect("__onTintColor", value: nil, on: view)
            }

        case "thumbColor", "thumbTintColor":
            // NSSwitch has no public API to color the thumb independently of the
            // track. Store the value for parity/inspection and warn in DEBUG.
            if let colorStr = value as? String, NSColor.fromHex(colorStr) != nil {
                StyleEngine.setInternalPropDirect("__thumbColor", value: colorStr, on: view)
                #if DEBUG
                NSLog("[VueNative macOS] VSwitch: 'thumbColor' (\(colorStr)) is not independently customizable on NSSwitch; AppKit tints the whole control via contentTintColor")
                #endif
            } else {
                StyleEngine.setInternalPropDirect("__thumbColor", value: nil, on: view)
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let sw = view as? NSSwitch, event == "change" else { return }

        let proxy = SwitchActionProxy(handler: handler)
        sw.target = proxy
        sw.action = #selector(SwitchActionProxy.valueChanged(_:))
        objc_setAssociatedObject(
            sw,
            &VSwitchFactory.changeHandlerKey,
            proxy,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    func removeEventListener(view: NSView, event: String) {
        guard let sw = view as? NSSwitch, event == "change" else { return }

        sw.target = nil
        sw.action = nil
        objc_setAssociatedObject(sw, &VSwitchFactory.changeHandlerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - SwitchActionProxy

/// Target-action proxy that routes NSSwitch value changes to a closure handler.
/// Stored as an associated object on the NSSwitch.
final class SwitchActionProxy: NSObject {

    let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
    }

    @objc func valueChanged(_ sender: NSSwitch) {
        handler(sender.state == .on)
    }
}
