#if canImport(UIKit)
import Foundation

/// Native module providing file system access.
///
/// Methods:
///   - readFile(path: String, encoding: String?) -> String
///   - writeFile(path: String, content: String, encoding: String?)
///   - deleteFile(path: String)
///   - exists(path: String) -> Bool
///   - listDirectory(path: String) -> [String]
///   - downloadFile(url: String, destPath: String) -> String
///   - getDocumentsPath() -> String
///   - getCachesPath() -> String
///   - stat(path: String) -> { size, isDirectory, modified }
///   - mkdir(path: String)
///   - copyFile(srcPath: String, destPath: String)
///   - moveFile(srcPath: String, destPath: String)
final class FileSystemModule: NativeModule {
    let moduleName = "FileSystem"

    private let fileManager = FileManager.default

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            switch method {
            case "readFile":
                guard let path = args.first as? String else {
                    callback(nil, "readFile: missing path")
                    return
                }
                let encoding = (args.count > 1 ? args[1] as? String : nil) ?? "utf8"
                guard self.fileManager.fileExists(atPath: path) else {
                    callback(nil, "readFile: file not found at \(path)")
                    return
                }
                guard let data = self.fileManager.contents(atPath: path) else {
                    callback(nil, "readFile: could not read file at \(path)")
                    return
                }
                if encoding == "base64" {
                    callback(data.base64EncodedString(), nil)
                } else {
                    guard let text = String(data: data, encoding: .utf8) else {
                        callback(nil, "readFile: file is not valid UTF-8")
                        return
                    }
                    callback(text, nil)
                }

            case "writeFile":
                guard args.count >= 2,
                      let path = args[0] as? String,
                      let content = args[1] as? String else {
                    callback(nil, "writeFile: missing path or content")
                    return
                }
                let encoding = (args.count > 2 ? args[2] as? String : nil) ?? "utf8"
                let data: Data?
                if encoding == "base64" {
                    data = Data(base64Encoded: content)
                } else {
                    data = content.data(using: .utf8)
                }
                guard let fileData = data else {
                    callback(nil, "writeFile: could not encode content")
                    return
                }
                // Create parent directory if needed
                let dir = (path as NSString).deletingLastPathComponent
                if !self.fileManager.fileExists(atPath: dir) {
                    do {
                        try self.fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
                    } catch {
                        callback(nil, "writeFile: could not create directory: \(error.localizedDescription)")
                        return
                    }
                }
                self.fileManager.createFile(atPath: path, contents: fileData)
                callback(nil, nil)

            case "deleteFile":
                guard let path = args.first as? String else {
                    callback(nil, "deleteFile: missing path")
                    return
                }
                guard self.fileManager.fileExists(atPath: path) else {
                    callback(nil, "deleteFile: file not found at \(path)")
                    return
                }
                do {
                    try self.fileManager.removeItem(atPath: path)
                    callback(nil, nil)
                } catch {
                    callback(nil, "deleteFile: \(error.localizedDescription)")
                }

            case "exists":
                guard let path = args.first as? String else {
                    callback(nil, "exists: missing path")
                    return
                }
                callback(self.fileManager.fileExists(atPath: path), nil)

            case "listDirectory":
                guard let path = args.first as? String else {
                    callback(nil, "listDirectory: missing path")
                    return
                }
                do {
                    let contents = try self.fileManager.contentsOfDirectory(atPath: path)
                    callback(contents, nil)
                } catch {
                    callback(nil, "listDirectory: \(error.localizedDescription)")
                }

            case "downloadFile":
                guard args.count >= 2,
                      let urlString = args[0] as? String,
                      let destPath = args[1] as? String else {
                    callback(nil, "downloadFile: missing url or destPath")
                    return
                }
                guard let url = URL(string: urlString) else {
                    callback(nil, "downloadFile: invalid URL")
                    return
                }
                let task = URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        callback(nil, "downloadFile: \(error.localizedDescription)")
                        return
                    }
                    guard let data = data else {
                        callback(nil, "downloadFile: no data received")
                        return
                    }
                    // Create parent directory if needed
                    let dir = (destPath as NSString).deletingLastPathComponent
                    if !self.fileManager.fileExists(atPath: dir) {
                        do {
                            try self.fileManager.createDirectory(atPath: dir, withIntermediateDirectories: true)
                        } catch {
                            callback(nil, "downloadFile: could not create directory: \(error.localizedDescription)")
                            return
                        }
                    }
                    self.fileManager.createFile(atPath: destPath, contents: data)
                    callback(destPath, nil)
                }
                task.resume()

            case "getDocumentsPath":
                let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
                callback(paths.first, nil)

            case "getCachesPath":
                let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
                callback(paths.first, nil)

            case "stat":
                guard let path = args.first as? String else {
                    callback(nil, "stat: missing path")
                    return
                }
                do {
                    let attrs = try self.fileManager.attributesOfItem(atPath: path)
                    let size = (attrs[.size] as? Int) ?? 0
                    let isDir = (attrs[.type] as? FileAttributeType) == .typeDirectory
                    let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                    callback([
                        "size": size,
                        "isDirectory": isDir,
                        "modified": modified * 1000 // milliseconds for JS
                    ] as [String: Any], nil)
                } catch {
                    callback(nil, "stat: \(error.localizedDescription)")
                }

            case "mkdir":
                guard let path = args.first as? String else {
                    callback(nil, "mkdir: missing path")
                    return
                }
                do {
                    try self.fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
                    callback(nil, nil)
                } catch {
                    callback(nil, "mkdir: \(error.localizedDescription)")
                }

            case "copyFile":
                guard args.count >= 2,
                      let srcPath = args[0] as? String,
                      let destPath = args[1] as? String else {
                    callback(nil, "copyFile: missing srcPath or destPath")
                    return
                }
                do {
                    // Remove destination if it exists (copyItem throws if dest exists)
                    if self.fileManager.fileExists(atPath: destPath) {
                        try self.fileManager.removeItem(atPath: destPath)
                    }
                    try self.fileManager.copyItem(atPath: srcPath, toPath: destPath)
                    callback(nil, nil)
                } catch {
                    callback(nil, "copyFile: \(error.localizedDescription)")
                }

            case "moveFile":
                guard args.count >= 2,
                      let srcPath = args[0] as? String,
                      let destPath = args[1] as? String else {
                    callback(nil, "moveFile: missing srcPath or destPath")
                    return
                }
                do {
                    if self.fileManager.fileExists(atPath: destPath) {
                        try self.fileManager.removeItem(atPath: destPath)
                    }
                    try self.fileManager.moveItem(atPath: srcPath, toPath: destPath)
                    callback(nil, nil)
                } catch {
                    callback(nil, "moveFile: \(error.localizedDescription)")
                }

            default:
                callback(nil, "FileSystemModule: Unknown method '\(method)'")
            }
        }
    }
}
#endif
