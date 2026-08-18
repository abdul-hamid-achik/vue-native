#if canImport(UIKit)
import UIKit
import FlexLayout

// MARK: - VSectionListFactory

/// Factory for VSectionList — a sectioned list backed by UITableView with section support.
/// Children with `__sectionHeader` prop are treated as section headers.
/// All other children are treated as regular items, grouped under the preceding header.
final class VSectionListFactory: NativeComponentFactory {

    func createView() -> UIView {
        let container = VSectionListContainerView()
        _ = container.flex
        return container
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let container = view as? VSectionListContainerView else {
            StyleEngine.apply(key: key, value: value, to: view)
            return
        }
        switch key {
        case "estimatedItemHeight":
            container.estimatedItemHeight = CGFloat(value as? Double ?? 44)
        case "stickySectionHeaders":
            container.applyStickySectionHeaders(value as? Bool ?? true)
        case "showsScrollIndicator":
            container.tableView.showsVerticalScrollIndicator = value as? Bool ?? true
        case "bounces":
            container.tableView.bounces = value as? Bool ?? true
        default:
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        guard let container = view as? VSectionListContainerView else { return }
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
        guard let container = view as? VSectionListContainerView else { return }
        switch event {
        case "scroll": container.onScroll = nil
        case "endReached": container.onEndReached = nil
        default: break
        }
    }

    // MARK: - Custom child management

    func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?) {
        guard let container = parent as? VSectionListContainerView else {
            if let anchor = anchor, let idx = parent.subviews.firstIndex(of: anchor) {
                parent.insertSubview(child, at: idx)
            } else {
                parent.addSubview(child)
            }
            return
        }
        container.applyChildMutation {
            if let anchor, let index = container.allChildren.firstIndex(where: { $0 === anchor }) {
                container.allChildren.insert(child, at: index)
            } else {
                container.allChildren.append(child)
            }
        }
    }

    func removeChild(_ child: UIView, from parent: UIView) {
        guard let container = parent as? VSectionListContainerView else {
            child.removeFromSuperview()
            return
        }
        container.applyChildMutation {
            container.allChildren.removeAll { $0 === child }
            child.removeFromSuperview()
        }
    }
}

// MARK: - SectionData

/// Represents a section: an optional header view and an array of item views.
private struct SectionData {
    var headerView: UIView?
    var itemViews: [UIView]
}

// MARK: - VSectionListContainerView

/// Container view that hosts a UITableView with section support.
final class VSectionListContainerView: UIView {

    private(set) var tableView: UITableView
    var allChildren: [UIView] = []
    var estimatedItemHeight: CGFloat = 44
    var stickySectionHeaders: Bool = true
    var onScroll: ((Any?) -> Void)?
    var onEndReached: ((Any?) -> Void)?
    fileprivate var firedEndReached = false
    fileprivate var sections: [SectionData] = []
    private lazy var internalDelegate = VSectionListInternalDelegate(container: self)

    init() {
        tableView = UITableView(frame: .zero, style: .plain)
        super.init(frame: .zero)
        configureTableView(tableView)
        super.addSubview(tableView)
    }

    func applyStickySectionHeaders(_ sticky: Bool) {
        guard stickySectionHeaders != sticky else { return }
        stickySectionHeaders = sticky
        recreateTableView(style: sticky ? .plain : .grouped)
    }

