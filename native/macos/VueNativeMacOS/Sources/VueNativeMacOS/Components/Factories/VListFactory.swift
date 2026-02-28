import AppKit
import ObjectiveC

/// Factory for VList — virtualized list component backed by NSTableView.
/// Uses a single-column, view-based NSTableView inside a VListContainerView.
/// JS sends child views that are placed into table view cells.
final class VListFactory: NativeComponentFactory {

    // MARK: - Associated object keys

    private static var scrollThrottleKey: UInt8 = 0
    private static var scrollObserverKey: UInt8 = 0
    private static var endReachedHandlerKey: UInt8 = 0
    private static var scrollHandlerKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> NSView {
        let container = VListContainerView()
        container.ensureLayoutNode()
        return container
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let container = view as? VListContainerView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }

        switch key {
        case "data":
            if let items = value as? [Any] {
                container.itemCount = items.count
            } else if let count = value as? Int {
                container.itemCount = count
            }
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
        guard let container = view as? VListContainerView else { return }

        switch event {
        case "scroll":
            let throttle = EventThrottle(interval: 0.016) { payload in
                handler(payload)
            }
            objc_setAssociatedObject(
                view, &VListFactory.scrollThrottleKey,
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
                if scrolledToBottom, let endHandler = objc_getAssociatedObject(
                    c, &VListFactory.endReachedHandlerKey
                ) as? HandlerWrapper {
                    endHandler.handler(nil)
                }
            }

            objc_setAssociatedObject(
                view, &VListFactory.scrollObserverKey,
                observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "endReached":
            let wrapper = HandlerWrapper(handler: handler)
            objc_setAssociatedObject(
                view, &VListFactory.endReachedHandlerKey,
                wrapper, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    func removeEventListener(view: NSView, event: String) {
        switch event {
        case "scroll":
            if let observer = objc_getAssociatedObject(view, &VListFactory.scrollObserverKey) {
                NotificationCenter.default.removeObserver(observer)
                objc_setAssociatedObject(
                    view, &VListFactory.scrollObserverKey,
                    nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
            objc_setAssociatedObject(
                view, &VListFactory.scrollThrottleKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        case "endReached":
            objc_setAssociatedObject(
                view, &VListFactory.endReachedHandlerKey,
                nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )

        default:
            break
        }
    }

    // MARK: - Child management

    func insertChild(_ child: NSView, into parent: NSView, before anchor: NSView?) {
        guard let container = parent as? VListContainerView else { return }
        child.ensureLayoutNode()

        if let anchor = anchor, let idx = container.childViews.firstIndex(where: { $0 === anchor }) {
            container.childViews.insert(child, at: idx)
        } else {
            container.childViews.append(child)
        }
        container.itemCount = container.childViews.count
        container.tableView.reloadData()
    }

    func removeChild(_ child: NSView, from parent: NSView) {
        guard let container = parent as? VListContainerView else {
            child.removeFromSuperview()
            return
        }
        container.childViews.removeAll { $0 === child }
        child.removeFromSuperview()
        container.itemCount = container.childViews.count
        container.tableView.reloadData()
    }
}

// MARK: - HandlerWrapper

/// NSObject wrapper for storing closure-based handlers as associated objects.
private final class HandlerWrapper: NSObject {
    let handler: (Any?) -> Void

    init(handler: @escaping (Any?) -> Void) {
        self.handler = handler
        super.init()
    }
}

// MARK: - VListContainerView

/// Container view that hosts an NSScrollView + NSTableView for virtualized list rendering.
/// JS-rendered child views are stored and served as cell contents via the data source.
final class VListContainerView: FlippedView, NSTableViewDataSource, NSTableViewDelegate {

    // MARK: - Subviews

    let scrollView: NSScrollView
    let tableView: NSTableView

    // MARK: - State

    var childViews: [NSView] = []
    var itemCount: Int = 0

    private static let cellIdentifier = NSUserInterfaceItemIdentifier("VListCell")

    // MARK: - Init

    override init(frame: NSRect) {
        scrollView = NSScrollView()
        tableView = NSTableView()

        super.init(frame: frame)

        // Configure table view
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        column.isEditable = false
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.style = .plain
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.dataSource = self
        tableView.delegate = self

        // Configure scroll view
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

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return itemCount
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Wrap the child view in a container cell view
        guard row < childViews.count else { return nil }

        let cellView: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: VListContainerView.cellIdentifier, owner: nil) as? NSTableCellView {
            // Remove old content
            reused.subviews.forEach { $0.removeFromSuperview() }
            cellView = reused
        } else {
            cellView = NSTableCellView()
            cellView.identifier = VListContainerView.cellIdentifier
        }

        let child = childViews[row]
        child.removeFromSuperview()
        cellView.addSubview(child)
        child.frame = cellView.bounds
        child.autoresizingMask = [.width, .height]

        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < childViews.count else { return 44 }

        let child = childViews[row]
        if let node = child.layoutNode {
            // Use layout node computed height if available
            if node.computedFrame.height > 0 {
                return node.computedFrame.height
            }
            // Try resolving the height
            if let h = node.height.resolve(relativeTo: bounds.height), h > 0 {
                return h
            }
        }
        // Default row height
        return 44
    }
}
