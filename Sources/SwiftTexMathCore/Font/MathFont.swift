import CoreGraphics
import Foundation

/// Bundled OpenType math font identity and point size.
public struct MathFont: Hashable, Sendable {
    public struct Name: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }

        public static let latinModern: Name = "latinmodern-math"
        public static let asana: Name = "Asana-Math"
        public static let euler: Name = "Euler-Math"
        public static let fira: Name = "FiraMath-Regular"
        public static let garamond: Name = "Garamond-Math"
        public static let kpLight: Name = "KpMath-Light"
        public static let kpSans: Name = "KpMath-Sans"
        public static let leteSans: Name = "LeteSansMath"
        public static let libertinus: Name = "LibertinusMath-Regular"
        public static let notoSans: Name = "NotoSansMath-Regular"
        public static let termes: Name = "texgyretermes-math"
        public static let xits: Name = "xits-math"

        /// All bundled MATH fonts.
        public static let allBundled: [Name] = [
            .latinModern, .asana, .euler, .fira, .garamond, .kpLight, .kpSans,
            .leteSans, .libertinus, .notoSans, .termes, .xits,
        ]
    }

    public var name: Name
    public var size: CGFloat

    public init(name: Name, size: CGFloat) {
        self.name = name
        self.size = size
    }
}