    private func configureTableView(_ table: UITableView) {
        table.separatorStyle = .none
        table.tableFooterView = UIView()
        table.backgroundColor = .clear
        table.backgroundView = nil
        table.dataSource = internalDelegate
        table.delegate = internalDelegate
        table.register(VListCell.self, forCellReuseIdentifier: "VListCell")
        if #available(iOS 15.0, *) {
            table.sectionHeaderTopPadding = 0
        }
    }

    private func recreateTableView(style: UITableView.Style) {
        guard tableView.style != style else { return }
        let showsIndicator = tableView.showsVerticalScrollIndicator
        let bounces = tableView.bounces
        let offset = tableView.contentOffset
        tableView.removeFromSuperview()
        tableView = UITableView(frame: bounds, style: style)
        configureTableView(tableView)
        tableView.showsVerticalScrollIndicator = showsIndicator
        tableView.bounces = bounces
        addSubview(tableView)
        tableView.reloadData()
        tableView.setContentOffset(offset, animated: false)
        setNeedsLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func applyChildMutation(_ mutate: () -> Void) {
        let oldSections = sections
        mutate()
        let newSections = makeSections(from: allChildren)

        // UITableView snapshots the data source before performBatchUpdates.
        // Keep `sections` as the old snapshot until we are inside the batch,
        // otherwise insert/delete row counts disagree with the data source.
        // Off-screen tables and section-count changes use a full reload.
        if tableView.window == nil || oldSections.count != newSections.count {
            sections = newSections
            tableView.reloadData()
            return
        }

        tableView.performBatchUpdates({
            self.sections = newSections
            for section in 0..<newSections.count {
                let oldItems = oldSections[section].itemViews
                let newItems = newSections[section].itemViews
                let deletes = oldItems.enumerated().compactMap { index, view -> IndexPath? in
                    newItems.contains(where: { $0 === view }) ? nil : IndexPath(row: index, section: section)
                }
                let inserts = newItems.enumerated().compactMap { index, view -> IndexPath? in
                    oldItems.contains(where: { $0 === view }) ? nil : IndexPath(row: index, section: section)
                }
                if !deletes.isEmpty {
                    tableView.deleteRows(at: deletes, with: .none)
                }
                if !inserts.isEmpty {
                    tableView.insertRows(at: inserts, with: .none)
                }
            }
        }, completion: nil)
    }

    /// Rebuild section data from the flat allChildren array.
    /// Children that had the `__sectionHeader: true` prop set via the bridge start a new section.
    func rebuildSections() {
        sections = makeSections(from: allChildren)
    }

    private func makeSections(from children: [UIView]) -> [SectionData] {
        var next: [SectionData] = []
        var currentSection = SectionData(headerView: nil, itemViews: [])

        for child in children {
            let isSectionHeader = StyleEngine.getInternalProp("__sectionHeader", from: child) as? Bool ?? false
            if isSectionHeader {
                if currentSection.headerView != nil || !currentSection.itemViews.isEmpty {
                    next.append(currentSection)
                }
                currentSection = SectionData(headerView: child, itemViews: [])
            } else {
                currentSection.itemViews.append(child)
            }
        }
        if currentSection.headerView != nil || !currentSection.itemViews.isEmpty {
            next.append(currentSection)
        }
        return next
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        tableView.frame = bounds

        let width = bounds.width
        guard width > 0 else { return }

        // Lay out all child views for height calculation. Keep track of the
        // rows whose measured width changed so we can refresh only affected
        // table sections/rows; reloading the whole table from layoutSubviews
        // can re-enter layout and is especially expensive for large lists.
        var changedChildren = Set<ObjectIdentifier>()
        for child in allChildren where abs(child.frame.size.width - width) > 0.5 {
            child.frame.size.width = width
            child.flex.layout(mode: .adjustHeight)
            changedChildren.insert(ObjectIdentifier(child))
        }

        guard !changedChildren.isEmpty else { return }

        var changedSections = IndexSet()
        var changedRows: [IndexPath] = []
        for (sectionIndex, section) in sections.enumerated() {
            if let header = section.headerView,
               changedChildren.contains(ObjectIdentifier(header)) {
                changedSections.insert(sectionIndex)
            }

            for (rowIndex, item) in section.itemViews.enumerated()
                where changedChildren.contains(ObjectIdentifier(item)) {
                changedRows.append(IndexPath(row: rowIndex, section: sectionIndex))
            }
        }

        if !changedSections.isEmpty {
            tableView.reloadSections(changedSections, with: .none)
        }

        let rowsOutsideReloadedSections = changedRows.filter {
            !changedSections.contains($0.section)
        }
        if !rowsOutsideReloadedSections.isEmpty {
            tableView.reloadRows(at: rowsOutsideReloadedSections, with: .none)
        }
    }
}

// MARK: - VSectionListInternalDelegate

private final class VSectionListInternalDelegate: NSObject,
    UITableViewDataSource, UITableViewDelegate {
    private weak var container: VSectionListContainerView?

    init(container: VSectionListContainerView) {
        self.container = container
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        container?.sections.count ?? 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let container = container, section < container.sections.count else { return 0 }
        return container.sections[section].itemViews.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "VListCell", for: indexPath) as? VListCell else {
            return UITableViewCell(style: .default, reuseIdentifier: nil)
        }
        guard let container = container,
              indexPath.section < container.sections.count,
              indexPath.row < container.sections[indexPath.section].itemViews.count else { return cell }
        cell.setItemView(container.sections[indexPath.section].itemViews[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView,
                   viewForHeaderInSection section: Int) -> UIView? {
        guard let container = container, section < container.sections.count else { return nil }
        return container.sections[section].headerView
    }

    func tableView(_ tableView: UITableView,
                   heightForHeaderInSection section: Int) -> CGFloat {
        guard let container = container, section < container.sections.count,
              let header = container.sections[section].headerView else { return 0 }
        let h = header.frame.size.height
        return h > 1 ? h : container.estimatedItemHeight
    }

    func tableView(_ tableView: UITableView,
                   estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        container?.estimatedItemHeight ?? 44
    }

    func tableView(_ tableView: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let container = container,
              indexPath.section < container.sections.count,
              indexPath.row < container.sections[indexPath.section].itemViews.count else {
            return container?.estimatedItemHeight ?? 44
        }
        let h = container.sections[indexPath.section].itemViews[indexPath.row].frame.size.height
        return h > 1 ? h : container.estimatedItemHeight
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let container = container else { return }
        let offset = scrollView.contentOffset
        container.onScroll?(["x": Double(offset.x), "y": Double(offset.y)])

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

// Reuses VListCell from VListFactory (same module)
#endif
