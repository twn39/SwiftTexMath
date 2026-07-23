import CoreGraphics
import Foundation

/// Alphabet / face used when mapping letters to glyphs.
public enum MathVariant: Sendable, Hashable {
    /// Default math italic for Latin letters.
    case italic
    /// Upright (`\mathrm`, `\text`).
    case upright
    /// Bold math (`\mathbf`) via Unicode Mathematical Bold when possible.
    case bold
    /// Calligraphic (`\mathcal`) via Unicode Mathematical Script when possible.
    case caligraphic
    /// Script face (`\mathscr`); mapped like calligraphic with the same Unicode block.
    case script
    /// Fraktur (`\mathfrak`).
    case fraktur
    /// Blackboard bold / double-struck (`\mathbb`).
    case blackboard
    /// Bold italic (`\boldsymbol`, `\mathbfit`, `\bm`).
    case boldItalic
    /// Sans-serif (`\mathsf`).
    case sans
    /// Typewriter (`\mathtt`).
    case typewriter
}

/// TeX math style (Appendix G styles without the cramped bit).
public enum MathStyle: Int, Sendable, Hashable, CaseIterable {
    case display = 0
    case text
    case script
    case scriptScript

    public var isScript: Bool {
        self == .script || self == .scriptScript
    }

    public var scriptStyle: MathStyle {
        switch self {
        case .display, .text: return .script
        case .script, .scriptScript: return .scriptScript
        }
    }

    public var sizeMultiplier: CGFloat {
        switch self {
        case .display, .text: return 1
        case .script: return 0.7
        case .scriptScript: return 0.5
        }
    }
}
