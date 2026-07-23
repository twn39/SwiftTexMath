import Foundation

/// TeX noad / iosMath atom classification used for spacing and layout.
public enum AtomKind: Int, Sendable, Hashable, Comparable {
    case ordinary = 1
    case number
    case variable
    case largeOperator
    case binaryOperator
    case relation
    case open
    case close
    case fraction
    case radical
    case punctuation
    case inner
    case underline
    case overline
    case accent
    case boundary = 101
    case space = 201
    case style
    case table = 1001

    public static func < (lhs: AtomKind, rhs: AtomKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var allowsScripts: Bool {
        self < .boundary
    }

    public var disallowsFollowingBinaryOperator: Bool {
        switch self {
        case .binaryOperator, .relation, .open, .punctuation, .largeOperator:
            return true
        default:
            return false
        }
    }

    /// Row/column index into the TeX inter-element spacing matrix.
    public func spacingIndex(isLeft: Bool) -> Int {
        switch self {
        case .ordinary, .number, .variable, .accent, .underline, .overline:
            return 0
        case .largeOperator:
            return 1
        case .binaryOperator:
            return 2
        case .relation:
            return 3
        case .open:
            return 4
        case .close:
            return 5
        case .punctuation:
            return 6
        case .fraction, .inner:
            return 7
        case .radical:
            return isLeft ? 8 : 0
        case .boundary, .space, .style, .table:
            return 0
        }
    }

    /// Layout treats these as ordinary for spacing after normalize.
    public var spacingKind: AtomKind {
        switch self {
        case .number, .variable:
            return .ordinary
        default:
            return self
        }
    }
}
