import AppKit
import ObjectiveC

// MARK: - Layout Value

/// Represents a layout dimension value that can be points, percent, or auto.
public enum LayoutValue: Equatable {
    case points(CGFloat)
    case percent(CGFloat)
    case auto
    case undefined

    var isUndefined: Bool {
        if case .undefined = self { return true }
        return false
    }

    func resolve(relativeTo parent: CGFloat) -> CGFloat? {
        switch self {
        case .points(let v): return v
        case .percent(let v): return parent * v / 100.0
        case .auto, .undefined: return nil
        }
    }
}

// MARK: - Layout Enums

public enum FlexDirection {
    case column, row, columnReverse, rowReverse

    var isRow: Bool {
        self == .row || self == .rowReverse
    }
    var isReverse: Bool {
        self == .columnReverse || self == .rowReverse
    }
}

public enum JustifyContent {
    case flexStart, flexEnd, center, spaceBetween, spaceAround, spaceEvenly
}

public enum AlignItems {
    case stretch, flexStart, flexEnd, center, baseline
}

public enum AlignSelf {
    case auto, stretch, flexStart, flexEnd, center, baseline
}

public enum PositionType {
    case relative, absolute
}

public enum DisplayType {
    case flex, none
}

public enum FlexWrap {
    case noWrap, wrap, wrapReverse
}

// MARK: - Edges

/// Stores inset values (top, right, bottom, left).
public struct EdgeInsets: Equatable {
    public var top: CGFloat
    public var right: CGFloat
    public var bottom: CGFloat
    public var left: CGFloat

    public static let zero = EdgeInsets(top: 0, right: 0, bottom: 0, left: 0)

    public var horizontal: CGFloat { left + right }
    public var vertical: CGFloat { top + bottom }
}

// MARK: - LayoutNode

/// A simplified flexbox layout node. Stores flex properties and computes frames
/// for its children. Associates with an NSView via objc_setAssociatedObject.
///
/// This implements a subset of the CSS Flexbox specification sufficient for
/// Phase 1 (counter app): direction, justify, align, padding, margin, gap,
/// flex grow/shrink, and basic dimensions.
@MainActor
public final class LayoutNode {

    // MARK: - Flex container properties

    public var flexDirection: FlexDirection = .column
    public var justifyContent: JustifyContent = .flexStart
    public var alignItems: AlignItems = .stretch
    public var alignContent: AlignItems = .stretch
    public var flexWrap: FlexWrap = .noWrap

    // MARK: - Flex item properties

    public var flexGrow: CGFloat = 0
    public var flexShrink: CGFloat = 1
    public var flexBasis: LayoutValue = .undefined
    public var alignSelf: AlignSelf = .auto

    // MARK: - Dimensions

    public var width: LayoutValue = .undefined
    public var height: LayoutValue = .undefined
    public var minWidth: LayoutValue = .undefined
    public var minHeight: LayoutValue = .undefined
    public var maxWidth: LayoutValue = .undefined
    public var maxHeight: LayoutValue = .undefined
    public var aspectRatio: CGFloat?

    // MARK: - Spacing

    public var padding: EdgeInsets = .zero
    public var margin: EdgeInsets = .zero

    /// Main axis gap between children (columnGap for row, rowGap for column).
    public var gap: CGFloat = 0
    public var rowGap: CGFloat?
    public var columnGap: CGFloat?

    // MARK: - Position

    public var positionType: PositionType = .relative
    public var positionTop: LayoutValue = .undefined
    public var positionRight: LayoutValue = .undefined
    public var positionBottom: LayoutValue = .undefined
    public var positionLeft: LayoutValue = .undefined

    // MARK: - Display

    public var display: DisplayType = .flex
    public var isEnabled: Bool = true

    // MARK: - Direction (RTL/LTR)

    public var layoutDirection: NSUserInterfaceLayoutDirection = .leftToRight

    // MARK: - View association

    weak var view: NSView?
    var isDirty: Bool = true

    // MARK: - Computed results

    /// The computed frame after layout. Relative to parent's content area.
    public var computedFrame: CGRect = .zero

    // MARK: - Children

