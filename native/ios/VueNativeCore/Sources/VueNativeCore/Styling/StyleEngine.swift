#if canImport(UIKit)
import UIKit
import FlexLayout
import ObjectiveC

/// Static class that applies style properties to UIViews via FlexLayout (Yoga).
/// Handles both Yoga layout properties (flex, padding, margin, etc.) and
/// UIView visual properties (backgroundColor, borderRadius, etc.).
///
/// Supports point values, percentage values, and auto for dimensions.
@MainActor
enum StyleEngine {

    // MARK: - Public API

    /// Apply a batch of style properties to a view.
    static func applyStyles(_ styles: [String: Any], to view: UIView) {
        for (key, value) in styles {
            apply(key: key, value: value, to: view)
        }
    }

    /// Apply a single style property to a view.
    /// Routes to the appropriate handler based on the property key.
    static func apply(key: String, value: Any?, to view: UIView) {
        // Store internal props (prefixed with "__") as associated objects
        // so parent factories can inspect them (e.g. VSectionListFactory).
        if key.hasPrefix("__") {
            setInternalProp(key, value: value, on: view)
            return
        }

        // First try layout properties (FlexLayout / Yoga)
        if applyLayoutProp(key: key, value: value, to: view) {
            return
        }

        // Then try visual properties (UIView)
        if applyVisualProp(key: key, value: value, to: view) {
            return
        }

        // Text properties are handled by VTextFactory directly,
        // but we handle them here as a fallback for convenience
        if applyTextProp(key: key, value: value, to: view) {
            return
        }
    }

    // MARK: - Internal Props

    private static var internalPropsKey: UInt8 = 0

