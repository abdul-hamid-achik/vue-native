import AppKit
import ObjectiveC

/// Factory for VSectionList — sectioned list component backed by NSTableView with group rows.
/// Extends the VList pattern to support section headers via NSTableView's group row feature.
final class VSectionListFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var scrollThrottleKey: UInt8 = 0
    private static var scrollObserverKey: UInt8 = 0
    private static var endReachedHandlerKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let container = VSectionListContainerView()
        container.ensureLayoutNode()
        return container
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let container = view as? VSectionListContainerView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "sections":
            if let sections = value as? [[String: Any]] {
                container.sections = sections.map { dict in
                    let title = dict["title"] as? String ?? ""
                    let dataCount: Int
                    if let data = dict["data"] as? [Any] {
                        dataCount = data.count
                    } else {
                        dataCount = 0
                    }
                    return SectionInfo(title: title, itemCount: dataCount)
                }
            }
            container.rebuildFlatList()
            container.tableView.reloadData()

        case "scrollEnabled":
            let enabled = (value as? Bool) ?? true
            container.scrollView.verticalScrollElasticity = enabled ? .allowed : .none
            container.scrollView.hasVerticalScroller = enabled

        case "showsVerticalScrollIndicator":
            let show = (value as? Bool) ?? true
            container.scrollView.hasVerticalScroller = show

        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        guard let container = view as? VSectionListContainerView else { return }

        switch event {
        case "scroll":
            let throttle = EventThrottle(interval: 0.016) { payload in
                handler(payload)
            }
            objc_setAssociatedObject(
                view, &VSectionListFactory.scrollThrottleKey,
                throttle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

            container.scrollView.contentView.postsBoundsChangedNotifications = true
            let observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: container.scrollView.contentView,
                queue: .main
            ) { [weak container] _ in
                guard let c = container else { return }
                let clipBounds = c.scrollView.contentView.bounds
                let docSize = c.scrollView.documentView?.frame.size ?? .zero
                let visibleSize = c.scrollView.contentView.bounds.size

                let payload: [String: Any] = [
                    "contentOffset": [
                        "x": clipBounds.origin.x,
                        "y": clipBounds.origin.y
                    ],
                    "contentSize": [
                        "width": docSize.width,
                        "height": docSize.height
                    ],
                    "layoutMeasurement": [
                        "width": visibleSize.width,
                        "height": visibleSize.height
                    ]
                ]
                throttle.fire(payload)

                // Check for endReached
                let endThreshold: CGFloat = 100
                let scrolledToBottom = clipBounds.origin.y + visibleSize.height >= docSize.height - endThreshold
                if scrolledToBottom, let wrapper = objc_getAssociatedObject(
                    c, &VSectionListFactory.endReachedHandlerKey
                ) as? SectionHandlerWrapper {
                    wrapper.handler(nil)
                }
            }

            objc_setAssociatedObject(
                view, &VSectionListFactory.scrollObserverKey,
                observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "endReached":
            let wrapper = SectionHandlerWrapper(handler: handler)
            objc_setAssociatedObject(
                view, &VSectionListFactory.endReachedHandlerKey,
                wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        switch event {
        case "scroll":
            if let observer = objc_getAssociatedObject(view, &VSectionListFactory.scrollObserverKey) {
                NotificationCenter.default.removeObserver(observer)
                objc_setAssociatedObject(
                    view, &VSectionListFactory.scrollObserverKey,
                    nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
            objc_setAssociatedObject(
                view, &VSectionListFactory.scrollThrottleKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "endReached":
            objc_setAssociatedObject(
                view, &VSectionListFactory.endReachedHandlerKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    // MARK: - Child management

    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?) {
        guard let container = parent as? VSectionListContainerView else { return }
        child.ensureLayoutNode()

        if let anchor = anchor, let idx = container.childViews.firstIndex(where: { $0 === anchor }) {
            container.childViews.insert(child, at: idx)
        } else {
            container.childViews.append(child)
        }
        container.tableView.reloadData()
    }

    func removeChild(_ child: NSView, from parent: NSView) {
        guard let container = parent as? VSectionListContainerView else {
            child.removeFromSuperview()
            return
        }
        container.childViews.removeAll { $0 === child }
        child.removeFromSuperview()
        container.tableView.reloadData()
    }
}

// MARK: - SectionHandlerWrapper

private final class SectionHandlerWrapper: NSObject {
    let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }
}

// MARK: - SectionInfo

struct SectionInfo {
    let title: String
    let itemCount: Int
}

// MARK: - FlatRow

/// Represents either a section header or an item row in the flattened table view data.
private enum FlatRow {
    case sectionHeader(String)
    case item(sectionIndex: Int, itemIndex: Int)
}

// MARK: - VSectionListContainerView

/// Container view hosting NSScrollView + NSTableView with section support.
/// Uses NSTableView group rows for section headers.
final class VSectionListContainerView: FlippedView, NSTableViewDataSource, NSTableViewDelegate {

    // MARK: - Subviews

    let scrollView: NSScrollView
    let tableView: NSTableView

    // MARK: - State

    var childViews: [NSView] = []
    var sections: [SectionInfo] = []
    private var flatRows: [FlatRow] = []

    private static let cellIdentifier = NSUserInterfaceItemIdentifier("VSectionListCell")
    private static let headerIdentifier = NSUserInterfaceItemIdentifier("VSectionListHeader")

    // MARK: - Init

    override init(frame: NSRect) {
        scrollView = NSScrollView()
        tableView = NSTableView()

        super.init(frame: frame)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .plain
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.floatsGroupRows = true

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        addSubview(scrollView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
    }

    /// Rebuild the flat row list from sections data.
    func rebuildFlatList() {
        flatRows.removeAll()
        for (sectionIndex, section) in sections.enumerated() {
            flatRows.append(.sectionHeader(section.title))
            for itemIndex in 0..<section.itemCount {
                flatRows.append(.item(sectionIndex: sectionIndex, itemIndex: itemIndex))
            }
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return flatRows.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        guard row < flatRows.count else { return false }
        if case .sectionHeader = flatRows[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < flatRows.count else { return nil }

        switch flatRows[row] {
        case .sectionHeader(let title):
            let headerView: NSTableCellView
            if let reused = tableView.makeView(withIdentifier: VSectionListContainerView.headerIdentifier, owner: nil) as? NSTableCellView {
                reused.textField?.stringValue = title
                headerView = reused
            } else {
                headerView = NSTableCellView()
                headerView.identifier = VSectionListContainerView.headerIdentifier
                let label = NSTextField(labelWithString: title)
                label.font = NSFont.boldSystemFont(ofSize: 13)
                label.textColor = .secondaryLabelColor
                headerView.addSubview(label)
                headerView.textField = label
                label.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
                    label.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
                ])
            }
            return headerView

        case .item(_, let itemIndex):
            // Map to the corresponding child view index
            let childIndex = childIndexForRow(row)
            guard childIndex < childViews.count else { return nil }

            let cellView: NSTableCellView
            if let reused = tableView.makeView(withIdentifier: VSectionListContainerView.cellIdentifier, owner: nil) as? NSTableCellView {
                reused.subviews.forEach { $0.removeFromSuperview() }
                cellView = reused
            } else {
                cellView = NSTableCellView()
                cellView.identifier = VSectionListContainerView.cellIdentifier
            }

            let child = childViews[childIndex]
            child.removeFromSuperview()
            cellView.addSubview(child)
            child.frame = cellView.bounds
            child.autoresizingMask = [.width, .height]

            return cellView
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < flatRows.count else { return 44 }

        switch flatRows[row] {
        case .sectionHeader:
            return 32

        case .item:
            let childIndex = childIndexForRow(row)
            guard childIndex < childViews.count else { return 44 }

            let child = childViews[childIndex]
            if let node = child.layoutNode {
                if node.computedFrame.height > 0 {
                    return node.computedFrame.height
                }
                if let h = node.height.resolve(relativeTo: bounds.height), h > 0 {
                    return h
                }
            }
            return 44
        }
    }

    /// Convert a flat table row index to a child view index (skipping section headers).
    private func childIndexForRow(_ row: Int) -> Int {
        var childIdx = 0
        for i in 0..<row {
            if case .item = flatRows[i] {
                childIdx += 1
            }
        }
        return childIdx
    }
}
