import AppKit
import UniformTypeIdentifiers
import VueNativeShared

/// macOS-only module for file open/save dialogs.
///
/// Methods:
///   - openFile(options?: { multiple?, allowedTypes?, title? }) -> [String]? (file paths)
///   - openDirectory(options?: { title? }) -> String? (directory path)
///   - saveFile(options?: { title?, defaultName? }) -> String? (save path)
final class FileDialogModule: NativeModule {
    let moduleName = "FileDialog"

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async {
            switch method {
            case "openFile":
                let options = args.first as? [String: Any] ?? [:]
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = (options["multiple"] as? Bool) ?? false

                if let types = options["allowedTypes"] as? [String] {
                    panel.allowedContentTypes = types.compactMap { ext in
                        UTType(filenameExtension: ext)
                    }
                }

                if let title = options["title"] as? String {
                    panel.title = title
                }

                panel.begin { response in
                    if response == .OK {
                        let urls = panel.urls.map { $0.path }
                        callback(urls, nil)
                    } else {
                        callback(nil, nil) // cancelled
                    }
                }

            case "openDirectory":
                let options = args.first as? [String: Any] ?? [:]
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false

                if let title = options["title"] as? String {
                    panel.title = title
                }

                panel.begin { response in
                    if response == .OK {
                        callback(panel.url?.path, nil)
                    } else {
                        callback(nil, nil)
                    }
                }

            case "saveFile":
                let options = args.first as? [String: Any] ?? [:]
                let panel = NSSavePanel()

                if let title = options["title"] as? String {
                    panel.title = title
                }
                if let defaultName = options["defaultName"] as? String {
                    panel.nameFieldStringValue = defaultName
                }

                panel.begin { response in
                    if response == .OK {
                        callback(panel.url?.path, nil)
                    } else {
                        callback(nil, nil)
                    }
                }

            default:
                callback(nil, "FileDialogModule: Unknown method '\(method)'")
            }
        }
    }
}
