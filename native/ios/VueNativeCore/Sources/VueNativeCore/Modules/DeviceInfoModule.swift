#if canImport(UIKit)
import UIKit

/// Native module providing device and screen information.
///
/// Methods:
///   - getInfo()/getDeviceInfo() -> { model, systemVersion, name, locale,
///     colorScheme, screenWidth, screenHeight, scale }
final class DeviceInfoModule: NativeModule {
    let moduleName = "DeviceInfo"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            switch method {
            case "getInfo", "getDeviceInfo":
                let device = UIDevice.current
                let screen = UIScreen.main
                let colorScheme = screen.traitCollection.userInterfaceStyle == .dark ? "dark" : "light"
                let info: [String: Any] = [
                    "platform": "ios",
                    "model": device.model,
                    "systemVersion": device.systemVersion,
                    "systemName": device.systemName,
                    "name": device.name,
                    "locale": Locale.current.identifier,
                    "colorScheme": colorScheme,
                    "screenWidth": screen.bounds.width,
                    "screenHeight": screen.bounds.height,
                    "scale": screen.scale
                ]
                callback(info, nil)

            default:
                callback(nil, "DeviceInfoModule: Unknown method '\(method)'")
            }
        }
    }
}
#endif
