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

    /// Written by `markDirty()` and cleared at the end of a layout pass, but
    /// deliberately **not** read to short-circuit work.
    ///
    /// A previous attempt to skip clean subtrees regressed layout: `isDirty` is
    /// only raised by `StyleEngine` when a *style* changes, never when the view
    /// tree changes (`appendChild`/`insertBefore`/`removeChild` go straight to
    /// `NSView.addSubview` and never touch this node), so a freshly inserted
    /// child would be skipped and never positioned. Honouring the flag safely
    /// needs dirt to propagate upward from every tree mutation site plus a
    /// cached `children` array invalidated at the same points — do not add a
    /// short-circuit here without both.
    var isDirty: Bool = true

    // MARK: - Content measurement

    /// Content-measurement hook, the equivalent of Yoga's `YGMeasureFunc`.
    ///
    /// Consulted during layout whenever this node has no definite size on an
    /// axis, so a text label or an image can size itself from its content
    /// instead of collapsing to zero.
    ///
    /// - Parameter availableSize: the space the parent can offer. The component
    ///   along the container's cross axis is the real constraint (so wrapping
    ///   text can measure against it); the component along the main axis is
    ///   `CGFloat.greatestFiniteMagnitude` when unbounded.
    /// - Returns: the ideal content size in points. Negative values are clamped
    ///   to zero.
    public var measure: ((_ availableSize: CGSize) -> CGSize)?

    /// Whether this node can report a content size at all.
    ///
    /// `true` when an explicit `measure` hook is installed or when the attached
    /// view has an intrinsic content size (labels, buttons, images). Plain
    /// container views report `false`: this engine has no bottom-up sizing, so
    /// their content size is always zero and the cross axis keeps its legacy
    /// "fill the parent" behaviour rather than collapsing.
    var measuresContent: Bool {
        if measure != nil { return true }
        guard let view else { return false }
        let intrinsic = view.intrinsicContentSize
        return intrinsic.width >= 0 || intrinsic.height >= 0
    }

    /// Resolve this node's content size. Explicit `measure` hook first, then the
    /// attached view's `fittingSize` (only for views that actually have an
    /// intrinsic content size — a bare `FlippedView` reports `(0, 0)` and must
    /// keep contributing zero so flex grow/shrink behaviour is unchanged).
    func contentSize(availableSize: CGSize) -> CGSize {
        if let measure {
            let size = measure(availableSize)
            return CGSize(width: Swift.max(0, size.width), height: Swift.max(0, size.height))
        }
        guard measuresContent, let view else { return .zero }
        let size = view.fittingSize
        return CGSize(width: Swift.max(0, size.width), height: Swift.max(0, size.height))
    }

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

    /// Perform layout calculation for a *root* node: resolves this node's own
    /// `width`/`height` against the space offered by its parent, then lays out
    /// its children. Sets frames on all descendant views recursively.
    ///
    /// Children are never laid out through this entry point — the parent already
    /// resolved their frame, so it calls ``layoutChildren(width:height:)`` with
    /// a definite size. Going through `layout()` again would re-resolve a
    /// percentage child against its own already-resolved size, halving it at
    /// every level of nesting.
    ///
    /// - Parameters:
    ///   - availableWidth: The width available from the parent.
    ///   - availableHeight: The height available from the parent.
    public func layout(availableWidth: CGFloat, availableHeight: CGFloat) {
        guard display != .none else { return }

        let resolvedWidth = width.resolve(relativeTo: availableWidth) ?? availableWidth
        let resolvedHeight = height.resolve(relativeTo: availableHeight) ?? availableHeight

        let constrainedWidth = constrain(resolvedWidth, min: minWidth.resolve(relativeTo: availableWidth), max: maxWidth.resolve(relativeTo: availableWidth))
        let constrainedHeight = constrain(resolvedHeight, min: minHeight.resolve(relativeTo: availableHeight), max: maxHeight.resolve(relativeTo: availableHeight))

        layoutChildren(width: constrainedWidth, height: constrainedHeight)
    }

    /// Lay out this node's children inside an already-resolved, definite box.
    ///
    /// `resolvedWidth`/`resolvedHeight` are final: `width`, `height` and their
    /// min/max constraints have already been applied by whoever sized this node
    /// (the parent's layout pass, or ``layout(availableWidth:availableHeight:)``
    /// for a root).
    func layoutChildren(width resolvedWidth: CGFloat, height resolvedHeight: CGFloat) {
        guard display != .none else { return }

        let constrainedWidth = resolvedWidth
        let constrainedHeight = resolvedHeight

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
            var crossIsAuto: Bool
            var mainIsAuto: Bool
            var flexBasis: CGFloat
            var mainFinal: CGFloat = 0
            var crossFinal: CGFloat = 0
            var mainMarginBefore: CGFloat
            var mainMarginAfter: CGFloat
            var crossMarginBefore: CGFloat
            var crossMarginAfter: CGFloat
        }

        var measures: [ChildMeasure] = relativeChildren.map { child in
            // Resolve flex basis. `nil` means "auto on the main axis" and the
            // child must be sized from its content instead.
            let basisExplicit: CGFloat?
            if !child.flexBasis.isUndefined, let b = child.flexBasis.resolve(relativeTo: mainSize) {
                basisExplicit = b
            } else if isRow, let w = child.width.resolve(relativeTo: contentWidth) {
                basisExplicit = w
            } else if !isRow, let h = child.height.resolve(relativeTo: contentHeight) {
                basisExplicit = h
            } else {
                basisExplicit = nil
            }

            let crossResolved: CGFloat?
            if isRow {
                crossResolved = child.height.resolve(relativeTo: contentHeight)
            } else {
                crossResolved = child.width.resolve(relativeTo: contentWidth)
            }

            let mainIsAuto = basisExplicit == nil
            // `align-items: stretch` must only apply when the cross-axis size is
            // auto/undefined. A definite cross size (e.g. width: 50%) wins over
            // stretch, matching CSS/Yoga behaviour on iOS and Android.
            let crossIsAuto = crossResolved == nil

            // Content-based sizing: ask the child to measure itself. Only done
            // when at least one axis is auto, so a fully-sized subtree never
            // pays for measurement. `availableSize` carries the real cross-axis
            // constraint (wrapping text measures against it) and leaves the main
            // axis unbounded.
            let content: CGSize
            if (mainIsAuto || crossIsAuto) && child.measuresContent {
                content = child.contentSize(availableSize: CGSize(
                    width: isRow ? CGFloat.greatestFiniteMagnitude : Swift.max(0, crossSize),
                    height: isRow ? Swift.max(0, crossSize) : CGFloat.greatestFiniteMagnitude
                ))
            } else {
                content = .zero
            }

            let basis = basisExplicit ?? (isRow ? content.width : content.height)

            // A child that can report content sizes is sized to its content on
            // the cross axis (capped so long unwrapped text cannot overflow the
            // container). A plain container has no bottom-up sizing in this
            // engine, so it keeps filling the available cross size.
            let crossHyp: CGFloat
            if let crossResolved {
                crossHyp = crossResolved
            } else if child.measuresContent {
                let contentCross = isRow ? content.height : content.width
                crossHyp = Swift.min(contentCross, Swift.max(0, crossSize))
            } else {
                crossHyp = crossSize
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
                crossIsAuto: crossIsAuto,
                mainIsAuto: mainIsAuto,
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

        // Phase 2b: redistribute space freed (or newly consumed) by the min/max
        // clamps above. Without this pass a `maxWidth`-capped `flex: 1` sibling
        // leaves dead space that CSS/Yoga would hand to the other flexible
        // siblings. Only items whose clamp did not bind participate, so the
        // redistribution cannot violate a min/max, and it runs once (a second
        // round could only be triggered by a clamp that the first round already
        // excluded).
        if !measures.isEmpty {
            let clampedTotal = measures.reduce(CGFloat(0)) { $0 + $1.mainFinal }
            let leftover = mainSize - clampedTotal - totalGaps - totalMargins
            if abs(leftover) > 0.01 {
                let candidates = measures.indices.filter { i in
                    // Flexible, and not already pinned by a min/max clamp.
                    let flexible = leftover > 0 ? measures[i].node.flexGrow > 0 : measures[i].node.flexShrink > 0
                    guard flexible else { return false }
                    let child = measures[i].node
                    let lower = isRow
                        ? child.minWidth.resolve(relativeTo: contentWidth)
                        : child.minHeight.resolve(relativeTo: contentHeight)
                    let upper = isRow
                        ? child.maxWidth.resolve(relativeTo: contentWidth)
                        : child.maxHeight.resolve(relativeTo: contentHeight)
                    if leftover > 0, let upper, measures[i].mainFinal >= upper { return false }
                    if leftover < 0, let lower, measures[i].mainFinal <= lower { return false }
                    return true
                }
                if !candidates.isEmpty {
                    let totalWeight = candidates.reduce(CGFloat(0)) { acc, i in
                        acc + (leftover > 0 ? measures[i].node.flexGrow : measures[i].node.flexShrink * measures[i].flexBasis)
                    }
                    if totalWeight > 0 {
                        for i in candidates {
                            let weight = leftover > 0
                                ? measures[i].node.flexGrow
                                : measures[i].node.flexShrink * measures[i].flexBasis
                            let child = measures[i].node
                            let grown = measures[i].mainFinal + leftover * weight / totalWeight
                            measures[i].mainFinal = max(0, constrain(
                                grown,
                                min: isRow ? child.minWidth.resolve(relativeTo: contentWidth) : child.minHeight.resolve(relativeTo: contentHeight),
                                max: isRow ? child.maxWidth.resolve(relativeTo: contentWidth) : child.maxHeight.resolve(relativeTo: contentHeight)
                            ))
                        }
                    }
                }
            }
        }

        // Phase 3: Cross axis sizing (alignItems)
        for i in measures.indices {
            let child = measures[i].node
            let resolvedAlign = child.alignSelf == .auto ? alignItems : alignSelfToAlignItems(child.alignSelf)

            if resolvedAlign == .stretch && measures[i].crossIsAuto {
                measures[i].crossFinal = crossSize - measures[i].crossMarginBefore - measures[i].crossMarginAfter
            } else {
                measures[i].crossFinal = measures[i].crossHypothetical
            }

            // Apply aspect ratio. A definite cross size always wins (CSS: an
            // explicit `width` in a column container is not overridden by
            // `aspectRatio`), so the ratio is only consulted when the cross
            // axis is auto.
            if let ar = child.aspectRatio, ar > 0, measures[i].crossIsAuto {
                if measures[i].mainIsAuto {
                    // Main axis is auto too: nothing to derive from, keep the
                    // content-based cross size.
                } else if isRow {
                    measures[i].crossFinal = measures[i].mainFinal / ar
                } else {
                    measures[i].crossFinal = measures[i].mainFinal * ar
                }
            } else if let ar = child.aspectRatio, ar > 0, measures[i].mainIsAuto {
                // Cross size is definite and the main size is not: derive the
                // main size from the ratio.
                if isRow {
                    measures[i].mainFinal = measures[i].crossFinal * ar
                } else {
                    measures[i].mainFinal = measures[i].crossFinal / ar
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

        // Phase 5: Position children.
        //
        // `mainOffset`/`mainSpacing` are expressed from *main-start*. For a
        // `*-reverse` direction main-start is the far edge (right for
        // row-reverse, bottom for column-reverse), so the cursor is walked from
        // that edge and each child's leading coordinate is mirrored into the
        // content box. Children are walked in document order either way: the
        // first child always sits nearest main-start.
        let isReverse = flexDirection.isReverse
        var cursor = mainOffset

        for measure in measures {
            let child = measure.node
            cursor += measure.mainMarginBefore
            let mainEnd = cursor + measure.mainFinal
            let mainStart = isReverse ? mainSize - mainEnd : cursor

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
                x = padding.left + mainStart
                y = padding.top + crossOffset
                w = measure.mainFinal
                h = measure.crossFinal
            } else {
                x = padding.left + crossOffset
                y = padding.top + mainStart
                w = measure.crossFinal
                h = measure.mainFinal
            }

            child.computedFrame = CGRect(x: x, y: y, width: w, height: h)
            child.view?.frame = child.computedFrame

            // Recurse with the size this pass already resolved. Going through
            // `layout(availableWidth:availableHeight:)` would re-resolve a
            // percentage `width`/`height` against the value it just produced.
            child.layoutChildren(width: w, height: h)

            cursor = mainEnd + measure.mainMarginAfter + mainSpacing
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

            child.layoutChildren(width: childW, height: childH)
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
