#if canImport(UIKit)
import UIKit
import FlexLayout

/// Factory for VText — the text display component.
/// Maps to a UILabel with FlexLayout enabled.
/// After any text or font change, calls flex.markDirty() to trigger Yoga remeasurement.
final class VTextFactory: NativeComponentFactory {

    // MARK: - Font weight mapping

    /// Maps CSS-like font weight strings to UIFont.Weight values.
    static let fontWeightMap: [String: UIFont.Weight] = [
        "100": .ultraLight,
        "200": .thin,
        "300": .light,
        "400": .regular,
        "normal": .regular,
        "500": .medium,
        "600": .semibold,
        "semibold": .semibold,
        "700": .bold,
        "bold": .bold,
        "800": .heavy,
        "900": .black,
    ]

    // MARK: - Text alignment mapping

    static let textAlignMap: [String: NSTextAlignment] = [
        "left": .left,
        "center": .center,
        "right": .right,
        "justify": .justified,
        "auto": .natural,
    ]

    // MARK: - Associated object keys for stored state

    private static var fontSizeKey: UInt8 = 0
    private static var fontWeightKey: UInt8 = 0
    private static var fontFamilyKey: UInt8 = 0
    private static var textChildrenKey: UInt8 = 0
    private static var attributedStyleKey: UInt8 = 0

    // MARK: - NativeComponentFactory

    func createView() -> UIView {
        let label = UILabel()
        // Multi-line by default
        label.numberOfLines = 0
        // Accessing .flex automatically enables Yoga layout
        _ = label.flex
        return label
    }

