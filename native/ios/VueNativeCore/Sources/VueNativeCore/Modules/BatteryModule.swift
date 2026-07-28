#if canImport(UIKit)
import UIKit

/// Native module exposing battery state via `UIDevice`.
///
/// Methods:
///   - getBatteryInfo() -> { "level": Double | null, "isCharging": Bool | null }
///
/// `level` is reported in the range 0...1 and is `null` when unknown
/// (`UIDevice.batteryLevel` returns -1 in that case). `isCharging` is `null`
/// when the battery state is `.unknown`. Unavailable values are encoded as
/// `NSNull` so they bridge to JavaScript `null`, matching the cross-platform
/// `useBattery` contract.
final class BatteryModule: NativeModule {
    let moduleName = "Battery"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            switch method {
            case "getBatteryInfo":
                callback(BatteryModule.currentBatteryInfo(), nil)

            default:
                callback(nil, "BatteryModule: Unknown method '\(method)'")
            }
        }
    }

    /// Read the current battery state. Exposed internally for testing.
    static func currentBatteryInfo() -> [String: Any] {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true

        let rawLevel = device.batteryLevel
        let level: Any = rawLevel >= 0 ? Double(rawLevel) : NSNull()

        let isCharging: Any
        switch device.batteryState {
        case .charging, .full:
            isCharging = true
        case .unplugged:
            isCharging = false
        default:
            isCharging = NSNull()
        }

        return ["level": level, "isCharging": isCharging]
    }
}
#endif