    /// Store an internal prop (prefixed with "__") on a view as an associated object.
    private static func setInternalProp(_ key: String, value: Any?, on view: UIView) {
        var props = objc_getAssociatedObject(view, &internalPropsKey) as? [String: Any] ?? [:]
        if let value = value {
            props[key] = value
        } else {
            props.removeValue(forKey: key)
        }
        objc_setAssociatedObject(view, &internalPropsKey, props, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Retrieve an internal prop from a view.
    static func getInternalProp(_ key: String, from view: UIView) -> Any? {
        let props = objc_getAssociatedObject(view, &internalPropsKey) as? [String: Any]
        return props?[key]
    }

    // MARK: - Yoga Value Helpers

    /// Convert a value to CGFloat points. Supports Double and Int.
    /// Returns nil for non-numeric values (strings like "50%", "auto").
    static func yogaValue(_ value: Any?) -> CGFloat? {
        if let num = value as? Double { return CGFloat(num) }
        if let num = value as? Int { return CGFloat(num) }
        if let num = value as? CGFloat { return num }
        if let str = value as? String, let num = Double(str) { return CGFloat(num) }
        return nil
    }

    /// Check if a value represents "auto" (for dimensions that support it).
    static func isAuto(_ value: Any?) -> Bool {
        if let str = value as? String, str.lowercased() == "auto" {
            return true
        }
        return false
    }

    /// Extract percentage value from strings like "50%". Returns 50.0 for "50%".
    static func asPercent(_ value: Any?) -> CGFloat? {
        guard let str = value as? String, str.hasSuffix("%"),
              let num = Double(str.dropLast()) else { return nil }
        return CGFloat(num)
    }

    // MARK: - Layout Properties (FlexLayout / Yoga)

    /// Apply a layout property via FlexLayout. Returns true if the key was recognized.
    @discardableResult
    private static func applyLayoutProp(key: String, value: Any?, to view: UIView) -> Bool {
        let flex = view.flex

        // The renderer sends `nil` when a key disappears from a style object.
        // FlexLayout retains its previous Yoga value unless we explicitly put
        // it back to the platform default, which made conditional styles stick
        // around after they were removed.
        if value == nil {
            return resetLayoutProp(key: key, to: view)
        }

        switch key {

        // MARK: Flex container properties

        case "flexDirection":
            if let str = value as? String {
                switch str {
                case "row": flex.direction(.row)
                case "row-reverse", "rowReverse": flex.direction(.rowReverse)
                case "column-reverse", "columnReverse": flex.direction(.columnReverse)
                default: flex.direction(.column)
                }
            }
            return true

        case "justifyContent":
            if let str = value as? String {
                switch str {
                case "flex-start", "flexStart", "start": flex.justifyContent(.start)
                case "flex-end", "flexEnd", "end": flex.justifyContent(.end)
                case "center": flex.justifyContent(.center)
                case "space-between", "spaceBetween": flex.justifyContent(.spaceBetween)
                case "space-around", "spaceAround": flex.justifyContent(.spaceAround)
                case "space-evenly", "spaceEvenly": flex.justifyContent(.spaceEvenly)
                default: flex.justifyContent(.start)
                }
            }
            return true

        case "alignItems":
            if let str = value as? String {
                switch str {
                case "flex-start", "flexStart", "start": flex.alignItems(.start)
                case "flex-end", "flexEnd", "end": flex.alignItems(.end)
                case "center": flex.alignItems(.center)
                case "stretch": flex.alignItems(.stretch)
                case "baseline": flex.alignItems(.baseline)
                default: flex.alignItems(.stretch)
                }
            }
            return true

        case "alignSelf":
            if let str = value as? String {
                switch str {
                case "auto": flex.alignSelf(.auto)
                case "flex-start", "flexStart", "start": flex.alignSelf(.start)
                case "flex-end", "flexEnd", "end": flex.alignSelf(.end)
                case "center": flex.alignSelf(.center)
                case "stretch": flex.alignSelf(.stretch)
                case "baseline": flex.alignSelf(.baseline)
                default: flex.alignSelf(.auto)
                }
            }
            return true

        case "alignContent":
            if let str = value as? String {
                switch str {
                case "flex-start", "flexStart", "start": flex.alignContent(.start)
                case "flex-end", "flexEnd", "end": flex.alignContent(.end)
                case "center": flex.alignContent(.center)
                case "stretch": flex.alignContent(.stretch)
                case "space-between", "spaceBetween": flex.alignContent(.spaceBetween)
                case "space-around", "spaceAround": flex.alignContent(.spaceAround)
                default: flex.alignContent(.stretch)
                }
            }
            return true

        case "flexWrap":
            if let str = value as? String {
                switch str {
                case "wrap": flex.wrap(.wrap)
                case "wrap-reverse", "wrapReverse": flex.wrap(.wrapReverse)
                default: flex.wrap(.noWrap)
                }
            }
            return true

        // MARK: Flex item properties

        case "flex":
            if let num = yogaValue(value) {
                // CSS "flex" shorthand: when a single number, it sets flexGrow.
                // flex: 1 => grow(1), shrink(1), basis(0)
                flex.grow(num)
                if num > 0 {
                    flex.shrink(1)
                    flex.basis(0)
                }
            }
            return true

        case "flexGrow":
            if let num = yogaValue(value) {
                flex.grow(num)
            }
            return true

        case "flexShrink":
            if let num = yogaValue(value) {
                flex.shrink(num)
            }
            return true

        case "flexBasis":
            if isAuto(value) {
                flex.basis(nil) // nil means auto in FlexLayout
            } else if let num = yogaValue(value) {
                flex.basis(num)
            }
            return true

        // MARK: Dimensions

        case "width":
            if isAuto(value) {
                flex.width(nil)
            } else if let pct = asPercent(value) {
                flex.width(pct%)
            } else if let num = yogaValue(value) {
                flex.width(num)
            }
            return true

        case "height":
            if isAuto(value) {
                flex.height(nil)
            } else if let pct = asPercent(value) {
                flex.height(pct%)
            } else if let num = yogaValue(value) {
                flex.height(num)
            }
            return true

        case "minWidth":
            if let pct = asPercent(value) {
                flex.minWidth(pct%)
            } else if let num = yogaValue(value) {
                flex.minWidth(num)
            }
            return true

        case "minHeight":
            if let pct = asPercent(value) {
                flex.minHeight(pct%)
            } else if let num = yogaValue(value) {
                flex.minHeight(num)
            }
            return true

        case "maxWidth":
            if let pct = asPercent(value) {
                flex.maxWidth(pct%)
            } else if let num = yogaValue(value) {
                flex.maxWidth(num)
            }
            return true

        case "maxHeight":
            if let pct = asPercent(value) {
                flex.maxHeight(pct%)
            } else if let num = yogaValue(value) {
                flex.maxHeight(num)
            }
            return true

        case "aspectRatio":
            if let num = yogaValue(value) {
                flex.aspectRatio(num)
            }
            return true

        // MARK: Padding

        case "padding":
            if let num = yogaValue(value) {
                flex.padding(num)
            }
            return true

        case "paddingTop":
            if let num = yogaValue(value) {
                flex.paddingTop(num)
            }
            return true

        case "paddingRight":
            if let num = yogaValue(value) {
                flex.paddingRight(num)
            }
            return true

        case "paddingBottom":
            if let num = yogaValue(value) {
                flex.paddingBottom(num)
            }
            return true

        case "paddingLeft":
            if let num = yogaValue(value) {
                flex.paddingLeft(num)
            }
            return true

        case "paddingHorizontal":
            if let num = yogaValue(value) {
                flex.paddingHorizontal(num)
            }
            return true

        case "paddingVertical":
            if let num = yogaValue(value) {
                flex.paddingVertical(num)
            }
            return true

        case "paddingStart":
            if let num = yogaValue(value) {
                flex.paddingStart(num)
            }
            return true

        case "paddingEnd":
            if let num = yogaValue(value) {
                flex.paddingEnd(num)
            }
            return true

        // MARK: Margin

        case "margin":
            // Note: FlexLayout does not expose auto margins via its Swift API.
            // Point values are supported; auto margins are not.
            if isAuto(value) {
                // Auto margins not supported by FlexLayout — skip gracefully
            } else if let num = yogaValue(value) {
                flex.margin(num)
            }
            return true

        case "marginTop":
            if let num = yogaValue(value) {
                flex.marginTop(num)
            }
            return true

        case "marginRight":
            if let num = yogaValue(value) {
                flex.marginRight(num)
            }
            return true

        case "marginBottom":
            if let num = yogaValue(value) {
                flex.marginBottom(num)
            }
            return true

        case "marginLeft":
            if let num = yogaValue(value) {
                flex.marginLeft(num)
            }
            return true

        case "marginHorizontal":
            if let num = yogaValue(value) {
                flex.marginHorizontal(num)
            }
            return true

        case "marginVertical":
            if let num = yogaValue(value) {
                flex.marginVertical(num)
            }
            return true

        case "marginStart":
            if let num = yogaValue(value) {
                flex.marginStart(num)
            }
            return true

        case "marginEnd":
            if let num = yogaValue(value) {
                flex.marginEnd(num)
            }
            return true

        // MARK: Gap

        case "gap":
            if let num = yogaValue(value) {
                flex.gap(num)
            }
            return true

        case "rowGap":
            if let num = yogaValue(value) {
                flex.rowGap(num)
            }
            return true

        case "columnGap":
            if let num = yogaValue(value) {
                flex.columnGap(num)
            }
            return true

        // MARK: Position

        case "position":
            if let str = value as? String {
                switch str {
                case "absolute": flex.position(.absolute)
                case "relative": flex.position(.relative)
                default: flex.position(.relative)
                }
            }
            return true

        case "top":
            if let num = yogaValue(value) {
                flex.top(num)
            }
            return true

        case "right":
            if let num = yogaValue(value) {
                flex.right(num)
            }
            return true

        case "bottom":
            if let num = yogaValue(value) {
                flex.bottom(num)
            }
            return true

        case "left":
            if let num = yogaValue(value) {
                flex.left(num)
            }
            return true

        case "start":
            if let num = yogaValue(value) {
                flex.start(num)
            }
            return true

        case "end":
            if let num = yogaValue(value) {
                flex.end(num)
            }
            return true

        // MARK: Overflow

        case "overflow":
            // Note: FlexLayout's Flex.overflow() is not exposed in the public API.
            // We handle overflow purely via UIView.clipsToBounds.
            if let str = value as? String {
                switch str {
                case "hidden":
                    view.clipsToBounds = true
                default:
                    view.clipsToBounds = false
                }
            }
            return true

        // MARK: Display

        case "display":
            if let str = value as? String {
                switch str {
                case "none":
                    flex.display(.none)
                    view.isHidden = true
                default:
                    flex.display(.flex)
                    view.isHidden = false
                }
            }
            return true

        // MARK: Direction (RTL/LTR)

        case "direction":
            if let str = value as? String {
                switch str {
                case "ltr": flex.layoutDirection(.ltr)
                case "rtl": flex.layoutDirection(.rtl)
                case "inherit": flex.layoutDirection(.inherit)
                default: break
                }
            }
            return true

        default:
            return false
        }
    }

    /// Restore the default value for a recognized layout property.
    ///
    /// FlexLayout only exposes `nil` resets for dimensions and flex basis. Its
    /// margin, padding, gap, and edge APIs accept concrete values, so zero is
    /// the CSS/Yoga default used to clear a previously applied value.
    @discardableResult
    private static func resetLayoutProp(key: String, to view: UIView) -> Bool {
        let flex = view.flex

        switch key {
        case "flexDirection":
            flex.direction(.column)
        case "justifyContent":
            flex.justifyContent(.start)
        case "alignItems":
            flex.alignItems(.stretch)
        case "alignSelf":
            flex.alignSelf(.auto)
        case "alignContent":
            flex.alignContent(.stretch)
        case "flexWrap":
            flex.wrap(.noWrap)

        case "flex":
            flex.grow(0).shrink(0).basis(nil)
        case "flexGrow":
            flex.grow(0)
        case "flexShrink":
            flex.shrink(0)
        case "flexBasis":
            flex.basis(nil)

        case "width":
            flex.width(nil)
        case "height":
            flex.height(nil)
        case "minWidth":
            flex.minWidth(nil)
        case "minHeight":
            flex.minHeight(nil)
        case "maxWidth":
            flex.maxWidth(nil)
        case "maxHeight":
            flex.maxHeight(nil)
        case "aspectRatio":
            flex.aspectRatio(nil)

        case "padding":
            flex.padding(0)
        case "paddingTop":
            flex.paddingTop(0)
        case "paddingRight":
            flex.paddingRight(0)
        case "paddingBottom":
            flex.paddingBottom(0)
        case "paddingLeft":
            flex.paddingLeft(0)
        case "paddingHorizontal":
            flex.paddingHorizontal(0)
        case "paddingVertical":
            flex.paddingVertical(0)
        case "paddingStart":
            flex.paddingStart(0)
        case "paddingEnd":
            flex.paddingEnd(0)

        case "margin":
            flex.margin(0)
        case "marginTop":
            flex.marginTop(0)
        case "marginRight":
            flex.marginRight(0)
        case "marginBottom":
            flex.marginBottom(0)
        case "marginLeft":
            flex.marginLeft(0)
        case "marginHorizontal":
            flex.marginHorizontal(0)
        case "marginVertical":
            flex.marginVertical(0)
        case "marginStart":
            flex.marginStart(0)
        case "marginEnd":
            flex.marginEnd(0)

        case "gap":
            flex.gap(0)
        case "rowGap":
            flex.rowGap(0)
        case "columnGap":
            flex.columnGap(0)

        case "position":
            flex.position(.relative)
        case "top":
            flex.top(0)
        case "right":
            flex.right(0)
        case "bottom":
            flex.bottom(0)
        case "left":
            flex.left(0)
        case "start":
            flex.start(0)
        case "end":
            flex.end(0)
        case "overflow":
            view.clipsToBounds = false
        case "display":
            flex.display(.flex)
            view.isHidden = false
        case "direction":
            flex.layoutDirection(.inherit)
        default:
            return false
        }

        return true
    }

    // MARK: - Visual Properties (UIView)

    /// Apply a visual property directly on the UIView. Returns true if recognized.
    @discardableResult
    private static func applyVisualProp(key: String, value: Any?, to view: UIView) -> Bool {
        switch key {

        case "backgroundColor":
            if let colorStr = value as? String {
                if let color = UIColor.fromHex(colorStr) {
                    view.backgroundColor = color
                } else {
                    logInvalidColor(colorStr)
                }
            } else {
                view.backgroundColor = nil
            }
            return true

        case "opacity":
            if let num = yogaValue(value) {
                view.alpha = num
            } else {
                view.alpha = 1.0
            }
            return true

        case "borderRadius":
            if let num = yogaValue(value) {
                view.layer.cornerRadius = num
                // Automatically enable clipping when border radius is set
                if num > 0 {
                    view.clipsToBounds = true
                }
            } else {
                view.layer.cornerRadius = 0
            }
            return true

        case "borderTopLeftRadius":
            applyCornerRadius(view: view, corner: .layerMinXMinYCorner, radius: yogaValue(value))
            return true

        case "borderTopRightRadius":
            applyCornerRadius(view: view, corner: .layerMaxXMinYCorner, radius: yogaValue(value))
            return true

        case "borderBottomLeftRadius":
            applyCornerRadius(view: view, corner: .layerMinXMaxYCorner, radius: yogaValue(value))
            return true

        case "borderBottomRightRadius":
            applyCornerRadius(view: view, corner: .layerMaxXMaxYCorner, radius: yogaValue(value))
            return true

        case "borderWidth":
            if let num = yogaValue(value) {
                view.layer.borderWidth = num
            } else {
                view.layer.borderWidth = 0
            }
            return true

        case "borderColor":
            if let colorStr = value as? String {
                if let color = UIColor.fromHex(colorStr) {
                    view.layer.borderColor = color.cgColor
                } else {
                    logInvalidColor(colorStr)
                }
            } else {
                view.layer.borderColor = nil
            }
            return true

        case "shadowColor":
            if let colorStr = value as? String {
                if let color = UIColor.fromHex(colorStr) {
                    view.layer.shadowColor = color.cgColor
                } else {
                    logInvalidColor(colorStr)
                }
            }
            return true

        case "shadowOpacity":
            if let num = yogaValue(value) {
                view.layer.shadowOpacity = Float(num)
            }
            return true

        case "shadowRadius":
            if let num = yogaValue(value) {
                view.layer.shadowRadius = num
            }
            return true

        case "shadowOffsetX":
            if let num = yogaValue(value) {
                view.layer.shadowOffset = CGSize(
                    width: num,
                    height: view.layer.shadowOffset.height
                )
            }
            return true

        case "shadowOffsetY":
            if let num = yogaValue(value) {
                view.layer.shadowOffset = CGSize(
                    width: view.layer.shadowOffset.width,
                    height: num
                )
            }
            return true

        case "shadowOffset":
            if let dict = value as? [String: Any] {
                let w = (dict["width"] as? Double).map { CGFloat($0) } ?? view.layer.shadowOffset.width
                let h = (dict["height"] as? Double).map { CGFloat($0) } ?? view.layer.shadowOffset.height
                view.layer.shadowOffset = CGSize(width: w, height: h)
            }
            return true

        case "transform":
            if let transforms = value as? [[String: Any]] {
                view.layer.transform = composeTransform3D(transforms)
            } else {
                view.layer.transform = CATransform3DIdentity
            }
            return true

        case "hidden":
            view.isHidden = (value as? Bool) ?? false
            return true

        case "pointerEvents":
            if let mode = value as? String {
                view.isUserInteractionEnabled = mode != "none"
            }
            return true

        case "isHidden":
            if let hidden = value as? Bool {
                view.isHidden = hidden
            } else if let hidden = value as? Int {
                view.isHidden = hidden != 0
            }
            return true

        case "zIndex":
            if let num = yogaValue(value) {
                view.layer.zPosition = num
            }
            return true

        case "accessibilityLabel":
            view.accessibilityLabel = value as? String
            view.isAccessibilityElement = true
            return true

        case "accessibilityHint":
            view.accessibilityHint = value as? String
            view.isAccessibilityElement = true
            return true

        case "accessibilityValue":
            view.accessibilityValue = value as? String
            view.isAccessibilityElement = true
            return true

        case "accessibilityRole":
            if let role = value as? String {
                // Replace only the trait owned by the previous role, preserving
                // reactive state traits (.notEnabled / .selected) applied via
                // accessibilityState so the two props no longer clobber each other.
                var traits = view.accessibilityTraits
                traits.remove(allRoleTraits)
                if let roleTrait = roleTraits[role] {
                    traits.insert(roleTrait)
                }
                view.accessibilityTraits = traits
                view.isAccessibilityElement = true
            }
            return true

        case "accessibilityState":
            let state = value as? [String: Any] ?? [:]
            var traits = view.accessibilityTraits
            // State props are reactive. Remove the traits owned by the previous
            // state snapshot before applying the new one so true -> false and
            // prop removal cannot leave stale VoiceOver announcements.
            traits.remove([.notEnabled, .selected])
            if state["disabled"] as? Bool == true { traits.insert(.notEnabled) }
            if state["selected"] as? Bool == true || state["checked"] as? Bool == true {
                traits.insert(.selected)
            }
            view.accessibilityTraits = traits
            view.isAccessibilityElement = true
            return true

        case "accessible":
            let acc = (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
            view.isAccessibilityElement = acc
            return true

        case "importantForAccessibility":
            if let val = value as? String {
                view.accessibilityElementsHidden = (val == "no-hide-descendants")
            }
            return true

        default:
            return false
        }
    }

    // MARK: - Text Properties

    /// Apply text-specific properties. Returns true if recognized.
    /// This is a fallback — VTextFactory handles these directly when it can.
    @discardableResult
    private static func applyTextProp(key: String, value: Any?, to view: UIView) -> Bool {
        guard let label = view as? UILabel else { return false }

        switch key {
        case "fontSize":
            if let num = yogaValue(value) {
                // Scale the developer-supplied size for Dynamic Type so text
                // respects the user's preferred content size category.
                let scaled = UIFontMetrics.default.scaledValue(for: num)
                label.font = label.font.withSize(scaled)
                label.flex.markDirty()
            }
            return true

        case "fontWeight":
            if let str = value as? String {
                let weight = VTextFactory.fontWeightMap[str] ?? .regular
                label.font = UIFont.systemFont(ofSize: label.font.pointSize, weight: weight)
                label.flex.markDirty()
            }
            return true

        case "color":
            if let colorStr = value as? String {
                if let color = UIColor.fromHex(colorStr) {
                    label.textColor = color
                } else {
                    logInvalidColor(colorStr)
                }
            }
            return true

        case "textAlign":
            if let alignStr = value as? String {
                label.textAlignment = VTextFactory.textAlignMap[alignStr] ?? .natural
            }
            return true

        case "fontStyle":
            if let str = value as? String, str == "italic" {
                let descriptor = label.font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? label.font.fontDescriptor
                label.font = UIFont(descriptor: descriptor, size: label.font.pointSize)
                label.flex.markDirty()
            } else {
                // Remove italic if "normal"
                var traits = label.font.fontDescriptor.symbolicTraits
                traits.remove(.traitItalic)
                if let descriptor = label.font.fontDescriptor.withSymbolicTraits(traits) {
                    label.font = UIFont(descriptor: descriptor, size: label.font.pointSize)
                    label.flex.markDirty()
                }
            }
            return true

        case "lineHeight":
            if let num = yogaValue(value) {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.minimumLineHeight = num
                paragraphStyle.maximumLineHeight = num
                paragraphStyle.alignment = label.textAlignment
                let text = label.text ?? ""
                let attrs: [NSAttributedString.Key: Any] = [
                    .paragraphStyle: paragraphStyle,
                    .font: label.font as Any
                ]
                label.attributedText = NSAttributedString(string: text, attributes: attrs)
                label.flex.markDirty()
            }
            return true

        case "letterSpacing":
            if let num = yogaValue(value) {
                let text = label.text ?? ""
                let attrs: [NSAttributedString.Key: Any] = [
                    .kern: num,
                    .font: label.font as Any
                ]
                label.attributedText = NSAttributedString(string: text, attributes: attrs)
                label.flex.markDirty()
            }
            return true

        case "textDecorationLine":
            if let str = value as? String {
                let text = label.text ?? ""
                var attrs: [NSAttributedString.Key: Any] = [.font: label.font as Any]
                switch str {
                case "underline":
                    attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                case "line-through", "lineThrough":
                    attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                case "underline line-through":
                    attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                default:
                    break
                }
                label.attributedText = NSAttributedString(string: text, attributes: attrs)
                label.flex.markDirty()
            }
            return true

        case "textTransform":
            if let str = value as? String, let text = label.text {
                switch str {
                case "uppercase": label.text = text.uppercased()
                case "lowercase": label.text = text.lowercased()
                case "capitalize": label.text = text.capitalized
                default: break
                }
                label.flex.markDirty()
            }
            return true

        default:
            return false
        }
    }

    // MARK: - Corner radius helpers

    /// Apply (or reset) a corner radius to a specific corner of the view.
    ///
    /// CALayer exposes a single shared `cornerRadius` for every corner
    /// selected via `maskedCorners` — it has no notion of "this corner's
    /// radius" independent of the others, so it cannot represent different
    /// non-zero radii on different corners at the same time. This applies the
    /// most recently set radius (instead of `max`, which made a smaller
    /// radius sent after a larger one a permanent no-op) and lets
    /// `radius == nil` (or `<= 0`) remove that corner from the mask, matching
    /// how the renderer sends `nil` when a style prop is removed. Per-corner
    /// combinations that need genuinely independent radii (e.g. a large
    /// top-left with a small bottom-right at the same time) are not
    /// representable this way and would need a CAShapeLayer mask instead.
    private static func applyCornerRadius(view: UIView, corner: CACornerMask, radius: CGFloat?) {
        guard let radius = radius, radius > 0 else {
            view.layer.maskedCorners.remove(corner)
            return
        }
        view.clipsToBounds = true
        view.layer.maskedCorners.insert(corner)
        view.layer.cornerRadius = radius
    }

    // MARK: - Helpers

    /// Maps `accessibilityRole` string values to the trait they own. `"selected"`
    /// is intentionally absent — it is a reactive state, not a role, and is owned
    /// by `accessibilityState`.
    private static let roleTraits: [String: UIAccessibilityTraits] = [
        "button": .button,
        "link": .link,
        "header": .header,
        "image": .image,
        "text": .staticText,
        "adjustable": .adjustable,
        "search": .searchField,
        "tab": .tabBar,
    ]

    /// Union of every trait `accessibilityRole` may assign. Removing this set
    /// before inserting a new role clears any previously applied role trait
    /// while leaving reactive state traits (.notEnabled / .selected) untouched.
    private static let allRoleTraits: UIAccessibilityTraits = [
        .button, .link, .header, .image, .staticText, .adjustable, .searchField, .tabBar,
    ]

    /// Log an invalid color value in DEBUG builds. The style is intentionally
    /// not applied so the view keeps its previous value rather than going clear.
    private static func logInvalidColor(_ colorStr: String) {
        #if DEBUG
        NSLog("[VueNative StyleEngine] Warning: invalid color '\(colorStr)' ignored — keeping previous value")
        #endif
    }

    /// Compose a transform list (an array of single-key dictionaries, matching the
    /// TypeScript `transform` style contract) into a single `CATransform3D`.
    ///
    /// Supports the 2D operations (`translateX/Y`, `scale`, `scaleX/Y`, `rotate`)
    /// plus the 3D operations (`perspective`, `rotateX/Y/Z`, `skewX/Y`). Each
    /// operation is pre-concatenated so the first entry in the array ends up as
    /// the outermost transform — the same convention CSS transform lists use and
    /// the same order the previous `CGAffineTransform`-based implementation used.
    ///
    /// The result is applied to `view.layer.transform`; pure-2D lists still
    /// project back to the equivalent `CGAffineTransform` via `view.transform`.
    private static func composeTransform3D(_ transforms: [[String: Any]]) -> CATransform3D {
        var result = CATransform3DIdentity

        // Pre-concatenate `op` so it is applied before the accumulated result,
        // mirroring `CGAffineTransformRotate(t, a) == Concat(rotation, t)`.
        func apply(_ op: CATransform3D) {
            result = CATransform3DConcat(op, result)
        }

        for dict in transforms {
            // Original 2D keys (relative order preserved from the prior impl).
            if let rotateStr = dict["rotate"] as? String {
                apply(CATransform3DMakeRotation(parseAngle(rotateStr), 0, 0, 1))
            }
            if let scale = yogaValue(dict["scale"]) {
                apply(CATransform3DMakeScale(scale, scale, 1))
            }
            if let scaleX = yogaValue(dict["scaleX"]) {
                apply(CATransform3DMakeScale(scaleX, 1, 1))
            }
            if let scaleY = yogaValue(dict["scaleY"]) {
                apply(CATransform3DMakeScale(1, scaleY, 1))
            }
            if let tx = yogaValue(dict["translateX"]) {
                apply(CATransform3DMakeTranslation(tx, 0, 0))
            }
            if let ty = yogaValue(dict["translateY"]) {
                apply(CATransform3DMakeTranslation(0, ty, 0))
            }

            // 3D keys.
            if let perspective = yogaValue(dict["perspective"]), perspective != 0 {
                var p = CATransform3DIdentity
                p.m34 = -1.0 / perspective
                apply(p)
            }
            if let rotateXStr = dict["rotateX"] as? String {
                apply(CATransform3DMakeRotation(parseAngle(rotateXStr), 1, 0, 0))
            }
            if let rotateYStr = dict["rotateY"] as? String {
                apply(CATransform3DMakeRotation(parseAngle(rotateYStr), 0, 1, 0))
            }
            if let rotateZStr = dict["rotateZ"] as? String {
                apply(CATransform3DMakeRotation(parseAngle(rotateZStr), 0, 0, 1))
            }
            if let skewXStr = dict["skewX"] as? String {
                var s = CATransform3DIdentity
                s.m21 = tan(skewXStr.isEmpty ? 0 : parseAngle(skewXStr))
                apply(s)
            }
            if let skewYStr = dict["skewY"] as? String {
                var s = CATransform3DIdentity
                s.m12 = tan(skewYStr.isEmpty ? 0 : parseAngle(skewYStr))
                apply(s)
            }
        }

        return result
    }

    /// Parse an angle string into radians.
    /// Supports "45deg" (degrees) and "1.5rad" (radians).
    private static func parseAngle(_ str: String) -> CGFloat {
        let s = str.trimmingCharacters(in: .whitespaces).lowercased()
        if s.hasSuffix("deg"), let num = Double(s.dropLast(3)) {
            return CGFloat(num * .pi / 180)
        }
        if s.hasSuffix("rad"), let num = Double(s.dropLast(3)) {
            return CGFloat(num)
        }
        // Fallback: try to parse as raw number (radians)
        if let num = Double(s) {
            return CGFloat(num)
        }
        return 0
    }
}
#endif