    /// Returns the LayoutNode children by inspecting the view's subviews.
    var children: [LayoutNode] {
        guard let view = view else { return [] }
        return view.subviews.compactMap { $0.layoutNode }
    }

    // MARK: - Mark dirty

    public func markDirty() {
        isDirty = true
        view?.needsLayout = true
    }

    // MARK: - Layout algorithm

    /// Perform layout calculation. Sets frames on all child views recursively.
    /// - Parameters:
    ///   - availableWidth: The width available from the parent.
    ///   - availableHeight: The height available from the parent.
    public func layout(availableWidth: CGFloat, availableHeight: CGFloat) {
        guard display != .none else { return }

        let resolvedWidth = width.resolve(relativeTo: availableWidth) ?? availableWidth
        let resolvedHeight = height.resolve(relativeTo: availableHeight) ?? availableHeight

        let constrainedWidth = constrain(resolvedWidth, min: minWidth.resolve(relativeTo: availableWidth), max: maxWidth.resolve(relativeTo: availableWidth))
        let constrainedHeight = constrain(resolvedHeight, min: minHeight.resolve(relativeTo: availableHeight), max: maxHeight.resolve(relativeTo: availableHeight))

        let contentWidth = constrainedWidth - padding.horizontal
        let contentHeight = constrainedHeight - padding.vertical

        // Separate children into relative (flex) and absolute positioned
        let allChildren = children
        let relativeChildren = allChildren.filter { $0.positionType == .relative && $0.display != .none }
        let absoluteChildren = allChildren.filter { $0.positionType == .absolute && $0.display != .none }

        // Compute main axis gap
        let mainGap: CGFloat
        if flexDirection.isRow {
            mainGap = columnGap ?? gap
        } else {
            mainGap = rowGap ?? gap
        }

        // Phase 1: Measure children along main axis (hypothetical size)
        let isRow = flexDirection.isRow
        let mainSize = isRow ? contentWidth : contentHeight
        let crossSize = isRow ? contentHeight : contentWidth

        struct ChildMeasure {
            let node: LayoutNode
            var mainHypothetical: CGFloat
            var crossHypothetical: CGFloat
            var flexBasis: CGFloat
            var mainFinal: CGFloat = 0
            var crossFinal: CGFloat = 0
            var mainMarginBefore: CGFloat
            var mainMarginAfter: CGFloat
            var crossMarginBefore: CGFloat
            var crossMarginAfter: CGFloat
        }

        var measures: [ChildMeasure] = relativeChildren.map { child in
            // Resolve flex basis
            let basis: CGFloat
            if let b = child.flexBasis.resolve(relativeTo: mainSize), !child.flexBasis.isUndefined {
                basis = b
            } else if isRow, let w = child.width.resolve(relativeTo: contentWidth) {
                basis = w
            } else if !isRow, let h = child.height.resolve(relativeTo: contentHeight) {
                basis = h
            } else {
                // Content-based sizing: use the view's fittingSize as an estimate
                basis = 0
            }

            let crossHyp: CGFloat
            if isRow {
                crossHyp = child.height.resolve(relativeTo: contentHeight) ?? crossSize
            } else {
                crossHyp = child.width.resolve(relativeTo: contentWidth) ?? crossSize
            }

            let mainMarginBefore: CGFloat
            let mainMarginAfter: CGFloat
            let crossMarginBefore: CGFloat
            let crossMarginAfter: CGFloat
            if isRow {
                mainMarginBefore = child.margin.left
                mainMarginAfter = child.margin.right
                crossMarginBefore = child.margin.top
                crossMarginAfter = child.margin.bottom
            } else {
                mainMarginBefore = child.margin.top
                mainMarginAfter = child.margin.bottom
                crossMarginBefore = child.margin.left
                crossMarginAfter = child.margin.right
            }

            return ChildMeasure(
                node: child,
                mainHypothetical: basis,
                crossHypothetical: crossHyp,
                flexBasis: basis,
                mainMarginBefore: mainMarginBefore,
                mainMarginAfter: mainMarginAfter,
                crossMarginBefore: crossMarginBefore,
                crossMarginAfter: crossMarginAfter
            )
        }

        // Phase 2: Flex grow/shrink
        let totalGaps = measures.count > 1 ? mainGap * CGFloat(measures.count - 1) : 0
        let totalMargins = measures.reduce(CGFloat(0)) { $0 + $1.mainMarginBefore + $1.mainMarginAfter }
        let usedSpace = measures.reduce(CGFloat(0)) { $0 + $1.flexBasis } + totalGaps + totalMargins
        let freeSpace = mainSize - usedSpace

        let totalGrow = measures.reduce(CGFloat(0)) { $0 + $1.node.flexGrow }
        let totalShrink = measures.reduce(CGFloat(0)) { $0 + ($1.node.flexShrink * $1.flexBasis) }

        for i in measures.indices {
            if freeSpace > 0 && totalGrow > 0 {
                measures[i].mainFinal = measures[i].flexBasis + (freeSpace * measures[i].node.flexGrow / totalGrow)
            } else if freeSpace < 0 && totalShrink > 0 {
                let shrinkRatio = (measures[i].node.flexShrink * measures[i].flexBasis) / totalShrink
                measures[i].mainFinal = measures[i].flexBasis + (freeSpace * shrinkRatio)
            } else {
                measures[i].mainFinal = measures[i].flexBasis
            }

            // Clamp to min/max
            let child = measures[i].node
            if isRow {
                measures[i].mainFinal = constrain(measures[i].mainFinal, min: child.minWidth.resolve(relativeTo: contentWidth), max: child.maxWidth.resolve(relativeTo: contentWidth))
            } else {
                measures[i].mainFinal = constrain(measures[i].mainFinal, min: child.minHeight.resolve(relativeTo: contentHeight), max: child.maxHeight.resolve(relativeTo: contentHeight))
            }

            // Ensure non-negative
            measures[i].mainFinal = max(0, measures[i].mainFinal)
        }

        // Phase 3: Cross axis sizing (alignItems)
        for i in measures.indices {
            let child = measures[i].node
            let resolvedAlign = child.alignSelf == .auto ? alignItems : alignSelfToAlignItems(child.alignSelf)

            if resolvedAlign == .stretch {
                measures[i].crossFinal = crossSize - measures[i].crossMarginBefore - measures[i].crossMarginAfter
            } else {
                measures[i].crossFinal = measures[i].crossHypothetical
            }

            // Apply aspect ratio
            if let ar = child.aspectRatio, ar > 0 {
                if isRow {
                    measures[i].crossFinal = measures[i].mainFinal / ar
                } else {
                    measures[i].crossFinal = measures[i].mainFinal * ar
                }
            }

            // Clamp cross to min/max
            if isRow {
                measures[i].crossFinal = constrain(measures[i].crossFinal, min: child.minHeight.resolve(relativeTo: contentHeight), max: child.maxHeight.resolve(relativeTo: contentHeight))
            } else {
                measures[i].crossFinal = constrain(measures[i].crossFinal, min: child.minWidth.resolve(relativeTo: contentWidth), max: child.maxWidth.resolve(relativeTo: contentWidth))
            }

            measures[i].crossFinal = max(0, measures[i].crossFinal)
        }

        // Phase 4: Main axis positioning (justifyContent)
        let totalChildMainSize = measures.reduce(CGFloat(0)) { $0 + $1.mainFinal + $1.mainMarginBefore + $1.mainMarginAfter }
        let remainingMain = mainSize - totalChildMainSize - totalGaps

        var mainOffset: CGFloat = 0
        var mainSpacing: CGFloat = mainGap

        switch justifyContent {
        case .flexStart:
            mainOffset = 0
        case .flexEnd:
            mainOffset = remainingMain
        case .center:
            mainOffset = remainingMain / 2
        case .spaceBetween:
            mainOffset = 0
            if measures.count > 1 {
                mainSpacing = mainGap + remainingMain / CGFloat(measures.count - 1)
            }
        case .spaceAround:
            let space = remainingMain / CGFloat(measures.count)
            mainOffset = space / 2
            mainSpacing = mainGap + space
        case .spaceEvenly:
            let space = remainingMain / CGFloat(measures.count + 1)
            mainOffset = space
            mainSpacing = mainGap + space
        }

        // Phase 5: Position children
        var currentMain = mainOffset
        let orderedMeasures = flexDirection.isReverse ? measures.reversed() : Array(measures)

        for measure in orderedMeasures {
            let child = measure.node
            currentMain += measure.mainMarginBefore

            let resolvedAlign = child.alignSelf == .auto ? alignItems : alignSelfToAlignItems(child.alignSelf)

            let crossOffset: CGFloat
            switch resolvedAlign {
            case .flexStart:
                crossOffset = measure.crossMarginBefore
            case .flexEnd:
                crossOffset = crossSize - measure.crossFinal - measure.crossMarginAfter
            case .center:
                crossOffset = (crossSize - measure.crossFinal) / 2
            case .stretch, .baseline:
                crossOffset = measure.crossMarginBefore
            }

            let x: CGFloat
            let y: CGFloat
            let w: CGFloat
            let h: CGFloat

            if isRow {
                x = padding.left + currentMain
                y = padding.top + crossOffset
                w = measure.mainFinal
                h = measure.crossFinal
            } else {
                x = padding.left + crossOffset
                y = padding.top + currentMain
                w = measure.crossFinal
                h = measure.mainFinal
            }

            child.computedFrame = CGRect(x: x, y: y, width: w, height: h)
            child.view?.frame = child.computedFrame

            // Recurse into child
            child.layout(availableWidth: w, availableHeight: h)

            currentMain += measure.mainFinal + measure.mainMarginAfter + mainSpacing
        }

        // Phase 6: Absolute positioned children
        for child in absoluteChildren {
            let childW = child.width.resolve(relativeTo: constrainedWidth) ?? 0
            let childH = child.height.resolve(relativeTo: constrainedHeight) ?? 0

            var x: CGFloat = padding.left
            var y: CGFloat = padding.top

            if let left = child.positionLeft.resolve(relativeTo: constrainedWidth) {
                x = left + child.margin.left
            } else if let right = child.positionRight.resolve(relativeTo: constrainedWidth) {
                x = constrainedWidth - right - childW - child.margin.right
            }

            if let top = child.positionTop.resolve(relativeTo: constrainedHeight) {
                y = top + child.margin.top
            } else if let bottom = child.positionBottom.resolve(relativeTo: constrainedHeight) {
                y = constrainedHeight - bottom - childH - child.margin.bottom
            }

            child.computedFrame = CGRect(x: x, y: y, width: childW, height: childH)
            child.view?.frame = child.computedFrame

            child.layout(availableWidth: childW, availableHeight: childH)
        }

        isDirty = false
    }

