import AppKit
import ObjectiveC

/// Factory for VPicker's public date/time API.
///
/// The TypeScript component exposes epoch-millisecond values and `date`,
/// `time`, and `datetime` modes. `NSDatePicker` maps directly to that contract;
/// the previous NSPopUpButton implementation used an unrelated items/index API
/// that was never part of the public VPicker surface.
final class VPickerFactory: NativeComponentFactory {

    nonisolated(unsafe) static var changeTargetKey: UInt8 = 0
    nonisolated(unsafe) static var minuteIntervalKey: UInt8 = 1
    nonisolated(unsafe) static var modeKey: UInt8 = 2

    func createView() -> NSView {
        let picker = NSDatePicker()
        picker.datePickerMode = .single
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay]
        picker.ensureLayoutNode()
        return picker
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let picker = view as? NSDatePicker else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "mode":
            let mode = value as? String ?? "date"
            configure(picker, for: mode)

        case "value":
            if let date = date(fromEpochMilliseconds: value) {
                picker.dateValue = normalized(date, for: picker)
            }

        case "minimumDate":
            picker.minDate = date(fromEpochMilliseconds: value)

        case "maximumDate":
            picker.maxDate = date(fromEpochMilliseconds: value)

        case "minuteInterval":
            let interval = max(1, min(60, intValue(value) ?? 1))
            objc_setAssociatedObject(
                picker,
                &VPickerFactory.minuteIntervalKey,
                NSNumber(value: interval),
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            picker.dateValue = normalized(picker.dateValue, for: picker)

        case "enabled":
            picker.isEnabled = boolValue(value, default: true)

        case "disabled":
            picker.isEnabled = !boolValue(value, default: false)

        default:
            StyleEngine.apply(key: key, value: value, to: picker)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard event == "change", let picker = view as? NSDatePicker else { return }

        let target = DatePickerActionTarget(picker: picker, handler: handler)
        picker.target = target
        picker.action = #selector(DatePickerActionTarget.selectionChanged(_:))
        objc_setAssociatedObject(
            picker,
            &VPickerFactory.changeTargetKey,
            target,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    func removeEventListener(view: NSView, event: String) {
        guard event == "change", let picker = view as? NSDatePicker else { return }
        picker.target = nil
        picker.action = nil
        objc_setAssociatedObject(picker, &VPickerFactory.changeTargetKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func configure(_ picker: NSDatePicker, for mode: String) {
        let resolvedMode: String
        switch mode {
        case "time":
            picker.datePickerElements = [.hourMinute]
            resolvedMode = "time"
        case "datetime":
            picker.datePickerElements = [.yearMonthDay, .hourMinute]
            resolvedMode = "datetime"
        default:
            picker.datePickerElements = [.yearMonthDay]
            resolvedMode = "date"
        }
        objc_setAssociatedObject(
            picker,
            &VPickerFactory.modeKey,
            resolvedMode as NSString,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        picker.dateValue = normalized(picker.dateValue, for: picker)
    }

    private func normalized(_ date: Date, for picker: NSDatePicker) -> Date {
        let mode = objc_getAssociatedObject(picker, &VPickerFactory.modeKey) as? String ?? "date"
        guard mode == "time" || mode == "datetime" else { return date }

        let interval = (objc_getAssociatedObject(
            picker,
            &VPickerFactory.minuteIntervalKey
        ) as? NSNumber)?.doubleValue ?? 1
        guard interval > 1 else { return date }

        let seconds = interval * 60
        return Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / seconds).rounded() * seconds)
    }

    private func date(fromEpochMilliseconds value: Any?) -> Date? {
        guard let milliseconds = doubleValue(value) else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? Double { return Int(value) }
        return nil
    }

    private func boolValue(_ value: Any?, default defaultValue: Bool) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return defaultValue
    }
}

private final class DatePickerActionTarget: NSObject {
    private weak var picker: NSDatePicker?
    private let handler: (Any?) -> Void

    init(picker: NSDatePicker, handler: @escaping (Any?) -> Void) {
        self.picker = picker
        self.handler = handler
    }

    @objc func selectionChanged(_ sender: NSDatePicker) {
        guard let picker else { return }

        let mode = objc_getAssociatedObject(picker, &VPickerFactory.modeKey) as? String ?? "date"
        let interval = (objc_getAssociatedObject(
            picker,
            &VPickerFactory.minuteIntervalKey
        ) as? NSNumber)?.doubleValue ?? 1
        let selectedDate: Date
        if (mode == "time" || mode == "datetime") && interval > 1 {
            let seconds = interval * 60
            selectedDate = Date(
                timeIntervalSinceReferenceDate: (picker.dateValue.timeIntervalSinceReferenceDate / seconds).rounded() * seconds
            )
            picker.dateValue = selectedDate
        } else {
            selectedDate = sender.dateValue
        }

        handler(["value": selectedDate.timeIntervalSince1970 * 1000])
    }
}
