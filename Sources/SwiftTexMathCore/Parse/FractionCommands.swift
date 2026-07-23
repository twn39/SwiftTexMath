import Foundation

/// Fraction, binomial, and radical command handlers.
enum FractionCommands {
    /// Infix fraction tokens (`\over`, `\atop`, `\choose`, …).
    static let infixFractions: [String: (hasRule: Bool, left: String, right: String)] = [
        "over": (true, "", ""),
        "atop": (false, "", ""),
        "choose": (false, "(", ")"),
        "brack": (false, "[", "]"),
        "brace": (false, "{", "}")
    ]

    static func handleLeaf(
        _ command: String,
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws -> Bool {
        switch command {
        case "frac":
            try appendFraction(parser: &parser, list: &list, prev: &prev, forcedStyle: nil, hasRule: true)
        case "dfrac":
            try appendFraction(parser: &parser, list: &list, prev: &prev, forcedStyle: .display, hasRule: true)
        case "tfrac":
            try appendFraction(parser: &parser, list: &list, prev: &prev, forcedStyle: .text, hasRule: true)
        case "cfrac":
            try appendCFrac(parser: &parser, list: &list, prev: &prev)
        case "binom":
            try appendBinom(parser: &parser, list: &list, prev: &prev, forcedStyle: nil)
        case "dbinom":
            try appendBinom(parser: &parser, list: &list, prev: &prev, forcedStyle: .display)
        case "tbinom":
            try appendBinom(parser: &parser, list: &list, prev: &prev, forcedStyle: .text)
        case "genfrac":
            try appendGenfrac(parser: &parser, list: &list, prev: &prev)
        case "sqrt":
            try appendSqrt(parser: &parser, list: &list, prev: &prev)
        default:
            return false
        }
        return true
    }

    static func appendCFrac(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let alignment = try parser.readOptionalCFracAlignment()
        let num = try parser.readArgument()
        let den = try parser.readArgument()
        let atom = MathAtom(
            kind: .fraction,
            payload: .fraction(
                .init(
                    numerator: num,
                    denominator: den,
                    hasRule: true,
                    forcedStyle: .display,
                    numeratorAlignment: alignment
                )
            )
        )
        list.append(atom)
        prev = atom
    }

    static func appendFraction(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        forcedStyle: MathStyle?,
        hasRule: Bool
    ) throws {
        let num = try parser.readArgument()
        let den = try parser.readArgument()
        let atom = MathAtom(
            kind: .fraction,
            payload: .fraction(
                .init(
                    numerator: num,
                    denominator: den,
                    hasRule: hasRule,
                    forcedStyle: forcedStyle
                )
            )
        )
        list.append(atom)
        prev = atom
    }

    static func appendBinom(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        forcedStyle: MathStyle?
    ) throws {
        let num = try parser.readArgument()
        let den = try parser.readArgument()
        let atom = MathAtom(
            kind: .fraction,
            payload: .fraction(
                .init(
                    numerator: num,
                    denominator: den,
                    hasRule: false,
                    leftDelimiter: "(",
                    rightDelimiter: ")",
                    forcedStyle: forcedStyle
                )
            )
        )
        list.append(atom)
        prev = atom
    }

    /// `\genfrac{left}{right}{thickness}{style}{num}{den}` (amsmath).
    static func appendGenfrac(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let leftRaw = try parser.readBracedRaw()
        let rightRaw = try parser.readBracedRaw()
        let thicknessRaw = try parser.readBracedRaw()
        let styleRaw = try parser.readBracedRaw()
        let num = try parser.readArgument()
        let den = try parser.readArgument()

        let atom = MathAtom(
            kind: .fraction,
            payload: .fraction(
                .init(
                    numerator: num,
                    denominator: den,
                    hasRule: thicknessImpliesRule(thicknessRaw),
                    leftDelimiter: resolveGenfracDelimiter(leftRaw),
                    rightDelimiter: resolveGenfracDelimiter(rightRaw),
                    forcedStyle: styleFromGenfrac(styleRaw)
                )
            )
        )
        list.append(atom)
        prev = atom
    }

    private static func resolveGenfracDelimiter(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("\\") {
            let name = AtomFactory.resolveAlias(String(trimmed.dropFirst()))
            return AtomFactory.boundaryNucleus(forDelimiter: name) ?? trimmed
        }
        return AtomFactory.boundaryNucleus(forDelimiter: trimmed) ?? trimmed
    }

    private static func thicknessImpliesRule(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.isEmpty { return true }
        var number = t
        for suffix in ["pt", "mu", "em", "ex", "bp", "mm", "cm", "in"] {
            if number.hasSuffix(suffix) {
                number = String(number.dropLast(suffix.count))
                break
            }
        }
        guard let value = Double(number) else { return true }
        return value > 0
    }

    private static func styleFromGenfrac(_ raw: String) -> MathStyle? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        switch t {
        case "0", "display": return .display
        case "1", "text": return .text
        case "2", "script": return .script
        case "3", "scriptscript": return .scriptScript
        default: return nil
        }
    }

    static func appendSqrt(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        var degree: MathList?
        parser.skipSpaces()
        if parser.peek() == "[" {
            _ = parser.nextCharacter()
            degree = try parser.buildInternal(stop: .character("]"))
            guard parser.hasCharacters, parser.nextCharacter() == "]" else {
                throw ParseError(code: .missingDelimiter, message: "Missing ] after sqrt degree")
            }
        }
        let radicand = try parser.readArgument()
        let atom = MathAtom(
            kind: .radical,
            payload: .radical(.init(degree: degree, radicand: radicand))
        )
        list.append(atom)
        prev = atom
    }
}
