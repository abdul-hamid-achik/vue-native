#if canImport(UIKit)
import UIKit
import FlexLayout

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

        default:
            return false
        }
    }

    // MARK: - Visual Properties (UIView)

    /// Apply a visual property directly on the UIView. Returns true if recognized.
    @discardableResult
    private static func applyVisualProp(key: String, value: Any?, to view: UIView) -> Bool {
        switch key {

        case "backgroundColor":
            if let colorStr = value as? String {
                view.backgroundColor = UIColor.fromHex(colorStr)
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
            if let num = yogaValue(value) {
                applyCornerRadius(view: view, corner: .layerMinXMinYCorner, radius: num)
            }
            return true

        case "borderTopRightRadius":
            if let num = yogaValue(value) {
                applyCornerRadius(view: view, corner: .layerMaxXMinYCorner, radius: num)
            }
            return true

        case "borderBottomLeftRadius":
            if let num = yogaValue(value) {
                applyCornerRadius(view: view, corner: .layerMinXMaxYCorner, radius: num)
            }
            return true

        case "borderBottomRightRadius":
            if let num = yogaValue(value) {
                applyCornerRadius(view: view, corner: .layerMaxXMaxYCorner, radius: num)
            }
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
                view.layer.borderColor = UIColor.fromHex(colorStr).cgColor
            } else {
                view.layer.borderColor = nil
            }
            return true

        case "shadowColor":
            if let colorStr = value as? String {
                view.layer.shadowColor = UIColor.fromHex(colorStr).cgColor
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
                var result = CGAffineTransform.identity
                for dict in transforms {
                    if let rotateStr = dict["rotate"] as? String {
                        let angle = parseAngle(rotateStr)
                        result = result.rotated(by: angle)
                    }
                    if let scale = dict["scale"] as? Double {
                        result = result.scaledBy(x: CGFloat(scale), y: CGFloat(scale))
                    }
                    if let scaleX = dict["scaleX"] as? Double {
                        result = result.scaledBy(x: CGFloat(scaleX), y: 1)
                    }
                    if let scaleY = dict["scaleY"] as? Double {
                        result = result.scaledBy(x: 1, y: CGFloat(scaleY))
                    }
                    if let tx = dict["translateX"] as? Double {
                        result = result.translatedBy(x: CGFloat(tx), y: 0)
                    }
                    if let ty = dict["translateY"] as? Double {
                        result = result.translatedBy(x: 0, y: CGFloat(ty))
                    }
                }
                view.transform = result
            } else {
                view.transform = .identity
            }
            return true

        case "hidden":
            view.isHidden = (value as? Bool) ?? false
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
            return true

        case "accessibilityHint":
            view.accessibilityHint = value as? String
            return true

        case "accessibilityValue":
            view.accessibilityValue = value as? String
            return true

        case "accessibilityRole":
            if let role = value as? String {
                switch role {
                case "button":    view.accessibilityTraits = .button
                case "link":      view.accessibilityTraits = .link
                case "header":    view.accessibilityTraits = .header
                case "image":     view.accessibilityTraits = .image
                case "selected":  view.accessibilityTraits = .selected
                case "text":      view.accessibilityTraits = .staticText
                case "adjustable": view.accessibilityTraits = .adjustable
                case "search":    view.accessibilityTraits = .searchField
                case "tab":       view.accessibilityTraits = .tabBar
                case "none":      view.accessibilityTraits = .none
                default:          break
                }
            }
            return true

        case "accessibilityState":
            if let state = value as? [String: Any] {
                var traits = view.accessibilityTraits
                if let disabled = state["disabled"] as? Bool, disabled { traits.insert(.notEnabled) }
                if let selected = state["selected"] as? Bool, selected { traits.insert(.selected) }
                if let checked = state["checked"] as? Bool, checked { traits.insert(.selected) }
                view.accessibilityTraits = traits
            }
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
                label.font = label.font.withSize(num)
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
                label.textColor = UIColor.fromHex(colorStr)
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

    /// Apply a corner radius to a specific corner of the view.
    private static func applyCornerRadius(view: UIView, corner: CACornerMask, radius: CGFloat) {
        view.clipsToBounds = true
        view.layer.maskedCorners.insert(corner)
        view.layer.cornerRadius = max(view.layer.cornerRadius, radius)
    }

    // MARK: - Helpers

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
