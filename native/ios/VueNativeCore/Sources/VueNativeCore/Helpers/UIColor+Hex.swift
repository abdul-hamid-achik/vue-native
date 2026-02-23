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

    // MARK: - Hex initializer

    /// Creates a UIColor from a hex string.
    /// Supports formats: "#RGB", "#RRGGBB", "#RRGGBBAA"
    /// Also supports named colors: "transparent", "black", "white", "red", "green", "blue", "gray"
    /// Returns .clear for invalid input.
    static func fromHex(_ hex: String) -> UIColor {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Check named colors first
        if let named = namedColors[trimmed] {
            return named
        }

        // Must start with '#'
        guard trimmed.hasPrefix("#") else {
            return .clear
        }

        let hexString = String(trimmed.dropFirst())
        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0

        guard scanner.scanHexInt64(&hexNumber) else {
            return .clear
        }

        switch hexString.count {
        case 3:
            // #RGB -> #RRGGBB
            let r = CGFloat((hexNumber & 0xF00) >> 8) / 15.0
            let g = CGFloat((hexNumber & 0x0F0) >> 4) / 15.0
            let b = CGFloat(hexNumber & 0x00F) / 15.0
            return UIColor(red: r, green: g, blue: b, alpha: 1.0)

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
            return .clear
        }
    }
}
#endif
