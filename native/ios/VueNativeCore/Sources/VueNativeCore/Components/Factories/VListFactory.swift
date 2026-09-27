#if canImport(UIKit)
import UIKit
import FlexLayout

// MARK: - VListFactory

/// Factory for VList — a scrollable list backed by UITableView.
///
/// Cells are recycled by the table view, but the child views themselves are **not**
/// virtualized: every row's `UIView` is created up front by the JS renderer and held
/// in `VListContainerView.itemViews` for the lifetime of the list. Only the visible
/// subset is measured with Yoga and hosted in a cell. Truly virtualizing the item
/// views (creating/destroying them as rows scroll) is a larger change tracked
/// separately; do not describe this component as virtualized in the meantime.
///
/// Children inserted via the bridge are stored as table rows, not regular subviews.
/// Supports scroll and endReached events.
final class VListFactory: NativeComponentFactory {

    func createView() -> UIView {
        let container = VListContainerView()
        _ = container.flex
        return container
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let container = view as? VListContainerView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }
        switch key {
        case "estimatedItemHeight":
            container.estimatedItemHeight = CGFloat(value as? Double ?? 44)
        case "showsScrollIndicator":
            container.tableView.showsVerticalScrollIndicator = value as? Bool ?? true
        case "bounces":
            container.tableView.bounces = value as? Bool ?? true
        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let container = view as? VListContainerView else { return }
        switch event {
        case "scroll":
            container.onScroll = handler
            container.scrollThrottle = EventThrottle(interval: 0.016, handler: handler)
        case "endReached":
            container.onEndReached = handler
        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        guard let container = view as? VListContainerView else { return }
        switch event {
        case "scroll":
            container.onScroll = nil
            container.scrollThrottle = nil
        case "endReached": container.onEndReached = nil
        default: break
        }
    }

    // MARK: - Custom child management

    func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?) {
        guard let container = parent as? VListContainerView else {
            // Fallback for non-VList parents (shouldn't happen)
            if let anchor = anchor, let idx = parent.subviews.firstIndex(of: anchor) {
                parent.insertSubview(child, at: idx)
            } else {
                parent.addSubview(child)
            }
            return
        }
        let insertIdx: Int
        if let anchor = anchor, let idx = container.indexOfItem(anchor) {
            insertIdx = container.insertItem(child, at: idx)
        } else {
            insertIdx = container.appendItem(child)
        }
        // Trigger layout so Yoga can calculate item height before the cell is displayed
        container.setNeedsLayout()
        // Use targeted insert rather than reloadData to avoid triggering layoutSubviews recursively
        container.tableView.insertRows(at: [IndexPath(row: insertIdx, section: 0)], with: .none)
    }

    func removeChild(_ child: UIView, from parent: UIView) {
        guard let container = parent as? VListContainerView else {
            child.removeFromSuperview()
            return
        }
        guard let idx = container.indexOfItem(child) else {
            child.removeFromSuperview()
            return
        }
        container.removeItem(at: idx)
        // Remove from any cell it's currently displayed in
        child.removeFromSuperview()
        // Use targeted delete rather than reloadData
        container.tableView.deleteRows(at: [IndexPath(row: idx, section: 0)], with: .none)
    }
}

// MARK: - VListContainerView

/// Container view that hosts a UITableView filling its bounds.
/// Item views are managed in itemViews array (not as regular subviews).
final class VListContainerView: UIView {

    let tableView: UITableView

    /// One real `UIView` per row, retained for the lifetime of the list. Mutate only
    /// through ``appendItem(_:)`` / ``insertItem(_:at:)`` / ``removeItem(at:)`` so
    /// ``itemIndexes`` stays in sync.
    private(set) var itemViews: [UIView] = []

    /// Identity → row index for ``itemViews``, so locating a child (a removal, or an
    /// `insertBefore` anchor) is O(1) instead of an O(n) identity scan.
    ///
    /// This removes the *scan*, not the array shift: `Array.insert`/`remove` still
    /// move elements, so a mid-list edit stays O(n) and building a list purely from
    /// anchored inserts is still O(n²). Appends — the common case — remain O(1).
    /// Getting rid of the shift needs an order-maintenance structure, which belongs
    /// with the deferred item-view virtualization work.
    private var itemIndexes: [ObjectIdentifier: Int] = [:]

    var estimatedItemHeight: CGFloat = 44
    var onScroll: ((Any?) -> Void)?
    var scrollThrottle: EventThrottle?
    var onEndReached: ((Any?) -> Void)?
    fileprivate var firedEndReached = false
    /// Container width at which visible row heights were last invalidated. Used
    /// to detect width changes (e.g. rotation) without an O(n) item scan.
    private var lastMeasuredWidth: CGFloat = 0
    /// Re-entrancy guard: `reloadRows` asks for row heights, which run Yoga, which
    /// can trigger another `layoutSubviews` before the first one returns.
    private var isInvalidatingRowHeights = false
    private lazy var internalDelegate = VListInternalDelegate(container: self)

