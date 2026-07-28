import AppKit
import VueNativeShared

/// Native module that dumps the live native view hierarchy as a JSON tree for
/// devtools and debugging. Backs the `useInspector` composable.
///
/// Methods:
///   - dumpTree() -> ViewTreeNode | null
///
/// The returned node shape matches the TypeScript `ViewTreeNode` contract:
///
///     { "id": Int, "type": String,
///       "frame": { "x": Double, "y": Double, "width": Double, "height": Double },
///       "children": [ ... ] }
///
/// The module walks the bridge's view registry (nodeId -> NSView + component
/// type) and reconstructs parent/child relationships from the AppKit subview
/// hierarchy, so intermediate non-Vue container views (a scroll view's
/// documentView, the modal container, etc.) never appear as tree nodes.
final class InspectorModule: NativeModule {

    let moduleName = "Inspector"

    /// Snapshot of every registered node: its id, component type, and view.
    /// Provided by the bridge and read on the main thread only.
    private let nodeSnapshot: () -> [(id: Int, type: String, view: NSView)]

    init(nodeSnapshot: @escaping () -> [(id: Int, type: String, view: NSView)]) {
        self.nodeSnapshot = nodeSnapshot
    }

    func invoke(method: String, args: [Any], callback: @escaping (Any?, String?) -> Void) {
        switch method {
        case "dumpTree":
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    callback(nil, "InspectorModule: disposed")
                    return
                }

                guard let tree = InspectorModule.buildTree(from: self.nodeSnapshot()) else {
                    // No registered views yet -- report a null tree.
                    callback(nil, nil)
                    return
                }

                // Serialize through JSONSerialization so the result crossing the
                // bridge is guaranteed to be a clean, valid JSON object graph.
                guard JSONSerialization.isValidJSONObject(tree),
                      let data = try? JSONSerialization.data(withJSONObject: tree),
                      let json = try? JSONSerialization.jsonObject(with: data) else {
                    callback(nil, "InspectorModule: failed to serialize view tree")
                    return
                }

                callback(json, nil)
            }

        default:
            callback(nil, "InspectorModule: Unknown method '\(method)'")
        }
    }

    // MARK: - Tree construction

    /// Build a single root `ViewTreeNode` dictionary from a flat node snapshot.
    ///
    /// Returns `nil` when there are no registered nodes. When more than one
    /// detached root exists, the root with the lowest node id is used so the
    /// result is deterministic (the TypeScript contract expects a single root).
    static func buildTree(from nodes: [(id: Int, type: String, view: NSView)]) -> [String: Any]? {
        guard !nodes.isEmpty else { return nil }

        // Map each registered view to its node metadata for O(1) ancestor lookups.
        var byView: [ObjectIdentifier: (id: Int, type: String, view: NSView)] = [:]
        for node in nodes {
            byView[ObjectIdentifier(node.view)] = node
        }

        // Determine each node's nearest *registered* ancestor by walking up the
        // AppKit superview chain. This skips intermediate container views that
        // are not Vue nodes (scroll documentViews, modal containers, etc.).
        var childrenByID: [Int: [(id: Int, type: String, view: NSView)]] = [:]
        var roots: [(id: Int, type: String, view: NSView)] = []

        for node in nodes {
            var ancestor = node.view.superview
            var parent: (id: Int, type: String, view: NSView)?
            while let current = ancestor {
                if let found = byView[ObjectIdentifier(current)] {
                    parent = found
                    break
                }
                ancestor = current.superview
            }

            if let parent {
                childrenByID[parent.id, default: []].append(node)
            } else {
                roots.append(node)
            }
        }

        // Deterministic ordering: sort roots and siblings by node id.
        roots.sort { $0.id < $1.id }
        for key in childrenByID.keys {
            childrenByID[key]?.sort { $0.id < $1.id }
        }

        func serialize(_ node: (id: Int, type: String, view: NSView)) -> [String: Any] {
            let frame = node.view.frame
            let children = (childrenByID[node.id] ?? []).map { serialize($0) }
            return [
                "id": node.id,
                "type": node.type,
                "frame": [
                    "x": frame.origin.x,
                    "y": frame.origin.y,
                    "width": frame.size.width,
                    "height": frame.size.height,
                ],
                "children": children,
            ]
        }

        guard let root = roots.first else { return nil }
        return serialize(root)
    }
}
