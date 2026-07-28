import AppKit
import VueNativeShared
import IOKit.ps

/// Native module reporting battery state.
///
/// Methods:
///   - getBatteryInfo() -> { "level": Double | null, "isCharging": Bool | null }
///
/// Desktop Macs (iMac, Mac mini, Mac Studio, Mac Pro) have no internal battery.
/// In that case both fields are `null` (bridged from `NSNull`) and the JS
/// `useBattery` composable reports `isSupported == false`. MacBooks report real
/// values read from IOKit power sources.
///
/// The result dictionary always contains both keys so the JS side can rely on
/// the documented shape regardless of hardware.
final class BatteryModule: NativeModule {
    let moduleName = "Battery"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        // IOPS lookups are cheap and synchronous; hop to the main queue to match
        // the other modules' threading contract before calling back.
        DispatchQueue.main.async {
            switch method {
            case "getBatteryInfo":
                callback(BatteryModule.batteryInfo(), nil)

            default:
                callback(nil, "BatteryModule: Unknown method '\(method)'")
            }
        }
    }

    /// Read the current battery state.
    ///
    /// Returns a dictionary that always contains the `level` and `isCharging`
    /// keys. When the machine has no battery (or the state cannot be read) the
    /// values are `NSNull`, which bridges to JavaScript `null`.
    static func batteryInfo() -> [String: Any] {
        var level: Any = NSNull()
        var isCharging: Any = NSNull()

        if let (computedLevel, charging) = readInternalBattery() {
            if let computedLevel {
                level = computedLevel
            }
            if let charging {
                isCharging = charging
            }
        }

        return ["level": level, "isCharging": isCharging]
    }

    /// Query IOKit for the first present internal battery.
    ///
    /// Returns `nil` when the machine has no power sources at all (desktop Mac),
    /// so the caller can leave both fields as `NSNull`. When a battery exists but
    /// an individual field cannot be read, that field is `nil` in the tuple while
    /// the other may still be populated.
    private static func readInternalBattery() -> (level: Double?, isCharging: Bool?)? {
        guard let infoUnmanaged = IOPSCopyPowerSourcesInfo() else { return nil }
        let info = infoUnmanaged.takeRetainedValue()

        guard let listUnmanaged = IOPSCopyPowerSourcesList(info) else { return nil }
        let sources = listUnmanaged.takeRetainedValue() as? [CFTypeRef] ?? []
        guard !sources.isEmpty else { return nil }

        for source in sources {
            guard let descriptionUnmanaged = IOPSGetPowerSourceDescription(info, source) else {
                continue
            }
            // IOPS owns this dictionary -- do not release (takeUnretainedValue).
            guard let description = descriptionUnmanaged.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            // Only consider an internal battery that is physically present.
            let type = description[kIOPSTypeKey as String] as? String
            let isPresent = (description[kIOPSIsPresentKey as String] as? Bool) ?? false
            guard type == (kIOPSInternalBatteryType as String), isPresent else { continue }

            var level: Double?
            let current = description[kIOPSCurrentCapacityKey as String] as? Double
            let max = description[kIOPSMaxCapacityKey as String] as? Double
            if let current, let max, max > 0 {
                // Clamp to 0...1 to guard against transient IOKit reporting glitches.
                level = Swift.min(1.0, Swift.max(0.0, current / max))
            }

            let charging = description[kIOPSIsChargingKey as String] as? Bool

            return (level, charging)
        }

        // Power sources exist but none is an internal battery (e.g. an attached
        // UPS reported as an external source). Treat as unsupported.
        return nil
    }
}
