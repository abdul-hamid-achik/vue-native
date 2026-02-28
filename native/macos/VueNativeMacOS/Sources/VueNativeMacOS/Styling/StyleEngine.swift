import AppKit
import ObjectiveC

/// Static class that applies style properties to NSViews via LayoutNode (flexbox).
/// Handles both layout properties (flex, padding, margin, etc.) and
/// NSView visual properties (backgroundColor, borderRadius, etc.).
///
/// Supports point values, percentage values, and auto for dimensions.
@MainActor
enum StyleEngine {

    // MARK: - Public API

    /// Apply a batch of style properties to a view.
    static func applyStyles(_ styles: [String: Any], to view: NSView) {
        for (key, value) in styles {
            apply(key: key, value: value, to: view)
        }
    }

    /// Apply a single style property to a view.
    /// Routes to the appropriate handler based on the property key.
    static func apply(key: String, value: Any?, to view: NSView) {
        // Store internal props (prefixed with "__") as associated objects
        // so parent factories can inspect them.
        if key.hasPrefix("__") {
            setInternalProp(key, value: value, on: view)
            return
        }

        // First try layout properties (LayoutNode / flexbox)
        if applyLayoutProp(key: key, value: value, to: view) {
            return
        }

        // Then try visual properties (NSView / CALayer)
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
    private static func setInternalProp(_ key: String, value: Any?, on view: NSView) {
        var props = objc_getAssociatedObject(view, &internalPropsKey) as? [String: Any] ?? [:]
        if let value = value {
            props[key] = value
        } else {
            props.removeValue(forKey: key)
        }
        objc_setAssociatedObject(view, &internalPropsKey, props, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    /// Retrieve an internal prop from a view.
    static func getInternalProp(_ key: String, from view: NSView) -> Any? {
        let props = objc_getAssociatedObject(view, &internalPropsKey) as? [String: Any]
        return props?[key]
    }

    /// Public setter for internal props (used by factories that need to store state).
    static func setInternalPropDirect(_ key: String, value: Any?, on view: NSView) {
        setInternalProp(key, value: value, on: view)
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

    // MARK: - Layout Properties (LayoutNode / Flexbox)

    /// Apply a layout property via LayoutNode. Returns true if the key was recognized.
    @discardableResult
    private static func applyLayoutProp(key: String, value: Any?, to view: NSView) -> Bool {
        let node = view.ensureLayoutNode()

        switch key {

        // MARK: Flex container properties

        case "flexDirection":
            if let str = value as? String {
                switch str {
                case "row": node.flexDirection = .row
                case "row-reverse", "rowReverse": node.flexDirection = .rowReverse
                case "column-reverse", "columnReverse": node.flexDirection = .columnReverse
                default: node.flexDirection = .column
                }
            }
            node.markDirty()
            return true

        case "justifyContent":
            if let str = value as? String {
                switch str {
                case "flex-start", "flexStart", "start": node.justifyContent = .flexStart
                case "flex-end", "flexEnd", "end": node.justifyContent = .flexEnd
                case "center": node.justifyContent = .center
                case "space-between", "spaceBetween": node.justifyContent = .spaceBetween
                case "space-around", "spaceAround": node.justifyContent = .spaceAround
                case "space-evenly", "spaceEvenly": node.justifyContent = .spaceEvenly
                default: node.justifyContent = .flexStart
                }
            }
            node.markDirty()
            return true

        case "alignItems":
            if let str = value as? String {
                switch str {
                case "flex-start", "flexStart", "start": node.alignItems = .flexStart
                case "flex-end", "flexEnd", "end": node.alignItems = .flexEnd
                case "center": node.alignItems = .center
                case "stretch": node.alignItems = .stretch
                case "baseline": node.alignItems = .baseline
                default: node.alignItems = .stretch
                }
            }
            node.markDirty()
            return true

        case "alignSelf":
            if let str = value as? String {
                switch str {
                case "auto": node.alignSelf = .auto
                case "flex-start", "flexStart", "start": node.alignSelf = .flexStart
                case "flex-end", "flexEnd", "end": node.alignSelf = .flexEnd
                case "center": node.alignSelf = .center
                case "stretch": node.alignSelf = .stretch
                case "baseline": node.alignSelf = .baseline
                default: node.alignSelf = .auto
                }
            }
            node.markDirty()
            return true

        case "alignContent":
            if let str = value as? String {
                switch str {
                case "flex-start", "flexStart", "start": node.alignContent = .flexStart
                case "flex-end", "flexEnd", "end": node.alignContent = .flexEnd
                case "center": node.alignContent = .center
                case "stretch": node.alignContent = .stretch
                case "space-between", "spaceBetween": node.alignContent = .flexStart // Simplified
                case "space-around", "spaceAround": node.alignContent = .flexStart   // Simplified
                default: node.alignContent = .stretch
                }
            }
            node.markDirty()
            return true

        case "flexWrap":
            if let str = value as? String {
                switch str {
                case "wrap": node.flexWrap = .wrap
                case "wrap-reverse", "wrapReverse": node.flexWrap = .wrapReverse
                default: node.flexWrap = .noWrap
                }
            }
            node.markDirty()
            return true

        // MARK: Flex item properties

        case "flex":
            if let num = yogaValue(value) {
                // CSS "flex" shorthand: when a single number, it sets flexGrow.
                // flex: 1 => grow(1), shrink(1), basis(0)
                node.flexGrow = num
                if num > 0 {
                    node.flexShrink = 1
                    node.flexBasis = .points(0)
                }
            }
            node.markDirty()
            return true

        case "flexGrow":
            if let num = yogaValue(value) {
                node.flexGrow = num
            }
            node.markDirty()
            return true

        case "flexShrink":
            if let num = yogaValue(value) {
                node.flexShrink = num
            }
            node.markDirty()
            return true

        case "flexBasis":
            if isAuto(value) {
                node.flexBasis = .auto
            } else if let pct = asPercent(value) {
                node.flexBasis = .percent(pct)
            } else if let num = yogaValue(value) {
                node.flexBasis = .points(num)
            }
            node.markDirty()
            return true

        // MARK: Dimensions

        case "width":
            if isAuto(value) {
                node.width = .auto
            } else if let pct = asPercent(value) {
                node.width = .percent(pct)
            } else if let num = yogaValue(value) {
                node.width = .points(num)
            }
            node.markDirty()
            return true

        case "height":
            if isAuto(value) {
                node.height = .auto
            } else if let pct = asPercent(value) {
                node.height = .percent(pct)
            } else if let num = yogaValue(value) {
                node.height = .points(num)
            }
            node.markDirty()
            return true

        case "minWidth":
            if let pct = asPercent(value) {
                node.minWidth = .percent(pct)
            } else if let num = yogaValue(value) {
                node.minWidth = .points(num)
            }
            node.markDirty()
            return true

        case "minHeight":
            if let pct = asPercent(value) {
                node.minHeight = .percent(pct)
            } else if let num = yogaValue(value) {
                node.minHeight = .points(num)
            }
            node.markDirty()
            return true

        case "maxWidth":
            if let pct = asPercent(value) {
                node.maxWidth = .percent(pct)
            } else if let num = yogaValue(value) {
                node.maxWidth = .points(num)
            }
            node.markDirty()
            return true

        case "maxHeight":
            if let pct = asPercent(value) {
                node.maxHeight = .percent(pct)
            } else if let num = yogaValue(value) {
                node.maxHeight = .points(num)
            }
            node.markDirty()
            return true

        case "aspectRatio":
            if let num = yogaValue(value) {
                node.aspectRatio = num
            }
            node.markDirty()
            return true

        // MARK: Padding

        case "padding":
            if let num = yogaValue(value) {
                node.padding = EdgeInsets(top: num, right: num, bottom: num, left: num)
            }
            node.markDirty()
            return true

        case "paddingTop":
            if let num = yogaValue(value) { node.padding.top = num }
            node.markDirty()
            return true

        case "paddingRight":
            if let num = yogaValue(value) { node.padding.right = num }
            node.markDirty()
            return true

        case "paddingBottom":
            if let num = yogaValue(value) { node.padding.bottom = num }
            node.markDirty()
            return true

        case "paddingLeft":
            if let num = yogaValue(value) { node.padding.left = num }
            node.markDirty()
            return true

        case "paddingHorizontal":
            if let num = yogaValue(value) {
                node.padding.left = num
                node.padding.right = num
            }
            node.markDirty()
            return true

        case "paddingVertical":
            if let num = yogaValue(value) {
                node.padding.top = num
                node.padding.bottom = num
            }
            node.markDirty()
            return true

        case "paddingStart":
            if let num = yogaValue(value) { node.padding.left = num }
            node.markDirty()
            return true

        case "paddingEnd":
            if let num = yogaValue(value) { node.padding.right = num }
            node.markDirty()
            return true

        // MARK: Margin

        case "margin":
            if let num = yogaValue(value) {
                node.margin = EdgeInsets(top: num, right: num, bottom: num, left: num)
            }
            node.markDirty()
            return true

        case "marginTop":
            if let num = yogaValue(value) { node.margin.top = num }
            node.markDirty()
            return true

        case "marginRight":
            if let num = yogaValue(value) { node.margin.right = num }
            node.markDirty()
            return true

        case "marginBottom":
            if let num = yogaValue(value) { node.margin.bottom = num }
            node.markDirty()
            return true

        case "marginLeft":
            if let num = yogaValue(value) { node.margin.left = num }
            node.markDirty()
            return true

        case "marginHorizontal":
            if let num = yogaValue(value) {
                node.margin.left = num
                node.margin.right = num
            }
            node.markDirty()
            return true

        case "marginVertical":
            if let num = yogaValue(value) {
                node.margin.top = num
                node.margin.bottom = num
            }
            node.markDirty()
            return true

        case "marginStart":
            if let num = yogaValue(value) { node.margin.left = num }
            node.markDirty()
            return true

        case "marginEnd":
            if let num = yogaValue(value) { node.margin.right = num }
            node.markDirty()
            return true

        // MARK: Gap

        case "gap":
            if let num = yogaValue(value) { node.gap = num }
            node.markDirty()
            return true

        case "rowGap":
            if let num = yogaValue(value) { node.rowGap = num }
            node.markDirty()
            return true

        case "columnGap":
            if let num = yogaValue(value) { node.columnGap = num }
            node.markDirty()
            return true

        // MARK: Position

        case "position":
            if let str = value as? String {
                switch str {
                case "absolute": node.positionType = .absolute
                case "relative": node.positionType = .relative
                default: node.positionType = .relative
                }
            }
            node.markDirty()
            return true

        case "top":
            if let num = yogaValue(value) {
                node.positionTop = .points(num)
            }
            node.markDirty()
            return true

        case "right":
            if let num = yogaValue(value) {
                node.positionRight = .points(num)
            }
            node.markDirty()
            return true

        case "bottom":
            if let num = yogaValue(value) {
                node.positionBottom = .points(num)
            }
            node.markDirty()
            return true

        case "left":
            if let num = yogaValue(value) {
                node.positionLeft = .points(num)
            }
            node.markDirty()
            return true

        case "start":
            if let num = yogaValue(value) {
                node.positionLeft = .points(num)
            }
            node.markDirty()
            return true

        case "end":
            if let num = yogaValue(value) {
                node.positionRight = .points(num)
            }
            node.markDirty()
            return true

        // MARK: Overflow

        case "overflow":
            if let str = value as? String {
                switch str {
                case "hidden":
                    view.layer?.masksToBounds = true
                default:
                    view.layer?.masksToBounds = false
                }
            }
            return true

        // MARK: Display

        case "display":
            if let str = value as? String {
                switch str {
                case "none":
                    node.display = .none
                    view.isHidden = true
                default:
                    node.display = .flex
                    view.isHidden = false
                }
            }
            node.markDirty()
            return true

        // MARK: Direction (RTL/LTR)

        case "direction":
            if let str = value as? String {
                switch str {
                case "ltr": node.layoutDirection = .leftToRight
                case "rtl": node.layoutDirection = .rightToLeft
                default: break
                }
            }
            node.markDirty()
            return true

        default:
            return false
        }
    }

    // MARK: - Visual Properties (NSView / CALayer)

    /// Apply a visual property directly on the NSView. Returns true if recognized.
    @discardableResult
    private static func applyVisualProp(key: String, value: Any?, to view: NSView) -> Bool {
        switch key {

        case "backgroundColor":
            if let colorStr = value as? String {
                view.layer?.backgroundColor = NSColor.fromHex(colorStr).cgColor
            } else {
                view.layer?.backgroundColor = nil
            }
            return true

        case "opacity":
            if let num = yogaValue(value) {
                view.alphaValue = num
            } else {
                view.alphaValue = 1.0
            }
            return true

        case "borderRadius":
            if let num = yogaValue(value) {
                view.layer?.cornerRadius = num
                if num > 0 {
                    view.layer?.masksToBounds = true
                }
            } else {
                view.layer?.cornerRadius = 0
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
                view.layer?.borderWidth = num
            } else {
                view.layer?.borderWidth = 0
            }
            return true

        case "borderColor":
            if let colorStr = value as? String {
                view.layer?.borderColor = NSColor.fromHex(colorStr).cgColor
            } else {
                view.layer?.borderColor = nil
            }
            return true

        case "shadowColor":
            if let colorStr = value as? String {
                view.layer?.shadowColor = NSColor.fromHex(colorStr).cgColor
            }
            return true

        case "shadowOpacity":
            if let num = yogaValue(value) {
                view.layer?.shadowOpacity = Float(num)
            }
            return true

        case "shadowRadius":
            if let num = yogaValue(value) {
                view.layer?.shadowRadius = num
            }
            return true

        case "shadowOffsetX":
            if let num = yogaValue(value) {
                view.layer?.shadowOffset = CGSize(
                    width: num,
                    height: view.layer?.shadowOffset.height ?? 0
                )
            }
            return true

        case "shadowOffsetY":
            if let num = yogaValue(value) {
                view.layer?.shadowOffset = CGSize(
                    width: view.layer?.shadowOffset.width ?? 0,
                    height: num
                )
            }
            return true

        case "shadowOffset":
            if let dict = value as? [String: Any] {
                let w = (dict["width"] as? Double).map { CGFloat($0) } ?? (view.layer?.shadowOffset.width ?? 0)
                let h = (dict["height"] as? Double).map { CGFloat($0) } ?? (view.layer?.shadowOffset.height ?? 0)
                view.layer?.shadowOffset = CGSize(width: w, height: h)
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
                view.layer?.setAffineTransform(result)
            } else {
                view.layer?.setAffineTransform(.identity)
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
                view.layer?.zPosition = num
            }
            return true

        // MARK: Accessibility (NSAccessibility)

        case "accessibilityLabel":
            view.setAccessibilityLabel(value as? String)
            return true

        case "accessibilityHint":
            // macOS uses "help" instead of "hint"
            view.setAccessibilityHelp(value as? String)
            return true

        case "accessibilityValue":
            view.setAccessibilityValue(value as? String)
            return true

        case "accessibilityRole":
            if let role = value as? String {
                switch role {
                case "button":     view.setAccessibilityRole(.button)
                case "link":       view.setAccessibilityRole(.link)
                case "header":     view.setAccessibilityRole(.staticText)
                case "image":      view.setAccessibilityRole(.image)
                case "text":       view.setAccessibilityRole(.staticText)
                case "search":     view.setAccessibilityRole(.textField)
                case "tab":        view.setAccessibilityRole(.tabGroup)
                case "none":       view.setAccessibilityRole(.unknown)
                default:           break
                }
            }
            return true

        case "accessible":
            let acc = (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
            view.setAccessibilityElement(acc)
            return true

        default:
            return false
        }
    }

    // MARK: - Text Properties

    /// Apply text-specific properties. Returns true if recognized.
    /// This is a fallback — VTextFactory handles these directly when it can.
    @discardableResult
    private static func applyTextProp(key: String, value: Any?, to view: NSView) -> Bool {
        guard let label = view as? NSTextField, !label.isEditable else { return false }

        switch key {
        case "fontSize":
            if let num = yogaValue(value) {
                let currentFont = label.font ?? NSFont.systemFont(ofSize: 13)
                label.font = NSFont(descriptor: currentFont.fontDescriptor, size: num)
                label.layoutNode?.markDirty()
            }
            return true

        case "fontWeight":
            if let str = value as? String {
                let weight = VTextFactory.fontWeightMap[str] ?? .regular
                let currentFont = label.font ?? NSFont.systemFont(ofSize: 13)
                label.font = NSFont.systemFont(ofSize: currentFont.pointSize, weight: weight)
                label.layoutNode?.markDirty()
            }
            return true

        case "color":
            if let colorStr = value as? String {
                label.textColor = NSColor.fromHex(colorStr)
            }
            return true

        case "textAlign":
            if let alignStr = value as? String {
                label.alignment = VTextFactory.textAlignMap[alignStr] ?? .natural
            }
            return true

        case "fontStyle":
            let currentFont = label.font ?? NSFont.systemFont(ofSize: 13)
            if let str = value as? String, str == "italic" {
                let descriptor = currentFont.fontDescriptor.withSymbolicTraits(.italic)
                label.font = NSFont(descriptor: descriptor, size: currentFont.pointSize)
            } else {
                var traits = currentFont.fontDescriptor.symbolicTraits
                traits.remove(.italic)
                let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits)
                label.font = NSFont(descriptor: descriptor, size: currentFont.pointSize)
            }
            label.layoutNode?.markDirty()
            return true

        case "lineHeight":
            if let num = yogaValue(value) {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.minimumLineHeight = num
                paragraphStyle.maximumLineHeight = num
                paragraphStyle.alignment = label.alignment
                let text = label.stringValue
                let font = label.font ?? NSFont.systemFont(ofSize: 13)
                let attrs: [NSAttributedString.Key: Any] = [
                    .paragraphStyle: paragraphStyle,
                    .font: font
                ]
                label.attributedStringValue = NSAttributedString(string: text, attributes: attrs)
                label.layoutNode?.markDirty()
            }
            return true

        case "letterSpacing":
            if let num = yogaValue(value) {
                let text = label.stringValue
                let font = label.font ?? NSFont.systemFont(ofSize: 13)
                let attrs: [NSAttributedString.Key: Any] = [
                    .kern: num,
                    .font: font
                ]
                label.attributedStringValue = NSAttributedString(string: text, attributes: attrs)
                label.layoutNode?.markDirty()
            }
            return true

        case "textDecorationLine":
            if let str = value as? String {
                let text = label.stringValue
                let font = label.font ?? NSFont.systemFont(ofSize: 13)
                var attrs: [NSAttributedString.Key: Any] = [.font: font]
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
                label.attributedStringValue = NSAttributedString(string: text, attributes: attrs)
                label.layoutNode?.markDirty()
            }
            return true

        case "textTransform":
            if let str = value as? String {
                let text = label.stringValue
                switch str {
                case "uppercase": label.stringValue = text.uppercased()
                case "lowercase": label.stringValue = text.lowercased()
                case "capitalize": label.stringValue = text.capitalized
                default: break
                }
                label.layoutNode?.markDirty()
            }
            return true

        default:
            return false
        }
    }

    // MARK: - Corner radius helpers

    /// Apply a corner radius to a specific corner of the view.
    private static func applyCornerRadius(view: NSView, corner: CACornerMask, radius: CGFloat) {
        view.layer?.masksToBounds = true
        view.layer?.maskedCorners.insert(corner)
        view.layer?.cornerRadius = max(view.layer?.cornerRadius ?? 0, radius)
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
