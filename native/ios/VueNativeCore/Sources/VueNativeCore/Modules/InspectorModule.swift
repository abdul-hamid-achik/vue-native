#if canImport(UIKit)
import Foundation

/// Native module exposing the live native view hierarchy for devtools.
///
/// Methods:
///   - dumpTree() -> [ { "id": Int, "type": String,
///                       "frame": { "x", "y", "width", "height" },
///                       "children": [...] } ]
///
/// The tree is built from the bridge's node registries, so every node carries
/// the component type it was created from (e.g. "VView", "VText") rather than
/// the underlying UIKit class. The returned value is JSON-serializable and is
/// intended to be consumed by a JS-side inspector/devtools overlay.
final class InspectorModule: NativeModule {
    let moduleName = "Inspector"

    private let bridge: NativeBridge

    init(bridge: NativeBridge = .shared) {
        self.bridge = bridge
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "dumpTree":
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                callback(self.bridge.dumpViewTree(), nil)
            }

        default:
            callback(nil, "InspectorModule: Unknown method '\(method)'")
        }
    }
}
#endif
