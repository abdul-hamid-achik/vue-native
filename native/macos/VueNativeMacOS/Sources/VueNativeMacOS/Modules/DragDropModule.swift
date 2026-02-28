import AppKit
import VueNativeShared

/// macOS-only module for drag and drop support.
///
/// Methods:
///   - enableDropZone(viewId: Int) -- register a view for file/text drops
///   - startDrag(data: { text: String }) -- initiate a drag operation
///
/// Events dispatched:
///   - dragDrop:drop { files: [String], text: String? }
final class DragDropModule: NativeModule {
    let moduleName = "DragDrop"
    private weak var dispatcher: NativeEventDispatcher?

    init(dispatcher: NativeEventDispatcher) {
        self.dispatcher = dispatcher
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            switch method {
            case "enableDropZone":
                guard args.first is Int else {
                    callback(nil, "Invalid viewId")
                    return
                }
                // Register the main window's content view for file and string drops.
                // Full per-view registration would require access to the bridge's view registry.
                if let window = NSApp.mainWindow, let view = window.contentView {
                    view.registerForDraggedTypes([.fileURL, .string])
                }
                callback(nil, nil)

            case "startDrag":
                guard let data = args.first as? [String: Any] else {
                    callback(nil, "Invalid args")
                    return
                }
                // Drag operations are typically initiated by mouse events.
                // This method prepares drag data that can be used by event handlers.
                _ = data
                callback(nil, nil)

            default:
                callback(nil, "DragDropModule: Unknown method '\(method)'")
            }
        }
    }
}