    func updateProp(view: UIView, key: String, value: Any?) {
        guard let label = view as? UILabel else { return }

        switch key {
        case "text":
            storeTextChildren([], on: label)
            if let text = value as? String {
                label.text = text
            } else {
                label.text = nil
            }
            // Setting .text wipes any previously computed .attributedText, so
            // lineHeight/letterSpacing/textDecorationLine must be reapplied.
            applyAccumulatedAttributes(on: label)
            label.flex.markDirty()

        case "numberOfLines":
            if let lines = value as? Int {
                label.numberOfLines = lines
            } else if let lines = value as? Double {
                label.numberOfLines = Int(lines)
            } else {
                label.numberOfLines = 0
            }
            label.flex.markDirty()

        case "color":
            if let colorStr = value as? String {
                if let color = UIColor.fromHex(colorStr) {
                    label.textColor = color
                }
            } else {
                label.textColor = .label
            }

        case "fontSize":
            let size: CGFloat
            if let num = value as? Double {
                size = CGFloat(num)
            } else if let num = value as? Int {
                size = CGFloat(num)
            } else {
                size = 17.0 // System default
            }
            storeFontSize(size, on: label)
            rebuildFont(for: label)
            label.flex.markDirty()

        case "fontWeight":
            if let str = value as? String {
                storeFontWeight(str, on: label)
            } else {
                storeFontWeight(nil, on: label)
            }
            rebuildFont(for: label)
            label.flex.markDirty()

        case "fontFamily":
            if let family = value as? String {
                storeFontFamily(family, on: label)
            } else {
                storeFontFamily(nil, on: label)
            }
            rebuildFont(for: label)
            label.flex.markDirty()

        case "textAlign":
            if let alignStr = value as? String {
                label.textAlignment = VTextFactory.textAlignMap[alignStr] ?? .natural
            } else {
                label.textAlignment = .natural
            }

        case "lineBreakMode":
            if let mode = value as? String {
                switch mode {
                case "clip": label.lineBreakMode = .byClipping
                case "head": label.lineBreakMode = .byTruncatingHead
                case "middle": label.lineBreakMode = .byTruncatingMiddle
                case "tail": label.lineBreakMode = .byTruncatingTail
                case "wordwrap": label.lineBreakMode = .byWordWrapping
                default: label.lineBreakMode = .byTruncatingTail
                }
            }

        case "fontStyle":
            if let str = value as? String {
                let currentSize = label.font.pointSize
                if str == "italic" {
                    let descriptor = label.font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? label.font.fontDescriptor
                    label.font = UIFont(descriptor: descriptor, size: currentSize)
                } else {
                    var traits = label.font.fontDescriptor.symbolicTraits
                    traits.remove(.traitItalic)
                    if let descriptor = label.font.fontDescriptor.withSymbolicTraits(traits) {
                        label.font = UIFont(descriptor: descriptor, size: currentSize)
                    }
                }
                // The .font baked into attributedText attributes is now stale.
                applyAccumulatedAttributes(on: label)
            }
            label.flex.markDirty()

        case "lineHeight":
            if let num = value as? Double {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.minimumLineHeight = CGFloat(num)
                paragraphStyle.maximumLineHeight = CGFloat(num)
                paragraphStyle.alignment = label.textAlignment
                mergeAttribute(.paragraphStyle, value: paragraphStyle, on: label)
                label.flex.markDirty()
            }

        case "letterSpacing":
            if let num = value as? Double {
                mergeAttribute(.kern, value: CGFloat(num), on: label)
                label.flex.markDirty()
            }

        case "textDecorationLine":
            if let str = value as? String {
                var attrs = storedAttributes(on: label)
                attrs[.underlineStyle] = nil
                attrs[.strikethroughStyle] = nil
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
                storeAttributes(attrs, on: label)
                applyAccumulatedAttributes(on: label)
                label.flex.markDirty()
            }

        case "textTransform":
            if let str = value as? String {
                let original = label.text ?? ""
                switch str {
                case "uppercase": label.text = original.uppercased()
                case "lowercase": label.text = original.lowercased()
                case "capitalize": label.text = original.capitalized
                default: break
                }
                // Setting .text wipes any previously computed .attributedText.
                applyAccumulatedAttributes(on: label)
                label.flex.markDirty()
            }

        default:
            // Delegate unknown props to StyleEngine for layout/visual styling
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: UIView, event: String, handler: @escaping (Any?) -> Void) {
        // Tap/press support via gesture recognizer.
        if event == "press" {
            let wrapper = GestureWrapper(handler: handler)
            let tap = UITapGestureRecognizer(
                target: wrapper,
                action: #selector(GestureWrapper.handleGesture(_:))
            )
            view.addGestureRecognizer(tap)
            view.isUserInteractionEnabled = true
            GestureStorage.store(wrapper, for: view, event: event)
        }
    }

    func removeEventListener(view: UIView, event: String) {
        if event == "press" {
            GestureStorage.remove(for: view, event: event)
            view.gestureRecognizers?.forEach { recognizer in
                if recognizer is UITapGestureRecognizer {
                    view.removeGestureRecognizer(recognizer)
                }
            }
        }
    }

    func insertChild(_ child: UIView, into parent: UIView, before anchor: UIView?) {
        guard let label = parent as? UILabel else {
            child.removeFromSuperview()
            return
        }

        var children = storedTextChildren(on: label)
        if let anchor = anchor, let index = children.firstIndex(where: { $0 === anchor }) {
            children.insert(child, at: index)
        } else {
            children.append(child)
        }

        storeTextChildren(children, on: label)
        rebuildText(from: children, on: label)
    }

    func removeChild(_ child: UIView, from parent: UIView) {
        guard let label = parent as? UILabel else { return }
        var children = storedTextChildren(on: label)
        children.removeAll { $0 === child }
        storeTextChildren(children, on: label)
        rebuildText(from: children, on: label)
    }

    // MARK: - Font rebuilding

    /// Rebuild the UIFont from stored fontSize, fontWeight, and fontFamily.
    private func rebuildFont(for label: UILabel) {
        let storedSize = storedFontSize(on: label) ?? 17.0
        // Scale the developer-supplied size for Dynamic Type so labels respect
        // the user's preferred content size category.
        let size = UIFontMetrics.default.scaledValue(for: storedSize)
        let weightStr = storedFontWeight(on: label)
        let family = storedFontFamily(on: label)

        let weight = weightStr.flatMap { VTextFactory.fontWeightMap[$0] } ?? .regular

        if let family = family, !family.isEmpty {
            // Try to create a font with the specified family
            if let customFont = UIFont(name: family, size: size) {
                label.font = customFont
            } else {
                // Fallback: try as a font descriptor family
                let descriptor = UIFontDescriptor()
                    .withFamily(family)
                    .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
                label.font = UIFont(descriptor: descriptor, size: size)
            }
        } else {
            label.font = UIFont.systemFont(ofSize: size, weight: weight)
        }

        // The .font baked into attributedText attributes is now stale.
        applyAccumulatedAttributes(on: label)
    }

    // MARK: - Attributed text state (lineHeight / letterSpacing / textDecorationLine)

    /// `lineHeight`, `letterSpacing`, and `textDecorationLine` each rebuild
    /// `attributedText`, and setting `.text` or the font also invalidates it.
    /// All of them read/write this accumulated dictionary instead of
    /// clobbering `attributedText` with only their own attribute, so the
    /// three props (and text/font changes) can coexist.
    private func storeAttributes(_ attrs: [NSAttributedString.Key: Any], on view: UIView) {
        objc_setAssociatedObject(view, &VTextFactory.attributedStyleKey, attrs, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func storedAttributes(on view: UIView) -> [NSAttributedString.Key: Any] {
        return objc_getAssociatedObject(view, &VTextFactory.attributedStyleKey) as? [NSAttributedString.Key: Any] ?? [:]
    }

    /// Merge `key: value` into the accumulated attributes and reapply them.
    private func mergeAttribute(_ key: NSAttributedString.Key, value: Any?, on label: UILabel) {
        var attrs = storedAttributes(on: label)
        attrs[key] = value
        storeAttributes(attrs, on: label)
        applyAccumulatedAttributes(on: label)
    }

    /// Rebuild `attributedText` from the accumulated attributes plus the
    /// label's current font. No-ops when nothing has ever set an attribute,
    /// leaving `label.text` as the plain (non-attributed) source of truth.
    private func applyAccumulatedAttributes(on label: UILabel) {
        let attrs = storedAttributes(on: label)
        guard !attrs.isEmpty else { return }
        var merged = attrs
        merged[.font] = label.font as Any
        label.attributedText = NSAttributedString(string: label.text ?? "", attributes: merged)
    }

    // MARK: - Font state storage via associated objects

    private func storeFontSize(_ size: CGFloat, on view: UIView) {
        objc_setAssociatedObject(view, &VTextFactory.fontSizeKey, size, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func storedFontSize(on view: UIView) -> CGFloat? {
        return objc_getAssociatedObject(view, &VTextFactory.fontSizeKey) as? CGFloat
    }

    private func storeFontWeight(_ weight: String?, on view: UIView) {
        objc_setAssociatedObject(view, &VTextFactory.fontWeightKey, weight, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func storedFontWeight(on view: UIView) -> String? {
        return objc_getAssociatedObject(view, &VTextFactory.fontWeightKey) as? String
    }

    private func storeFontFamily(_ family: String?, on view: UIView) {
        objc_setAssociatedObject(view, &VTextFactory.fontFamilyKey, family, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func storedFontFamily(on view: UIView) -> String? {
        return objc_getAssociatedObject(view, &VTextFactory.fontFamilyKey) as? String
    }

    private func storeTextChildren(_ children: [UIView], on view: UIView) {
        objc_setAssociatedObject(view, &VTextFactory.textChildrenKey, children, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func storedTextChildren(on view: UIView) -> [UIView] {
        return objc_getAssociatedObject(view, &VTextFactory.textChildrenKey) as? [UIView] ?? []
    }

    private func rebuildText(from children: [UIView], on label: UILabel) {
        let text = children.compactMap { child -> String? in
            (child as? UILabel)?.text
        }.joined()
        label.text = text.isEmpty ? nil : text
        // Setting .text wipes any previously computed .attributedText.
        applyAccumulatedAttributes(on: label)
        label.flex.markDirty()
    }
}
#endif
