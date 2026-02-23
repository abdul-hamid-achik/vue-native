#if canImport(UIKit)
import UIKit
import FlexLayout
import ObjectiveC

private var pickerOnChangeKey: UInt8 = 0
private var pickerItemsKey: UInt8 = 1
private var pickerDelegateKey: UInt8 = 2

/// Factory for VPicker.
/// Modes: "selector" (UIPickerView), "date", "time", "datetime" (UIDatePicker)
final class VPickerFactory: NativeComponentFactory {

    func createView() -> UIView {
        // Default: UIDatePicker (most common on mobile)
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        if #available(iOS 14.0, *) {
            picker.preferredDatePickerStyle = .compact
        }
        _ = picker.flex
        return picker
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        switch key {
        case "mode":
            guard let modeStr = value as? String else { return }
            // If we have a UIDatePicker, set its mode
            if let datePicker = view as? UIDatePicker {
                switch modeStr {
                case "date":     datePicker.datePickerMode = .date
                case "time":     datePicker.datePickerMode = .time
                case "datetime": datePicker.datePickerMode = .dateAndTime
                default: break
                }
            }
        case "value":
            if let datePicker = view as? UIDatePicker {
                if let ms = (value as? Double) ?? (value as? NSNumber)?.doubleValue {
                    datePicker.date = Date(timeIntervalSince1970: ms / 1000.0)
                }
            }
        case "minimumDate":
            if let datePicker = view as? UIDatePicker,
               let ms = (value as? Double) ?? (value as? NSNumber)?.doubleValue {
                datePicker.minimumDate = Date(timeIntervalSince1970: ms / 1000.0)
            }
        case "maximumDate":
            if let datePicker = view as? UIDatePicker,
               let ms = (value as? Double) ?? (value as? NSNumber)?.doubleValue {
                datePicker.maximumDate = Date(timeIntervalSince1970: ms / 1000.0)
            }
        case "minuteInterval":
            if let datePicker = view as? UIDatePicker,
               let interval = (value as? Int) ?? (value as? NSNumber)?.intValue {
                datePicker.minuteInterval = interval
            }
        case "items":
            // UIPickerView items — not using UIPickerView in this simplified version
            objc_setAssociatedObject(view, &pickerItemsKey, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        if event == "change" {
            objc_setAssociatedObject(view, &pickerOnChangeKey, handler as AnyObject, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            if let datePicker = view as? UIDatePicker {
                let target = PickerChangeTarget(view: view)
                objc_setAssociatedObject(view, &pickerDelegateKey, target, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                datePicker.addTarget(target, action: #selector(PickerChangeTarget.handleChange(_:)), for: .valueChanged)
            }
        }
    }

    func removeEventListener(view: UIView, event: String) {
        if event == "change" {
            objc_setAssociatedObject(view, &pickerOnChangeKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private final class PickerChangeTarget: NSObject {
    private weak var view: UIView?
    init(view: UIView) { self.view = view }

    @objc func handleChange(_ picker: UIDatePicker) {
        guard let view = view else { return }
        if let handler = objc_getAssociatedObject(view, &pickerOnChangeKey) as? ((Any?) -> Void) {
            handler(["value": picker.date.timeIntervalSince1970 * 1000.0])
        }
    }
}
#endif
