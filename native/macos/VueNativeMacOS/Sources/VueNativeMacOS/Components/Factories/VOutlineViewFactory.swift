import AppKit
import ObjectiveC

/// Factory for VOutlineView — macOS-specific tree/outline view component.
/// Maps to NSOutlineView wrapped in an NSScrollView.
///
/// Props:
///   - data: [{ id, label, children?: [...] }]
///   - expandAll: Bool
///   - selectionMode: "single" | "multiple" | "none"
///
/// Events:
///   - select -> { id, label }
///   - expand -> { id }
///   - collapse -> { id }
final class VOutlineViewFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var dataSourceKey: UInt8 = 0
    private static var selectHandlerKey: UInt8 = 0
    private static var expandHandlerKey: UInt8 = 0
    private static var collapseHandlerKey: UInt8 = 0
    private static var outlineViewKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let scrollView = NSScrollView()
        scrollView.wantsLayer = true
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.allowsMultipleSelection = false
        outlineView.selectionHighlightStyle = .regular

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("label"))
        column.title = ""
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column

        scrollView.documentView = outlineView

        // Create and attach data source/delegate
        let handler = OutlineHandler(outlineView: outlineView, scrollView: scrollView)
        outlineView.dataSource = handler
        outlineView.delegate = handler

        objc_setAssociatedObject(
            scrollView, &VOutlineViewFactory.dataSourceKey,
            handler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        objc_setAssociatedObject(
            scrollView, &VOutlineViewFactory.outlineViewKey,
            outlineView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        scrollView.ensureLayoutNode()
        return scrollView
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        let outlineView = objc_getAssociatedObject(
            view, &VOutlineViewFactory.outlineViewKey
        ) as? NSOutlineView

        let handler = objc_getAssociatedObject(
            view, &VOutlineViewFactory.dataSourceKey
        ) as? OutlineHandler

        switch key {
        case "data":
            guard let dataArray = value as? [[String: Any]] else { return }
            let nodes = OutlineNode.parse(dataArray)
            handler?.rootNodes = nodes
            outlineView?.reloadData()

            // If expandAll was previously set, re-expand
            if handler?.shouldExpandAll == true {
                outlineView?.expandItem(nil, expandChildren: true)
            }

        case "expandAll":
            let expand = (value as? Bool) ?? false
            handler?.shouldExpandAll = expand
            if expand {
                outlineView?.expandItem(nil, expandChildren: true)
            } else {
                outlineView?.collapseItem(nil, collapseChildren: true)
            }

        case "selectionMode":
            guard let outlineView = outlineView else { return }
            if let mode = value as? String {
                switch mode {
                case "multiple":
                    outlineView.allowsMultipleSelection = true
                    outlineView.allowsEmptySelection = true
                case "none":
                    outlineView.allowsMultipleSelection = false
                    outlineView.allowsEmptySelection = true
                    outlineView.selectionHighlightStyle = .none
                default: // "single"
                    outlineView.allowsMultipleSelection = false
                    outlineView.allowsEmptySelection = true
                    outlineView.selectionHighlightStyle = .regular
                }
            }

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        let outlineHandler = objc_getAssociatedObject(
            view, &VOutlineViewFactory.dataSourceKey
        ) as? OutlineHandler

        switch event {
        case "select":
            outlineHandler?.onSelect = handler

        case "expand":
            outlineHandler?.onExpand = handler

        case "collapse":
            outlineHandler?.onCollapse = handler

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        let outlineHandler = objc_getAssociatedObject(
            view, &VOutlineViewFactory.dataSourceKey
        ) as? OutlineHandler

        switch event {
        case "select":
            outlineHandler?.onSelect = nil

        case "expand":
            outlineHandler?.onExpand = nil

        case "collapse":
            outlineHandler?.onCollapse = nil

        default:
            break
        }
    }
}

// MARK: - OutlineNode

private final class OutlineNode {
    let id: String
    let label: String
    var children: [OutlineNode]

    init(id: String, label: String, children: [OutlineNode] = []) {
        self.id = id
        self.label = label
        self.children = children
    }

    static func parse(_ array: [[String: Any]]) -> [OutlineNode] {
        return array.map { dict in
            let id = (dict["id"] as? String) ?? UUID().uuidString
            let label = (dict["label"] as? String) ?? ""
            let childDicts = dict["children"] as? [[String: Any]] ?? []
            let children = parse(childDicts)
            return OutlineNode(id: id, label: label, children: children)
        }
    }
}

// MARK: - OutlineHandler

private final class OutlineHandler: NSObject,
    NSOutlineViewDataSource, NSOutlineViewDelegate
{
    var rootNodes: [OutlineNode] = []
    var shouldExpandAll: Bool = false

    var onSelect: ((Any?) -> Void)?
    var onExpand: ((Any?) -> Void)?
    var onCollapse: ((Any?) -> Void)?

    private weak var outlineView: NSOutlineView?
    private weak var scrollView: NSScrollView?

    init(outlineView: NSOutlineView, scrollView: NSScrollView) {
        self.outlineView = outlineView
        self.scrollView = scrollView
        super.init()
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let node = item as? OutlineNode {
            return node.children.count
        }
        return rootNodes.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let node = item as? OutlineNode {
            return node.children[index]
        }
        return rootNodes[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let node = item as? OutlineNode {
            return !node.children.isEmpty
        }
        return false
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? OutlineNode else { return nil }

        let cellId = NSUserInterfaceItemIdentifier("OutlineCell")
        let cellView: NSTableCellView

        if let reused = outlineView.makeView(withIdentifier: cellId, owner: nil) as? NSTableCellView {
            cellView = reused
        } else {
            cellView = NSTableCellView()
            cellView.identifier = cellId

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            cellView.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            ])
        }

        cellView.textField?.stringValue = node.label
        return cellView
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = outlineView else { return }
        let row = outlineView.selectedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? OutlineNode else { return }
        onSelect?(["id": node.id, "label": node.label])
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? OutlineNode else { return }
        onExpand?(["id": node.id])
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let node = notification.userInfo?["NSObject"] as? OutlineNode else { return }
        onCollapse?(["id": node.id])
    }
}
