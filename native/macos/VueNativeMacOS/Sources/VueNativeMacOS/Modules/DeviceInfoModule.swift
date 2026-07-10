import AppKit
import VueNativeShared

/// Native module providing device and screen information for macOS.
///
/// Methods:
///   - getInfo()/getDeviceInfo() -> { platform, systemName, systemVersion,
///     model, name, locale, colorScheme, screenWidth, screenHeight, scale }
final class DeviceInfoModule: NativeModule {
    let moduleName = "DeviceInfo"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            switch method {
            case "getInfo", "getDeviceInfo":
                let processInfo = ProcessInfo.processInfo
                let version = processInfo.operatingSystemVersion

                var systemInfo = utsname()
                uname(&systemInfo)
                let machine = withUnsafePointer(to: &systemInfo.machine) {
                    $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                        String(validatingUTF8: $0) ?? "unknown"
                    }
                }

                let screen = NSScreen.main
                let screenWidth = screen?.frame.width ?? 0
                let screenHeight = screen?.frame.height ?? 0
                let scale = screen?.backingScaleFactor ?? 1.0
                let colorScheme = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? "dark"
                    : "light"

                let info: [String: Any] = [
                    "platform": "macos",
                    "systemName": "macOS",
                    "systemVersion": "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
                    "model": machine,
                    "name": Host.current().localizedName ?? "Mac",
                    "isSimulator": false,
                    "locale": Locale.current.identifier,
                    "colorScheme": colorScheme,
                    "screenWidth": screenWidth,
                    "screenHeight": screenHeight,
                    "scale": scale,
                ]
                callback(info, nil)

            default:
                callback(nil, "DeviceInfoModule: Unknown method '\(method)'")
            }
        }
    }
}
