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
            if let text = value as? String {
                label.text = text
            } else {
                label.text = nil
            }
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
                label.textColor = UIColor.fromHex(colorStr)
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
            }
            label.flex.markDirty()

        case "lineHeight":
            if let num = value as? Double {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.minimumLineHeight = CGFloat(num)
                paragraphStyle.maximumLineHeight = CGFloat(num)
                paragraphStyle.alignment = label.textAlignment
                let text = label.text ?? ""
                let attrs: [NSAttributedString.Key: Any] = [
                    .paragraphStyle: paragraphStyle,
                    .font: label.font as Any
                ]
                label.attributedText = NSAttributedString(string: text, attributes: attrs)
                label.flex.markDirty()
            }

        case "letterSpacing":
            if let num = value as? Double {
                let text = label.text ?? ""
                let attrs: [NSAttributedString.Key: Any] = [
                    .kern: CGFloat(num),
                    .font: label.font as Any
                ]
                label.attributedText = NSAttributedString(string: text, attributes: attrs)
                label.flex.markDirty()
            }

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

        case "textTransform":
            if let str = value as? String {
                let original = label.text ?? ""
                switch str {
                case "uppercase": label.text = original.uppercased()
                case "lowercase": label.text = original.lowercased()
                case "capitalize": label.text = original.capitalized
                default: break
                }
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

    // MARK: - Font rebuilding

    /// Rebuild the UIFont from stored fontSize, fontWeight, and fontFamily.
    private func rebuildFont(for label: UILabel) {
        let size = storedFontSize(on: label) ?? 17.0
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
}
#endif
