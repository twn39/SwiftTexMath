import Foundation

/// Style, color, mathchoice, and `\not` command handlers.
enum StyleCommands {
    static let styleVariants: [String: (MathVariant, Bool)] = [
        "mathrm": (.upright, false),
        "textrm": (.upright, false),
        "rm": (.upright, false),
        "text": (.upright, true),
        "mathbf": (.bold, false),
        "textbf": (.bold, true),
        "bf": (.bold, false),
        "mathit": (.italic, false),
        "textit": (.italic, true),
        "mit": (.italic, false),
        "mathcal": (.caligraphic, false),
        "cal": (.caligraphic, false),
        "mathscr": (.script, false),
        "mathfrak": (.fraktur, false),
        "frak": (.fraktur, false),
        "mathbb": (.blackboard, false),
        "mathsf": (.sans, false),
        "textsf": (.sans, true),
        "mathtt": (.typewriter, false),
        "texttt": (.typewriter, true),
        "mathnormal": (.italic, false),
        "mathbfit": (.boldItalic, false),
        "bm": (.boldItalic, false),
        "boldsymbol": (.boldItalic, false),
    ]

    /// Common `\not` + relation combinations.
    static let notCombinations: [String: String] = [
        "=": "\u{2260}",
        "equiv": "\u{2262}",
        "approx": "\u{2249}",
        "cong": "\u{2247}",
        "sim": "\u{2241}",
        "simeq": "\u{2244}",
        "in": "\u{2209}",
        "subset": "\u{2284}",
        "supset": "\u{2285}",
        "subseteq": "\u{2288}",
        "supseteq": "\u{2289}",
        "leq": "\u{2270}",
        "geq": "\u{2271}",
        "le": "\u{2270}",
        "ge": "\u{2271}",
        "prec": "\u{2280}",
        "succ": "\u{2281}",
        "mid": "\u{2224}",
        "parallel": "\u{2226}",
    ]

    static func handleLeaf(
        _ command: String,
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws -> Bool {
        switch command {
        case "color", "textcolor":
            try appendColor(parser: &parser, list: &list, prev: &prev, fillsBackground: false)
        case "colorbox":
            try appendColor(parser: &parser, list: &list, prev: &prev, fillsBackground: true)
        case "mathchoice":
            try appendMathChoice(parser: &parser, list: &list, prev: &prev)
        case "not":
            try appendNot(parser: &parser, list: &list, prev: &prev)
        case "overline":
            try appendOverline(parser: &parser, list: &list, prev: &prev)
        case "underline":
            try appendUnderline(parser: &parser, list: &list, prev: &prev)
        default:
            return false
        }
        return true
    }

    static func appendStyled(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        variant: MathVariant,
        allowSpaces: Bool
    ) throws {
        let contents = try parser.readArgument(allowSpaces: allowSpaces)
        let atom = MathAtom(
            kind: .ordinary,
            payload: .styled(.init(variant: variant, contents: contents))
        )
        list.append(atom)
        prev = atom
    }

    static func appendColor(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        fillsBackground: Bool
    ) throws {
        let color = try parser.readColor()
        guard MathColor.components(from: color) != nil else {
            throw ParseError(code: .invalidCommand, message: "Unknown color '\(color)'")
        }
        let contents = try parser.readArgument()
        let atom = MathAtom(
            kind: .ordinary,
            payload: .colored(
                .init(color: color, contents: contents, fillsBackground: fillsBackground)
            )
        )
        list.append(atom)
        prev = atom
    }

    static func appendMathChoice(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let display = try parser.readArgument()
        let text = try parser.readArgument()
        let script = try parser.readArgument()
        let scriptScript = try parser.readArgument()
        let atom = MathAtom(
            kind: .ordinary,
            payload: .mathChoice(
                .init(display: display, text: text, script: script, scriptScript: scriptScript)
            )
        )
        list.append(atom)
        prev = atom
    }

    static func appendNot(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        parser.skipSpaces()
        guard parser.hasCharacters else {
            throw ParseError(code: .unexpectedEnd, message: "\\not requires a following symbol")
        }
        if parser.peek() == "\\" {
            _ = parser.nextCharacter()
            let name = parser.readCommandName()
            let key = AtomFactory.resolveAlias(name)
            guard let nucleus = notCombinations[key] ?? notCombinations[name] else {
                throw ParseError(code: .invalidCommand, message: "Unsupported \\not\\\(name) combination")
            }
            let atom = MathAtom.relation(nucleus)
            list.append(atom)
            prev = atom
            return
        }
        let ch = parser.nextCharacter()
        let key = String(ch)
        guard let nucleus = notCombinations[key] else {
            throw ParseError(code: .invalidCommand, message: "Unsupported \\not\(ch) combination")
        }
        let atom = MathAtom.relation(nucleus)
        list.append(atom)
        prev = atom
    }

    static func appendOverline(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let atom = MathAtom(kind: .overline, payload: .overline(try parser.readArgument()))
        list.append(atom)
        prev = atom
    }

    static func appendUnderline(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let atom = MathAtom(kind: .underline, payload: .underline(try parser.readArgument()))
        list.append(atom)
        prev = atom
    }
}