    init() {
        tableView = UITableView(frame: .zero, style: .plain)
        super.init(frame: .zero)
        tableView.separatorStyle = .none
        tableView.tableFooterView = UIView()
        tableView.dataSource = internalDelegate
        tableView.delegate = internalDelegate
        tableView.register(VListCell.self, forCellReuseIdentifier: "VListCell")
        // Add tableView as a real subview of self
        super.addSubview(tableView)

        // Accessibility: let VoiceOver navigate to individual children within the list
        isAccessibilityElement = false
        shouldGroupAccessibilityChildren = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        tableView.frame = bounds

        let width = bounds.width
        guard width > 0 else { return }

        // Row heights are computed lazily in heightForRowAt for the rows the
        // table actually displays. When the available width changes, previously
        // measured heights go stale, so invalidate only the visible rows;
        // off-screen rows re-measure on demand when they scroll into view. This
        // avoids an O(n) Yoga pass over every item on the first layout pass.
        guard abs(width - lastMeasuredWidth) > 0.5 else { return }

        // `reloadRows` re-enters layout: it asks for row heights, `measuredHeight`
        // runs Yoga, and Yoga can invalidate layout again. Guard the recursion, and
        // skip entirely while off-window — there are no visible rows to fix up and
        // `lastMeasuredWidth` is deliberately left stale so the invalidation still
        // happens on the next pass once the view is back in a window.
        guard window != nil, !isInvalidatingRowHeights else { return }

        let visible = tableView.indexPathsForVisibleRows ?? []
        guard !visible.isEmpty else {
            lastMeasuredWidth = width
            return
        }

        lastMeasuredWidth = width
        isInvalidatingRowHeights = true
        defer { isInvalidatingRowHeights = false }
        tableView.reloadRows(at: visible, with: .none)
    }

    // MARK: - Item storage

    /// Row index of `view`, or `nil` when it is not an item of this list.
    /// O(1) via ``itemIndexes``; a stale entry (one whose recorded slot no longer
    /// holds the same view) is treated as absent rather than trusted.
    func indexOfItem(_ view: UIView) -> Int? {
        guard let index = itemIndexes[ObjectIdentifier(view)],
              index < itemViews.count,
              itemViews[index] === view else {
            return nil
        }
        return index
    }

    /// Append `view` as the last row. O(1) amortized — no re-indexing needed.
    @discardableResult
    func appendItem(_ view: UIView) -> Int {
        let index = itemViews.count
        itemViews.append(view)
        itemIndexes[ObjectIdentifier(view)] = index
        return index
    }

    /// Insert `view` before the row currently at `index` (clamped to the valid
    /// range) and return the row it landed on.
    @discardableResult
    func insertItem(_ view: UIView, at index: Int) -> Int {
        let clamped = min(max(index, 0), itemViews.count)
        itemViews.insert(view, at: clamped)
        rebuildItemIndexes()
        return clamped
    }

    /// Remove and return the row at `index`. The caller must have obtained `index`
    /// from ``indexOfItem(_:)`` so it is in range.
    @discardableResult
    func removeItem(at index: Int) -> UIView {
        let removed = itemViews.remove(at: index)
        rebuildItemIndexes()
        return removed
    }

    private func rebuildItemIndexes() {
        itemIndexes.removeAll(keepingCapacity: true)
        for (index, view) in itemViews.enumerated() {
            itemIndexes[ObjectIdentifier(view)] = index
        }
    }

    /// Lazily measure a row's height at the current container width. Runs Yoga
    /// only when the row's width differs from the container (first measure or a
    /// width change), so off-screen rows never pay for layout until displayed.
    func measuredHeight(forRow row: Int) -> CGFloat {
        guard row < itemViews.count else { return estimatedItemHeight }
        let itemView = itemViews[row]
        let width = bounds.width
        if width > 0, abs(itemView.frame.size.width - width) > 0.5 {
            itemView.frame.size.width = width
            itemView.flex.layout(mode: .adjustHeight)
        }
        let height = itemView.frame.size.height
        return height > 1 ? height : estimatedItemHeight
    }
}

// MARK: - VListInternalDelegate

private final class VListInternalDelegate: NSObject,
    UITableViewDataSource, UITableViewDelegate {
    private weak var container: VListContainerView?

    init(container: VListContainerView) {
        self.container = container
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        container?.itemViews.count ?? 0
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "VListCell", for: indexPath) as? VListCell else {
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
        guard let container = container,
              indexPath.row < container.itemViews.count else { return cell }
        cell.setItemView(container.itemViews[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView,
                   estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        container?.estimatedItemHeight ?? 44
    }

    func tableView(_ tableView: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let container = container else { return 44 }
        return container.measuredHeight(forRow: indexPath.row)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let container = container else { return }
        let offset = scrollView.contentOffset
        let payload: [String: Any] = [
            "x": Double(offset.x),
            "y": Double(offset.y),
            "contentWidth": Double(scrollView.contentSize.width),
            "contentHeight": Double(scrollView.contentSize.height),
            "layoutWidth": Double(scrollView.frame.width),
            "layoutHeight": Double(scrollView.frame.height),
        ]
        // Use throttle if available, otherwise fire directly
        if let throttle = container.scrollThrottle {
            throttle.fire(payload)
        } else {
            container.onScroll?(payload)
        }

        // endReached detection (threshold = 20% from bottom)
        let contentH = scrollView.contentSize.height
        let frameH = scrollView.frame.size.height
        guard contentH > frameH else { return }
        let distanceFromBottom = contentH - frameH - offset.y
        let threshold = frameH * 0.2

        if distanceFromBottom < threshold && !container.firedEndReached {
            container.firedEndReached = true
            container.onEndReached?(nil)
        } else if distanceFromBottom >= threshold {
            container.firedEndReached = false
        }
    }
}

// MARK: - VListCell

final class VListCell: UITableViewCell {

    private var currentView: UIView?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        // Accessibility: cells are containers — VoiceOver should navigate to children inside
        isAccessibilityElement = false
        accessibilityTraits = .none
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func setItemView(_ view: UIView) {
        guard currentView !== view else { return }
        currentView?.removeFromSuperview()
        currentView = view
        contentView.addSubview(view)
        view.frame = contentView.bounds
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        currentView?.frame = contentView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        currentView?.removeFromSuperview()
        currentView = nil
    }
}
#endif
