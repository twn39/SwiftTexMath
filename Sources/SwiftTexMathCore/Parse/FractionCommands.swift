import Foundation

/// Fraction, binomial, and radical command handlers.
enum FractionCommands {
    /// Infix fraction tokens (`\over`, `\atop`, `\choose`, …).
    static let infixFractions: [String: (hasRule: Bool, left: String, right: String)] = [
        "over": (true, "", ""),
        "atop": (false, "", ""),
        "choose": (false, "(", ")"),
        "brack": (false, "[", "]"),
        "brace": (false, "{", "}"),
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
