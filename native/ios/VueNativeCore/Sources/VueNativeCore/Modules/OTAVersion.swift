#if canImport(UIKit)
import Foundation

/// A parsed OTA version: `[v|V]core[-prerelease][+build]`.
///
/// - `core` is 1 to 4 dot-separated non-negative integers of at most 9 digits.
///   Missing components count as 0, so `1.2` equals `1.2.0`.
/// - `prerelease` is dot-separated identifiers made of `[0-9A-Za-z-]`, none empty.
/// - `build` must be valid identifiers but is ignored for ordering.
///
/// Ordering is semver precedence. A release is newer than any prerelease of the
/// same core. Numeric identifiers compare numerically and rank below alphanumeric
/// ones. Alphanumeric identifiers compare in ASCII order. A shorter identifier list
/// ranks lower when it is a prefix of the longer one.
struct OTAVersion: Equatable, Comparable {
    let core: [Int]
    let prerelease: [String]

    init?(_ text: String) {
        var rest = Substring(text)
        if let first = rest.first, first == "v" || first == "V" {
            rest = rest.dropFirst()
        }
        // Build metadata is split off first, so a `-` inside it is not read as a
        // prerelease separator.
        if let plus = rest.firstIndex(of: "+") {
            guard Self.isIdentifierList(rest[rest.index(after: plus)...]) else { return nil }
            rest = rest[..<plus]
        }
        var prerelease: [String] = []
        if let dash = rest.firstIndex(of: "-") {
            let identifiers = rest[rest.index(after: dash)...]
            guard Self.isIdentifierList(identifiers) else { return nil }
            prerelease = identifiers.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            rest = rest[..<dash]
        }
        let parts = rest.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(parts.count) else { return nil }
        var core: [Int] = []
        for part in parts {
            guard (1...9).contains(part.count),
                  part.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let value = Int(part) else { return nil }
            core.append(value)
        }
        self.core = core
        self.prerelease = prerelease
    }

    static func == (lhs: OTAVersion, rhs: OTAVersion) -> Bool {
        compare(lhs, rhs) == 0
    }

    static func < (lhs: OTAVersion, rhs: OTAVersion) -> Bool {
        compare(lhs, rhs) < 0
    }

    /// Returns -1, 0 or 1 by semver precedence.
    static func compare(_ lhs: OTAVersion, _ rhs: OTAVersion) -> Int {
        for index in 0..<max(lhs.core.count, rhs.core.count) {
            let left = index < lhs.core.count ? lhs.core[index] : 0
            let right = index < rhs.core.count ? rhs.core[index] : 0
            if left != right { return left < right ? -1 : 1 }
        }
        switch (lhs.prerelease.isEmpty, rhs.prerelease.isEmpty) {
        case (true, true): return 0
        case (true, false): return 1
        case (false, true): return -1
        case (false, false): break
        }
        for (left, right) in zip(lhs.prerelease, rhs.prerelease) {
            let result = comparePrereleaseIdentifier(left, right)
            if result != 0 { return result }
        }
        if lhs.prerelease.count == rhs.prerelease.count { return 0 }
        return lhs.prerelease.count < rhs.prerelease.count ? -1 : 1
    }

    private static func comparePrereleaseIdentifier(_ left: String, _ right: String) -> Int {
        switch (isNumericIdentifier(left), isNumericIdentifier(right)) {
        case (true, true):
            // Compare by magnitude without Int, so long numbers cannot overflow.
            let leftDigits = left.drop(while: { $0 == "0" })
            let rightDigits = right.drop(while: { $0 == "0" })
            if leftDigits.count != rightDigits.count {
                return leftDigits.count < rightDigits.count ? -1 : 1
            }
            return compareBytes(leftDigits, rightDigits)
        case (true, false): return -1
        case (false, true): return 1
        case (false, false): return compareBytes(left, right)
        }
    }

    private static func compareBytes<S: StringProtocol>(_ left: S, _ right: S) -> Int {
        if left == right { return 0 }
        return left.utf8.lexicographicallyPrecedes(right.utf8) ? -1 : 1
    }

    private static func isNumericIdentifier(_ identifier: String) -> Bool {
        !identifier.isEmpty && identifier.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// `true` for one or more dot-separated identifiers, each non-empty and made of
    /// `[0-9A-Za-z-]`.
    private static func isIdentifierList(_ text: Substring) -> Bool {
        text.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { identifier in
            !identifier.isEmpty && identifier.allSatisfy { character in
                character == "-" || (character.isASCII && (character.isLetter || character.isNumber))
            }
        }
    }
}
#endif
