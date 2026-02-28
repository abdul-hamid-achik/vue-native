import AppKit
import ObjectiveC

/// Factory for VText — the text display component.
/// Maps to an NSTextField configured as a non-editable label.
/// After any text or font change, calls layoutNode.markDirty() to trigger remeasurement.
final class VTextFactory: NativeComponentFactory {

    // MARK: - Font weight mapping

    /// Maps CSS-like font weight strings to NSFont.Weight values.
    static let fontWeightMap: [String: NSFont.Weight] = [
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

    func createView() -> NSView {
        let label = NSTextField(labelWithString: "")
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.wantsLayer = true
        // Ensure layout node is attached
        label.ensureLayoutNode()
        return label
    }

    func updateProp(view: NSView, key: String, value: Any?) {
        guard let label = view as? NSTextField else { return }

        switch key {
        case "text":
            if let text = value as? String {
                label.stringValue = text
            } else {
                label.stringValue = ""
            }
            label.layoutNode?.markDirty()

        case "numberOfLines":
            if let lines = value as? Int {
                label.maximumNumberOfLines = lines
            } else if let lines = value as? Double {
                label.maximumNumberOfLines = Int(lines)
            } else {
                label.maximumNumberOfLines = 0
            }
            label.layoutNode?.markDirty()

        case "color":
            if let colorStr = value as? String {
                label.textColor = NSColor.fromHex(colorStr)
            } else {
                label.textColor = .labelColor
            }

        case "fontSize":
            let size: CGFloat
            if let num = value as? Double {
                size = CGFloat(num)
            } else if let num = value as? Int {
                size = CGFloat(num)
            } else {
                size = 13.0 // macOS system default
            }
            storeFontSize(size, on: label)
            rebuildFont(for: label)
            label.layoutNode?.markDirty()

        case "fontWeight":
            if let str = value as? String {
                storeFontWeight(str, on: label)
            } else {
                storeFontWeight(nil, on: label)
            }
            rebuildFont(for: label)
            label.layoutNode?.markDirty()

        case "fontFamily":
            if let family = value as? String {
                storeFontFamily(family, on: label)
            } else {
                storeFontFamily(nil, on: label)
            }
            rebuildFont(for: label)
            label.layoutNode?.markDirty()

        case "textAlign":
            if let alignStr = value as? String {
                label.alignment = VTextFactory.textAlignMap[alignStr] ?? .natural
            } else {
                label.alignment = .natural
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
                let currentFont = label.font ?? NSFont.systemFont(ofSize: 13)
                let currentSize = currentFont.pointSize
                if str == "italic" {
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits(.italic)
                    label.font = NSFont(descriptor: descriptor, size: currentSize)
                } else {
                    var traits = currentFont.fontDescriptor.symbolicTraits
                    traits.remove(.italic)
                    let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits)
                    label.font = NSFont(descriptor: descriptor, size: currentSize)
                }
            }
            label.layoutNode?.markDirty()

        case "lineHeight":
            if let num = value as? Double {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.minimumLineHeight = CGFloat(num)
                paragraphStyle.maximumLineHeight = CGFloat(num)
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

        case "letterSpacing":
            if let num = value as? Double {
                let text = label.stringValue
                let font = label.font ?? NSFont.systemFont(ofSize: 13)
                let attrs: [NSAttributedString.Key: Any] = [
                    .kern: CGFloat(num),
                    .font: font
                ]
                label.attributedStringValue = NSAttributedString(string: text, attributes: attrs)
                label.layoutNode?.markDirty()
            }

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

        case "textTransform":
            if let str = value as? String {
                let original = label.stringValue
                switch str {
                case "uppercase": label.stringValue = original.uppercased()
                case "lowercase": label.stringValue = original.lowercased()
                case "capitalize": label.stringValue = original.capitalized
                default: break
                }
                label.layoutNode?.markDirty()
            }

        default:
            // Delegate unknown props to StyleEngine for layout/visual styling
            StyleEngine.apply(key: key, value: value, to: view)
        }
    }

    func addEventListener(view: NSView, event: String, handler: @escaping (Any?) -> Void) {
        // Click/press support via gesture recognizer.
        if event == "press" {
            let wrapper = ClickGestureWrapper(handler: handler)
            let click = NSClickGestureRecognizer(
                target: wrapper,
                action: #selector(ClickGestureWrapper.handleGesture(_:))
            )
            view.addGestureRecognizer(click)
            GestureStorage.store(wrapper, for: view, event: event)
        }
    }

    func removeEventListener(view: NSView, event: String) {
        if event == "press" {
            GestureStorage.remove(for: view, event: event)
            view.gestureRecognizers.forEach { recognizer in
                if recognizer is NSClickGestureRecognizer {
                    view.removeGestureRecognizer(recognizer)
                }
            }
        }
    }

    // MARK: - Font rebuilding

    /// Rebuild the NSFont from stored fontSize, fontWeight, and fontFamily.
    private func rebuildFont(for label: NSTextField) {
        let size = storedFontSize(on: label) ?? 13.0
        let weightStr = storedFontWeight(on: label)
        let family = storedFontFamily(on: label)

        let weight = weightStr.flatMap { VTextFactory.fontWeightMap[$0] } ?? .regular

        if let family = family, !family.isEmpty {
            // Try to create a font with the specified family
            if let customFont = NSFont(name: family, size: size) {
                label.font = customFont
            } else {
                // Fallback: try as a font descriptor family
                let descriptor = NSFontDescriptor()
                    .withFamily(family)
                label.font = NSFont(descriptor: descriptor, size: size)
            }
        } else {
            label.font = NSFont.systemFont(ofSize: size, weight: weight)
        }
    }

    // MARK: - Font state storage via associated objects

    private func storeFontSize(_ size: CGFloat, on view: NSView) {
        objc_setAssociatedObject(view, &VTextFactory.fontSizeKey, size, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func storedFontSize(on view: NSView) -> CGFloat? {
        return objc_getAssociatedObject(view, &VTextFactory.fontSizeKey) as? CGFloat
    }

    private func storeFontWeight(_ weight: String?, on view: NSView) {
        objc_setAssociatedObject(view, &VTextFactory.fontWeightKey, weight, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func storedFontWeight(on view: NSView) -> String? {
        return objc_getAssociatedObject(view, &VTextFactory.fontWeightKey) as? String
    }

    private func storeFontFamily(_ family: String?, on view: NSView) {
        objc_setAssociatedObject(view, &VTextFactory.fontFamilyKey, family, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func storedFontFamily(on view: NSView) -> String? {
        return objc_getAssociatedObject(view, &VTextFactory.fontFamilyKey) as? String
    }
}
