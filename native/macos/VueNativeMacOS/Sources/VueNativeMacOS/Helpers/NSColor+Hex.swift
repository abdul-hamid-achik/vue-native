import AppKit

extension NSColor {

    // MARK: - Named color lookup

    private static let namedColors: [String: NSColor] = [
        "transparent": .clear,
        "black": .black,
        "white": .white,
        "red": .red,
        "green": .green,
        "blue": .blue,
        "gray": .gray,
        "grey": .gray,
        "orange": .orange,
        "yellow": .yellow,
        "purple": .purple,
        "cyan": .cyan,
        "magenta": .magenta,
        "brown": .brown
    ]

    // MARK: - Semantic color lookup

    /// Semantic color names that resolve to dynamic AppKit catalog colors.
    /// These adapt automatically to light/dark appearance changes, so a style
    /// like `color: "label"` stays legible in both modes without extra work.
    ///
    /// `systemBlue` maps to `controlAccentColor` because macOS has no
    /// `NSColor.systemBlue` (that symbol is iOS-only); the control accent color
    /// is the platform-correct "system blue" on macOS and follows the user's
    /// accent-color preference.
    private static let semanticColors: [String: NSColor] = [
        "background": .windowBackgroundColor,
        "label": .labelColor,
        "secondarylabel": .secondaryLabelColor,
        "tertiarylabel": .tertiaryLabelColor,
        "separator": .separatorColor,
        "systemblue": .controlAccentColor,
        "systemred": .systemRed,
        "systemgreen": .systemGreen,
        "systemorange": .systemOrange,
        "systemgray": .systemGray
    ]

    // MARK: - Hex / functional initializer

    /// Creates an NSColor from a color string.
    ///
    /// Supported formats:
    /// - Hex: `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA` (8 digits = alpha last).
    /// - Functional: `rgb(r, g, b)` and `rgba(r, g, b, a)` where r/g/b are
    ///   0...255 and alpha is 0...1.
    /// - Named colors: `transparent`, `white`, `black`, `red`, `blue`, `green`,
    ///   `gray`, `grey`, `orange`, `yellow`, `purple`, `cyan`, `magenta`, `brown`.
    /// - Semantic colors (dynamic, auto dark-mode): `background`, `label`,
    ///   `secondaryLabel`, `tertiaryLabel`, `separator`, `systemBlue`,
    ///   `systemRed`, `systemGreen`, `systemOrange`, `systemGray`.
    ///
    /// Returns `nil` for invalid input so callers can ignore the style rather
    /// than silently applying a transparent color. Emits a warning in DEBUG.
    static func fromHex(_ hex: String) -> NSColor? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Check named colors first
        if let named = namedColors[trimmed] {
            return named
        }

        // Semantic (dynamic catalog) colors — case-insensitive via `trimmed`.
        if let semantic = semanticColors[trimmed] {
            return semantic
        }

        // Functional notation: rgb(...) / rgba(...)
        if trimmed.hasPrefix("rgb") {
            if let color = parseFunctional(trimmed) {
                return color
            }
            warnInvalid(hex)
            return nil
        }

        // Must start with '#'
        guard trimmed.hasPrefix("#") else {
            warnInvalid(hex)
            return nil
        }

        let hexString = String(trimmed.dropFirst())
        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0

        guard scanner.scanHexInt64(&hexNumber), scanner.isAtEnd else {
            warnInvalid(hex)
            return nil
        }

        switch hexString.count {
        case 3:
            // #RGB -> #RRGGBB
            let r = CGFloat((hexNumber & 0xF00) >> 8) / 15.0
            let g = CGFloat((hexNumber & 0x0F0) >> 4) / 15.0
            let b = CGFloat(hexNumber & 0x00F) / 15.0
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)

        case 4:
            // #RGBA -> #RRGGBBAA
            let r = CGFloat((hexNumber & 0xF000) >> 12) / 15.0
            let g = CGFloat((hexNumber & 0x0F00) >> 8) / 15.0
            let b = CGFloat((hexNumber & 0x00F0) >> 4) / 15.0
            let a = CGFloat(hexNumber & 0x000F) / 15.0
            return NSColor(red: r, green: g, blue: b, alpha: a)

        case 6:
            // #RRGGBB
            let r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(hexNumber & 0x0000FF) / 255.0
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)

        case 8:
            // #RRGGBBAA
            let r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(hexNumber & 0x000000FF) / 255.0
            return NSColor(red: r, green: g, blue: b, alpha: a)

        default:
            warnInvalid(hex)
            return nil
        }
    }

    // MARK: - Functional notation parser

    /// Parses `rgb(r, g, b)` and `rgba(r, g, b, a)`.
    /// r/g/b are 0...255; alpha is 0...1.
    private static func parseFunctional(_ input: String) -> NSColor? {
        guard let open = input.firstIndex(of: "("),
              let close = input.lastIndex(of: ")"),
              open < close else { return nil }

        let inner = input[input.index(after: open)..<close]
        let parts = inner
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let isRGBA = input.hasPrefix("rgba")
        let expectedCount = isRGBA ? 4 : 3
        guard parts.count == expectedCount else { return nil }

        guard let r = Double(parts[0]),
              let g = Double(parts[1]),
              let b = Double(parts[2]) else { return nil }

        var alpha = 1.0
        if isRGBA {
            guard let a = Double(parts[3]) else { return nil }
            alpha = a
        }

        return NSColor(
            red: CGFloat(r / 255.0),
            green: CGFloat(g / 255.0),
            blue: CGFloat(b / 255.0),
            alpha: CGFloat(max(0, min(1, alpha)))
        )
    }

    // MARK: - Invalid input warning

    private static func warnInvalid(_ input: String) {
        #if DEBUG
        NSLog("[VueNative macOS] NSColor.fromHex: ignoring invalid color string \"\(input)\"")
        #endif
    }
}
