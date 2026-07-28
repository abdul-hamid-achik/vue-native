#if canImport(UIKit)
import UIKit

extension UIColor {

    // MARK: - Named color lookup

    private static let namedColors: [String: UIColor] = [
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

    // MARK: - Color parsing

    /// Creates a UIColor from a CSS-like color string.
    ///
    /// Supported formats:
    /// - Hex: `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA` (alpha last, matching the
    ///   cross-platform `#RRGGBBAA` convention).
    /// - Functional: `rgb(r, g, b)` and `rgba(r, g, b, a)` where r/g/b are
    ///   0...255 and alpha is 0...1.
    /// - Named colors: `transparent`, `white`, `black`, `red`, `blue`, `green`,
    ///   `gray`, `grey`, `orange`, `yellow`, `purple`, `cyan`, `magenta`, `brown`.
    ///
    /// Returns `nil` for invalid input so callers can ignore the style and keep
    /// the previously applied value instead of silently clearing the view.
    static func fromHex(_ hex: String) -> UIColor? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        // Check named colors first
        if let named = namedColors[trimmed] {
            return named
        }

        // Functional notation: rgb(...) / rgba(...)
        if trimmed.hasPrefix("rgb") {
            return parseRGBFunctional(trimmed)
        }

        // Hex notation must start with '#'
        guard trimmed.hasPrefix("#") else {
            return nil
        }

        let hexString = String(trimmed.dropFirst())
        // Scanner.scanHexInt64 stops at the first invalid character and still
        // reports success, so validate the whole string is hex up front.
        guard !hexString.isEmpty,
              hexString.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }

        var hexNumber: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&hexNumber) else {
            return nil
        }

        switch hexString.count {
        case 3:
            // #RGB -> #RRGGBB (opaque)
            let r = CGFloat((hexNumber & 0xF00) >> 8) / 15.0
            let g = CGFloat((hexNumber & 0x0F0) >> 4) / 15.0
            let b = CGFloat(hexNumber & 0x00F) / 15.0
            return UIColor(red: r, green: g, blue: b, alpha: 1.0)

        case 4:
            // #RGBA -> #RRGGBBAA (each nibble expanded)
            let r = CGFloat((hexNumber & 0xF000) >> 12) / 15.0
            let g = CGFloat((hexNumber & 0x0F00) >> 8) / 15.0
            let b = CGFloat((hexNumber & 0x00F0) >> 4) / 15.0
            let a = CGFloat(hexNumber & 0x000F) / 15.0
            return UIColor(red: r, green: g, blue: b, alpha: a)

        case 6:
            // #RRGGBB
            let r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(hexNumber & 0x0000FF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: 1.0)

        case 8:
            // #RRGGBBAA
            let r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(hexNumber & 0x000000FF) / 255.0
            return UIColor(red: r, green: g, blue: b, alpha: a)

        default:
            return nil
        }
    }

    /// Parse `rgb(r, g, b)` / `rgba(r, g, b, a)`. Channels are 0...255; alpha is
    /// 0...1 (defaulting to 1 when omitted).
    private static func parseRGBFunctional(_ value: String) -> UIColor? {
        guard let open = value.firstIndex(of: "("),
              let close = value.lastIndex(of: ")"),
              open < close else {
            return nil
        }

        let inner = value[value.index(after: open)..<close]
        let parts = inner
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard parts.count == 3 || parts.count == 4,
              let r = Double(parts[0]),
              let g = Double(parts[1]),
              let b = Double(parts[2]) else {
            return nil
        }

        let alpha = parts.count == 4 ? (Double(parts[3]) ?? 1.0) : 1.0
        return UIColor(
            red: CGFloat(r / 255.0),
            green: CGFloat(g / 255.0),
            blue: CGFloat(b / 255.0),
            alpha: CGFloat(alpha)
        )
    }
}
#endif
