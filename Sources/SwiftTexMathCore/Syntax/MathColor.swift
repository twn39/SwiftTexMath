import CoreGraphics
import Foundation

/// Resolves LaTeX `\color{…}` arguments to sRGB components.
public enum MathColor {
    public struct Components: Sendable, Hashable {
        public var red: CGFloat
        public var green: CGFloat
        public var blue: CGFloat
        public var alpha: CGFloat

        public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
            self.red = red
            self.green = green
            self.blue = blue
            self.alpha = alpha
        }

        public var cgColor: CGColor {
            CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }
    }

    private static let named: [String: Components] = [
        "black": .init(red: 0, green: 0, blue: 0),
        "white": .init(red: 1, green: 1, blue: 1),
        "red": .init(red: 1, green: 0, blue: 0),
        "green": .init(red: 0, green: 0.5, blue: 0),
        "blue": .init(red: 0, green: 0, blue: 1),
        "cyan": .init(red: 0, green: 1, blue: 1),
        "magenta": .init(red: 1, green: 0, blue: 1),
        "yellow": .init(red: 1, green: 1, blue: 0),
        "orange": .init(red: 1, green: 0.647, blue: 0),
        "purple": .init(red: 0.5, green: 0, blue: 0.5),
        "brown": .init(red: 0.65, green: 0.16, blue: 0.16),
        "gray": .init(red: 0.5, green: 0.5, blue: 0.5),
        "grey": .init(red: 0.5, green: 0.5, blue: 0.5),
    ]

    public static func components(from raw: String) -> Components? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("#") {
            return hex(trimmed)
        }
        return named[trimmed.lowercased()]
    }

    private static func hex(_ string: String) -> Components? {
        var hex = string.dropFirst()
        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()[...]
        }
        guard hex.count == 6,
              let value = UInt32(hex, radix: 16)
        else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        return Components(red: r, green: g, blue: b)
    }
}
