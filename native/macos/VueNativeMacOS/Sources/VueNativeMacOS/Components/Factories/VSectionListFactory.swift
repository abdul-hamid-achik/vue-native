import AppKit
import ObjectiveC

/// Factory for VSectionList — sectioned list component backed by NSTableView with group rows.
/// Children marked with `__sectionHeader` are treated as section headers.
final class VSectionListFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    nonisolated(unsafe) private static var scrollThrottleKey: UInt8 = 0
    nonisolated(unsafe) private static var scrollObserverKey: UInt8 = 0
    nonisolated(unsafe) private static var endReachedHandlerKey: UInt8 = 0

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
        case "estimatedItemHeight":
            container.estimatedItemHeight = Self.cgFloat(from: value) ?? 44

        case "stickySectionHeaders":
            let sticky = (value as? Bool) ?? true
            container.stickySectionHeaders = sticky
            container.tableView.floatsGroupRows = sticky

        case "showsScrollIndicator":
            container.scrollView.hasVerticalScroller = (value as? Bool) ?? true

        case "bounces":
            let elasticity: NSScrollView.Elasticity = ((value as? Bool) ?? true) ? .allowed : .none
            container.scrollView.verticalScrollElasticity = elasticity
            container.scrollView.horizontalScrollElasticity = elasticity

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
                    "x": clipBounds.origin.x,
                    "y": clipBounds.origin.y,
                    "contentWidth": docSize.width,
                    "contentHeight": docSize.height,
                    "layoutWidth": visibleSize.width,
                    "layoutHeight": visibleSize.height,
                ]
                throttle.fire(payload)

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

        if let anchor = anchor, let idx = container.allChildren.firstIndex(where: { $0 === anchor }) {
            container.allChildren.insert(child, at: idx)
        } else {
            container.allChildren.append(child)
        }
        container.rebuildSections()
        container.tableView.reloadData()
    }

    func removeChild(_ child: NSView, from parent: NSView) {
        guard let container = parent as? VSectionListContainerView else {
            child.removeFromSuperview()
            return
        }

        container.allChildren.removeAll { $0 === child }
        child.removeFromSuperview()
        container.rebuildSections()
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

// MARK: - SectionData

private struct SectionData {
    var headerView: NSView?
    var itemViews: [NSView]
}

// MARK: - FlatRow

private enum FlatRow {
    case sectionHeader(sectionIndex: Int)
    case item(sectionIndex: Int, itemIndex: Int)
}

// MARK: - VSectionListContainerView

/// Container view hosting NSScrollView + NSTableView with section support.
final class VSectionListContainerView: FlippedView, NSTableViewDataSource, NSTableViewDelegate {

    // MARK: - Subviews

    let scrollView: NSScrollView
    let tableView: NSTableView

    // MARK: - State

    var allChildren: [NSView] = []
    var estimatedItemHeight: CGFloat = 44
    var stickySectionHeaders = true
    fileprivate var sections: [SectionData] = []
    fileprivate var flatRows: [FlatRow] = []

    private static let cellIdentifier = NSUserInterfaceItemIdentifier("VSectionListCell")

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

    func rebuildSections() {
        sections.removeAll()
        var currentSection = SectionData(headerView: nil, itemViews: [])

        for child in allChildren {
            let isSectionHeader = StyleEngine.getInternalProp("__sectionHeader", from: child) as? Bool ?? false
            if isSectionHeader {
                if currentSection.headerView != nil || !currentSection.itemViews.isEmpty {
                    sections.append(currentSection)
                }
                currentSection = SectionData(headerView: child, itemViews: [])
            } else {
                currentSection.itemViews.append(child)
            }
        }

        if currentSection.headerView != nil || !currentSection.itemViews.isEmpty {
            sections.append(currentSection)
        }

        rebuildFlatRows()
    }

    private func rebuildFlatRows() {
        flatRows.removeAll()

        for (sectionIndex, section) in sections.enumerated() {
            if section.headerView != nil {
                flatRows.append(.sectionHeader(sectionIndex: sectionIndex))
            }
            for itemIndex in section.itemViews.indices {
                flatRows.append(.item(sectionIndex: sectionIndex, itemIndex: itemIndex))
            }
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        flatRows.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        guard row < flatRows.count else { return false }
        if case .sectionHeader = flatRows[row] {
            return true
        }
        return false
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < flatRows.count else { return nil }

        switch flatRows[row] {
        case .sectionHeader(let sectionIndex):
            guard sectionIndex < sections.count,
                  let headerView = sections[sectionIndex].headerView else { return nil }
            headerView.removeFromSuperview()
            return headerView

        case .item(let sectionIndex, let itemIndex):
            guard sectionIndex < sections.count,
                  itemIndex < sections[sectionIndex].itemViews.count else { return nil }

            let cellView: NSTableCellView
            if let reused = tableView.makeView(withIdentifier: VSectionListContainerView.cellIdentifier, owner: nil) as? NSTableCellView {
                reused.subviews.forEach { $0.removeFromSuperview() }
                cellView = reused
            } else {
                cellView = NSTableCellView()
                cellView.identifier = VSectionListContainerView.cellIdentifier
            }

            let child = sections[sectionIndex].itemViews[itemIndex]
            child.removeFromSuperview()
            cellView.addSubview(child)
            child.frame = cellView.bounds
            child.autoresizingMask = [.width, .height]
            return cellView
        }
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < flatRows.count else { return estimatedItemHeight }

        switch flatRows[row] {
        case .sectionHeader(let sectionIndex):
            guard sectionIndex < sections.count,
                  let headerView = sections[sectionIndex].headerView else { return estimatedItemHeight }
            return resolvedHeight(for: headerView)

        case .item(let sectionIndex, let itemIndex):
            guard sectionIndex < sections.count,
                  itemIndex < sections[sectionIndex].itemViews.count else { return estimatedItemHeight }
            return resolvedHeight(for: sections[sectionIndex].itemViews[itemIndex])
        }
    }

    private func resolvedHeight(for view: NSView) -> CGFloat {
        let explicitHeight = view.frame.size.height
        if explicitHeight > 1 {
            return explicitHeight
        }

        if let node = view.layoutNode {
            if node.computedFrame.height > 0 {
                return node.computedFrame.height
            }
            if let resolved = node.height.resolve(relativeTo: bounds.height), resolved > 0 {
                return resolved
            }
        }

        return estimatedItemHeight
    }
}

private extension VSectionListFactory {
    static func cgFloat(from value: Any?) -> CGFloat? {
        if let value = value as? CGFloat { return value }
        if let value = value as? Double { return CGFloat(value) }
        if let value = value as? Int { return CGFloat(value) }
        if let value = value as? String, let parsed = Double(value) {
            return CGFloat(parsed)
        }
        return nil
    }
}