    // MARK: - Helpers

    private func constrain(_ value: CGFloat, min: CGFloat?, max: CGFloat?) -> CGFloat {
        var result = value
        if let min = min { result = Swift.max(result, min) }
        if let max = max { result = Swift.min(result, max) }
        return result
    }

    private func alignSelfToAlignItems(_ alignSelf: AlignSelf) -> AlignItems {
        switch alignSelf {
        case .auto: return .stretch
        case .stretch: return .stretch
        case .flexStart: return .flexStart
        case .flexEnd: return .flexEnd
        case .center: return .center
        case .baseline: return .baseline
        }
    }
}

// MARK: - NSView extension

private var layoutNodeKey: UInt8 = 0

extension NSView {
    /// Access the LayoutNode associated with this view. Creates one on first access.
    public var layoutNode: LayoutNode? {
        get {
            objc_getAssociatedObject(self, &layoutNodeKey) as? LayoutNode
        }
        set {
            objc_setAssociatedObject(self, &layoutNodeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            newValue?.view = self
        }
    }

    /// Convenience: returns or creates a LayoutNode for this view.
    @discardableResult
    public func ensureLayoutNode() -> LayoutNode {
        if let existing = layoutNode { return existing }
        let node = LayoutNode()
        self.layoutNode = node
        return node
    }
}

// MARK: - Percentage postfix operator

postfix operator %

public postfix func % (value: CGFloat) -> LayoutValue {
    return .percent(value)
}

public postfix func % (value: Int) -> LayoutValue {
    return .percent(CGFloat(value))
}

public postfix func % (value: Double) -> LayoutValue {
    return .percent(CGFloat(value))
}
