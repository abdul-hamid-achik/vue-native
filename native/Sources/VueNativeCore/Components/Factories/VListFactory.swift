#if canImport(UIKit)
import UIKit
import FlexLayout

// MARK: - VListFactory

/// Factory for VList — a virtualized scrollable list backed by UITableView.
/// Children inserted via the bridge are stored as table cells, not regular subviews.
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
        case "endReached":
            container.onEndReached = handler
        default:
            break
        }
    }

    func removeEventListener(view: UIView, event: String) {
        guard let container = view as? VListContainerView else { return }
        switch event {
        case "scroll": container.onScroll = nil
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
        if let anchor = anchor, let idx = container.itemViews.firstIndex(where: { $0 === anchor }) {
            container.itemViews.insert(child, at: idx)
        } else {
            container.itemViews.append(child)
        }
        // Trigger layout so Yoga can calculate item heights
        container.setNeedsLayout()
        container.tableView.reloadData()
    }

    func removeChild(_ child: UIView, from parent: UIView) {
        guard let container = parent as? VListContainerView else {
            child.removeFromSuperview()
            return
        }
        container.itemViews.removeAll { $0 === child }
        // Remove from any cell it's currently displayed in
        child.removeFromSuperview()
        container.tableView.reloadData()
    }
}

// MARK: - VListContainerView

/// Container view that hosts a UITableView filling its bounds.
/// Item views are managed in itemViews array (not as regular subviews).
final class VListContainerView: UIView {

    let tableView: UITableView
    var itemViews: [UIView] = []
    var estimatedItemHeight: CGFloat = 44
    var onScroll: ((Any?) -> Void)?
    var onEndReached: ((Any?) -> Void)?
    fileprivate var firedEndReached = false
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
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        tableView.frame = bounds

        // Run Yoga layout on each item view to compute its height
        let width = bounds.width
        guard width > 0 else { return }

        var needsReload = false
        for itemView in itemViews {
            // Only recompute if width changed (avoids infinite layout loops)
            if abs(itemView.frame.size.width - width) > 0.5 {
                itemView.frame.size.width = width
                itemView.flex.layout(mode: .adjustHeight)
                needsReload = true
            }
        }
        if needsReload {
            tableView.reloadData()
        }
    }
}

// MARK: - VListInternalDelegate

private final class VListInternalDelegate: NSObject,
    UITableViewDataSource, UITableViewDelegate
{
    private weak var container: VListContainerView?

    init(container: VListContainerView) {
        self.container = container
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        container?.itemViews.count ?? 0
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "VListCell", for: indexPath) as! VListCell
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
        guard let container = container,
              indexPath.row < container.itemViews.count else {
            return container?.estimatedItemHeight ?? 44
        }
        let h = container.itemViews[indexPath.row].frame.size.height
        return h > 1 ? h : (container.estimatedItemHeight)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let container = container else { return }
        let offset = scrollView.contentOffset
        container.onScroll?(["x": Double(offset.x), "y": Double(offset.y)])

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

private final class VListCell: UITableViewCell {

    private var currentView: UIView?

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
