import AppKit
import VueNativeShared

/// macOS-only module for window management.
///
/// Methods:
///   - setTitle(title: String)
///   - setSize(width: Double, height: Double)
///   - center()
///   - minimize()
///   - toggleFullScreen()
///   - close()
///   - getInfo() -> { width, height, x, y, isFullScreen, isVisible, title }
final class WindowModule: NativeModule {
    let moduleName = "Window"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            switch method {
            case "setTitle":
                let title = args.first as? String ?? ""
                NSApp.mainWindow?.title = title
                callback(nil, nil)

            case "setSize":
                guard args.count >= 2,
                      let width = args[0] as? Double,
                      let height = args[1] as? Double else {
                    callback(nil, "Invalid args")
                    return
                }
                NSApp.mainWindow?.setContentSize(NSSize(width: width, height: height))
                callback(nil, nil)

            case "center":
                NSApp.mainWindow?.center()
                callback(nil, nil)

            case "minimize":
                NSApp.mainWindow?.miniaturize(nil)
                callback(nil, nil)

            case "toggleFullScreen":
                NSApp.mainWindow?.toggleFullScreen(nil)
                callback(nil, nil)

            case "close":
                NSApp.mainWindow?.close()
                callback(nil, nil)

            case "getInfo":
                guard let window = NSApp.mainWindow else {
                    callback(nil, "No main window")
                    return
                }
                callback([
                    "width": window.frame.width,
                    "height": window.frame.height,
                    "x": window.frame.origin.x,
                    "y": window.frame.origin.y,
                    "isFullScreen": window.styleMask.contains(.fullScreen),
                    "isVisible": window.isVisible,
                    "title": window.title,
                ], nil)

            default:
                callback(nil, "WindowModule: Unknown method '\(method)'")
            }
        }
    }
}
