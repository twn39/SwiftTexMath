import Foundation

/// Maps ASCII letters/digits to Unicode Mathematical Alphanumeric Symbols for math variants.
enum MathVariantMapper {
    static func mapNucleus(_ nucleus: String, variant: MathVariant, kind: AtomKind) -> String {
        // Allow multi-char mapping for blackboard digits etc. by mapping char-wise.
        if nucleus.count != 1 {
            return String(nucleus.map { mapCharacter($0, variant: variant, kind: kind) })
        }
        guard let ch = nucleus.first else { return nucleus }
        return String(mapCharacter(ch, variant: variant, kind: kind))
    }

    static func mapCharacter(_ ch: Character, variant: MathVariant, kind: AtomKind) -> Character {
        let isLetter = ("a"..."z").contains(ch) || ("A"..."Z").contains(ch)
        let isDigit = ("0"..."9").contains(ch)

        switch variant {
        case .upright:
            return ch
        case .bold:
            guard isLetter else { return ch }
            return mathBold(ch)
        case .italic:
            if kind == .largeOperator { return ch }
            guard isLetter else { return ch }
            return mathItalic(ch)
        case .caligraphic, .script:
            guard isLetter else { return ch }
            return mathScript(ch)
        case .fraktur:
            guard isLetter else { return ch }
            return mathFraktur(ch)
        case .blackboard:
            if isLetter || isDigit { return mathBlackboard(ch) }
            return ch
        case .boldItalic:
            guard isLetter else { return ch }
            return mathBoldItalic(ch)
        case .sans:
            guard isLetter || isDigit else { return ch }
            return mathSans(ch)
        case .typewriter:
            guard isLetter || isDigit else { return ch }
            return mathTypewriter(ch)
        }
    }

    private static func mathBoldItalic(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first else { return ch }
        let v = scalar.value
        if (65...90).contains(v) {
            return Character(UnicodeScalar(0x1D468 + (v - 65))!)
        }
        if (97...122).contains(v) {
            return Character(UnicodeScalar(0x1D482 + (v - 97))!)
        }
        return ch
    }

    private static func mathSans(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first else { return ch }
        let v = scalar.value
        if (65...90).contains(v) {
            return Character(UnicodeScalar(0x1D5A0 + (v - 65))!)
        }
        if (97...122).contains(v) {
            return Character(UnicodeScalar(0x1D5BA + (v - 97))!)
        }
        if (48...57).contains(v) {
            return Character(UnicodeScalar(0x1D7E2 + (v - 48))!)
        }
        return ch
    }

    private static func mathTypewriter(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first else { return ch }
        let v = scalar.value
        if (65...90).contains(v) {
            return Character(UnicodeScalar(0x1D670 + (v - 65))!)
        }
        if (97...122).contains(v) {
            return Character(UnicodeScalar(0x1D68A + (v - 97))!)
        }
        if (48...57).contains(v) {
            return Character(UnicodeScalar(0x1D7F6 + (v - 48))!)
        }
        return ch
    }

    private static func mathItalic(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first else { return ch }
        let v = scalar.value
        if (65...90).contains(v) {
            return Character(UnicodeScalar(0x1D434 + (v - 65))!)
        }
        if (97...122).contains(v) {
            if ch == "h" { return "\u{210E}" }
            return Character(UnicodeScalar(0x1D44E + (v - 97))!)
        }
        return ch
    }

    private static func mathBold(_ ch: Character) -> Character {
        guard let scalar = ch.unicodeScalars.first else { return ch }
        let v = scalar.value
        if (65...90).contains(v) {
            return Character(UnicodeScalar(0x1D400 + (v - 65))!)
        }
        if (97...122).contains(v) {
            return Character(UnicodeScalar(0x1D41A + (v - 97))!)
        }
        return ch
    }

    /// Unicode Mathematical Script (plus letterlike exceptions used by fonts).
    private static func mathScript(_ ch: Character) -> Character {
        switch ch {
        case "B": return "\u{212C}"
        case "E": return "\u{2130}"
        case "F": return "\u{2131}"
        case "H": return "\u{210B}"
        case "I": return "\u{2110}"
        case "L": return "\u{2112}"
        case "M": return "\u{2133}"
        case "R": return "\u{211B}"
        case "e": return "\u{212F}"
        case "g": return "\u{210A}"
        case "o": return "\u{2134}"
        default:
            guard let scalar = ch.unicodeScalars.first else { return ch }
            let v = scalar.value
            if (65...90).contains(v) {
                return Character(UnicodeScalar(0x1D49C + (v - 65))!)
            }
            if (97...122).contains(v) {
                // LM Math lacks lower script; keep upright letter rather than tofu.
                return ch
            }
            return ch
        }
    }

    private static func mathFraktur(_ ch: Character) -> Character {
        switch ch {
        case "C": return "\u{212D}"
        case "H": return "\u{210C}"
        case "I": return "\u{2111}"
        case "R": return "\u{211C}"
        case "Z": return "\u{2128}"
        default:
            guard let scalar = ch.unicodeScalars.first else { return ch }
            let v = scalar.value
            if (65...90).contains(v) {
                return Character(UnicodeScalar(0x1D504 + (v - 65))!)
            }
            if (97...122).contains(v) {
                return Character(UnicodeScalar(0x1D51E + (v - 97))!)
            }
            return ch
        }
    }

    private static func mathBlackboard(_ ch: Character) -> Character {
        switch ch {
        case "C": return "\u{2102}"
        case "H": return "\u{210D}"
        case "N": return "\u{2115}"
        case "P": return "\u{2119}"
        case "Q": return "\u{211A}"
        case "R": return "\u{211D}"
        case "Z": return "\u{2124}"
        default:
            guard let scalar = ch.unicodeScalars.first else { return ch }
            let v = scalar.value
            if (65...90).contains(v) {
                return Character(UnicodeScalar(0x1D538 + (v - 65))!)
            }
            if (97...122).contains(v) {
                return Character(UnicodeScalar(0x1D552 + (v - 97))!)
            }
            if (48...57).contains(v) {
                return Character(UnicodeScalar(0x1D7D8 + (v - 48))!)
            }
            return ch
        }
    }
}
