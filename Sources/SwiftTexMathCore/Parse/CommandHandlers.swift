import Foundation

/// Structural LaTeX command handlers extracted from the recursive-descent core.
enum CommandHandlers {
    enum Result {
        case notHandled
        case handled
        /// `\over` / `\atop` / `\choose` / … — replace current list with a fraction.
        case infixFraction(hasRule: Bool, leftDelimiter: String, rightDelimiter: String)
    }

    /// TeX `\big` / `\Big` / `\bigg` / `\Bigg` (+ l/r/m) multipliers × font size.
    static let delimiterSizeMultipliers: [String: CGFloat] = [
        "big": 1.0, "Big": 1.2, "bigg": 1.8, "Bigg": 2.2,
        "bigl": 1.0, "Bigl": 1.2, "biggl": 1.8, "Biggl": 2.2,
        "bigr": 1.0, "Bigr": 1.2, "biggr": 1.8, "Biggr": 2.2,
        "bigm": 1.0, "Bigm": 1.2, "biggm": 1.8, "Biggm": 2.2,
    ]

    static let styleVariants: [String: (MathVariant, Bool)] = [
        "mathrm": (.upright, false),
        "textrm": (.upright, false),
        "text": (.upright, true),
        "mathbf": (.bold, false),
        "textbf": (.bold, true),
        "mathit": (.italic, false),
        "textit": (.italic, true),
        "mathcal": (.caligraphic, false),
        "cal": (.caligraphic, false),
        "mathscr": (.script, false),
        "mathfrak": (.fraktur, false),
        "frak": (.fraktur, false),
        "mathbb": (.blackboard, false),
        "mathsf": (.sans, false),
        "mathtt": (.typewriter, false),
        "mathnormal": (.italic, false),
        "mathbfit": (.boldItalic, false),
        "bm": (.boldItalic, false),
        "boldsymbol": (.boldItalic, false),
    ]

    /// Phantom / smash / lap / cancel specs (iosMath `boxCommands`).
    private struct BoxSpec {
        var keepWidth: Bool
        var keepHeight: Bool
        var keepDepth: Bool
        var drawChild: Bool
        var hAlign: MathAtom.Box.HAlign
        var strike: MathAtom.Box.StrikeStyle
        var acceptsTB: Bool
        var synthParen: Bool
    }

    private static let boxCommands: [String: BoxSpec] = [
        "phantom": .init(keepWidth: true, keepHeight: true, keepDepth: true, drawChild: false, hAlign: .left, strike: .none, acceptsTB: false, synthParen: false),
        "hphantom": .init(keepWidth: true, keepHeight: false, keepDepth: false, drawChild: false, hAlign: .left, strike: .none, acceptsTB: false, synthParen: false),
        "vphantom": .init(keepWidth: false, keepHeight: true, keepDepth: true, drawChild: false, hAlign: .left, strike: .none, acceptsTB: false, synthParen: false),
        "mathstrut": .init(keepWidth: false, keepHeight: true, keepDepth: true, drawChild: false, hAlign: .left, strike: .none, acceptsTB: false, synthParen: true),
        "smash": .init(keepWidth: true, keepHeight: false, keepDepth: false, drawChild: true, hAlign: .left, strike: .none, acceptsTB: true, synthParen: false),
        "llap": .init(keepWidth: false, keepHeight: true, keepDepth: true, drawChild: true, hAlign: .right, strike: .none, acceptsTB: false, synthParen: false),
        "rlap": .init(keepWidth: false, keepHeight: true, keepDepth: true, drawChild: true, hAlign: .left, strike: .none, acceptsTB: false, synthParen: false),
        "clap": .init(keepWidth: false, keepHeight: true, keepDepth: true, drawChild: true, hAlign: .center, strike: .none, acceptsTB: false, synthParen: false),
        "mathllap": .init(keepWidth: false, keepHeight: true, keepDepth: true, drawChild: true, hAlign: .right, strike: .none, acceptsTB: false, synthParen: false),
        "mathrlap": .init(keepWidth: false, keepHeight: true, keepDepth: true, drawChild: true, hAlign: .left, strike: .none, acceptsTB: false, synthParen: false),
        "mathclap": .init(keepWidth: false, keepHeight: true, keepDepth: true, drawChild: true, hAlign: .center, strike: .none, acceptsTB: false, synthParen: false),
        "cancel": .init(keepWidth: true, keepHeight: true, keepDepth: true, drawChild: true, hAlign: .left, strike: .forward, acceptsTB: false, synthParen: false),
        "bcancel": .init(keepWidth: true, keepHeight: true, keepDepth: true, drawChild: true, hAlign: .left, strike: .backward, acceptsTB: false, synthParen: false),
        "xcancel": .init(keepWidth: true, keepHeight: true, keepDepth: true, drawChild: true, hAlign: .left, strike: .cross, acceptsTB: false, synthParen: false),
        "sout": .init(keepWidth: true, keepHeight: true, keepDepth: true, drawChild: true, hAlign: .left, strike: .horizontal, acceptsTB: false, synthParen: false),
    ]

    /// Spacing commands that take a dimension argument (`true` = allow em; `false` = mu only).
    private static let spacingCommands: [String: Bool] = [
        "kern": true,
        "hspace": true,
        "hskip": true,
        "mkern": false,
        "mskip": false,
        "mspace": false,
    ]

    private static let infixFractions: [String: (hasRule: Bool, left: String, right: String)] = [
        "over": (true, "", ""),
        "atop": (false, "", ""),
        "choose": (false, "(", ")"),
        "brack": (false, "[", "]"),
        "brace": (false, "{", "}"),
    ]

    /// Stretchy over/under constructions with a single base argument.
    private static let stretchyStacks: [String: (over: String?, under: String?)] = [
        "overrightarrow": ("\u{2192}", nil),
        "overleftarrow": ("\u{2190}", nil),
        "overleftrightarrow": ("\u{2194}", nil),
        "underrightarrow": (nil, "\u{2192}"),
        "underleftarrow": (nil, "\u{2190}"),
        "underleftrightarrow": (nil, "\u{2194}"),
        "overbrace": ("\u{23DE}", nil),
        "underbrace": (nil, "\u{23DF}"),
    ]

    /// Common `\not` + relation combinations.
    private static let notCombinations: [String: String] = [
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

    static func dispatch(
        _ command: String,
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        oneCharArgument: Bool = false
    ) throws -> Result {
        if let multiplier = delimiterSizeMultipliers[command] {
            try appendSizedDelimiter(
                parser: &parser,
                list: &list,
                prev: &prev,
                command: command,
                multiplier: multiplier
            )
            return .handled
        }

        if let (variant, allowSpaces) = styleVariants[command] {
            try appendStyled(
                parser: &parser,
                list: &list,
                prev: &prev,
                variant: variant,
                allowSpaces: allowSpaces
            )
            return .handled
        }

        if let frac = infixFractions[command] {
            if oneCharArgument {
                throw ParseError(
                    code: .invalidCommand,
                    message: "\\\(command) cannot be used in a one-character argument; wrap it in braces"
                )
            }
            return .infixFraction(hasRule: frac.hasRule, leftDelimiter: frac.left, rightDelimiter: frac.right)
        }

        if let allowEm = spacingCommands[command] {
            try appendKern(parser: &parser, list: &list, prev: &prev, command: command, allowEm: allowEm)
            return .handled
        }

        if let boxSpec = boxCommands[command] {
            try appendBox(parser: &parser, list: &list, prev: &prev, spec: boxSpec)
            return .handled
        }

        if let stretch = stretchyStacks[command] {
            let base = try parser.readArgument()
            let atom = MathAtom(
                kind: .ordinary,
                payload: .stack(
                    .init(
                        base: base,
                        displayKind: .ordinary,
                        overNucleus: stretch.over,
                        underNucleus: stretch.under
                    )
                )
            )
            list.append(atom)
            prev = atom
            return .handled
        }

        switch command {
        case "frac":
            try appendFraction(parser: &parser, list: &list, prev: &prev, forcedStyle: nil, hasRule: true)
        case "dfrac":
            try appendFraction(parser: &parser, list: &list, prev: &prev, forcedStyle: .display, hasRule: true)
        case "tfrac", "cfrac":
            try appendFraction(parser: &parser, list: &list, prev: &prev, forcedStyle: .text, hasRule: true)
        case "binom":
            try appendBinom(parser: &parser, list: &list, prev: &prev, forcedStyle: nil)
        case "dbinom":
            try appendBinom(parser: &parser, list: &list, prev: &prev, forcedStyle: .display)
        case "tbinom":
            try appendBinom(parser: &parser, list: &list, prev: &prev, forcedStyle: .text)
        case "sqrt":
            try appendSqrt(parser: &parser, list: &list, prev: &prev)
        case "left":
            try appendLeftRight(parser: &parser, list: &list, prev: &prev)
        case "right":
            throw ParseError(code: .missingLeft, message: "Missing \\left")
        case "middle":
            try appendMiddle(parser: &parser, list: &list, prev: &prev)
        case "overline":
            let atom = MathAtom(kind: .overline, payload: .overline(try parser.readArgument()))
            list.append(atom)
            prev = atom
        case "underline":
            let atom = MathAtom(kind: .underline, payload: .underline(try parser.readArgument()))
            list.append(atom)
            prev = atom
        case "begin":
            let env = try parser.readBracedName()
            var columnSpec: TableEnvironment.ColumnSpec?
            let baseEnv = env.hasSuffix("*") ? String(env.dropLast()) : env
            if baseEnv == "array" {
                columnSpec = try parser.readColumnSpec()
            } else if env.hasSuffix("*") {
                columnSpec = try parser.readOptionalMatrixAlignment(columnsHint: nil)
            } else if baseEnv == "alignedat" {
                let n = try parser.readBracedInteger()
                columnSpec = TableEnvironment.alignedAtSpec(pairs: n)
            }
            let table = try parser.parseTable(environment: env, columnSpec: columnSpec)
            let atom = MathAtom(kind: .table, payload: .table(table))
            list.append(atom)
            prev = atom
        case "end":
            throw ParseError(code: .missingBegin, message: "Unexpected \\end")
        case "limits", "nolimits":
            guard var op = prev, op.kind == .largeOperator else {
                throw ParseError(code: .invalidLimits, message: "\\limits not after large operator")
            }
            op.payload = .largeOperator(limits: command == "limits")
            list.atoms[list.atoms.count - 1] = op
            prev = op
        case "color", "textcolor":
            try appendColor(parser: &parser, list: &list, prev: &prev)
        case "mathchoice":
            try appendMathChoice(parser: &parser, list: &list, prev: &prev)
        case "overset":
            try appendStack(parser: &parser, list: &list, prev: &prev, role: .over, kind: .ordinary, inherit: true)
        case "underset":
            try appendStack(parser: &parser, list: &list, prev: &prev, role: .under, kind: .ordinary, inherit: true)
        case "stackrel":
            try appendStack(parser: &parser, list: &list, prev: &prev, role: .over, kind: .relation, inherit: false)
        case "stackbin":
            try appendStack(parser: &parser, list: &list, prev: &prev, role: .over, kind: .binaryOperator, inherit: false)
        case "substack":
            let table = try parser.parseSubstack()
            let atom = MathAtom(kind: .table, payload: .table(table))
            list.append(atom)
            prev = atom
            return .handled
        case "not":
            try appendNot(parser: &parser, list: &list, prev: &prev)
            return .handled
        default:
            return .notHandled
        }
        return .handled
    }

    private enum StackRole { case over, under }

    private static func appendStack(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        role: StackRole,
        kind: AtomKind,
        inherit: Bool
    ) throws {
        let first = try parser.readArgument()
        let base = try parser.readArgument()
        var displayKind = kind
        if inherit, base.atoms.count == 1, let only = base.atoms.first {
            if only.kind == .binaryOperator || only.kind == .relation {
                displayKind = only.kind
            }
        }
        let stack: MathAtom.Stack
        switch role {
        case .over:
            stack = .init(base: base, over: first, displayKind: displayKind)
        case .under:
            stack = .init(base: base, under: first, displayKind: displayKind)
        }
        let atom = MathAtom(kind: displayKind, payload: .stack(stack))
        list.append(atom)
        prev = atom
    }

    private static func appendNot(
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

    private static func appendBox(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        spec: BoxSpec
    ) throws {
        var keepHeight = spec.keepHeight
        var keepDepth = spec.keepDepth

        if spec.synthParen {
            let contents = MathList(atoms: [MathAtom.open("(")])
            let atom = MathAtom(
                kind: .ordinary,
                payload: .box(
                    .init(
                        contents: contents,
                        keepWidth: spec.keepWidth,
                        keepHeight: keepHeight,
                        keepDepth: keepDepth,
                        drawChild: spec.drawChild,
                        hAlign: spec.hAlign,
                        strike: spec.strike
                    )
                )
            )
            list.append(atom)
            prev = atom
            return
        }

        if spec.acceptsTB {
            parser.skipSpaces()
            if parser.peek() == "[" {
                _ = parser.nextCharacter()
                var opt = ""
                while parser.hasCharacters, parser.peek() != "]" {
                    opt.append(parser.nextCharacter())
                }
                guard parser.hasCharacters, parser.nextCharacter() == "]" else {
                    throw ParseError(code: .characterNotFound, message: "Expected ] after \\smash option")
                }
                let trimmed = opt.trimmingCharacters(in: .whitespaces)
                if trimmed == "t" {
                    keepHeight = false
                    keepDepth = true
                } else if trimmed == "b" {
                    keepHeight = true
                    keepDepth = false
                }
            }
        }

        let contents = try parser.readOptionalArgument()
        let atom = MathAtom(
            kind: .ordinary,
            payload: .box(
                .init(
                    contents: contents,
                    keepWidth: spec.keepWidth,
                    keepHeight: keepHeight,
                    keepDepth: keepDepth,
                    drawChild: spec.drawChild,
                    hAlign: spec.hAlign,
                    strike: spec.strike
                )
            )
        )
        list.append(atom)
        prev = atom
    }

    private static func appendKern(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        command: String,
        allowEm: Bool
    ) throws {
        // `\hspace*` is identical to `\hspace`.
        if command == "hspace" {
            parser.skipSpaces()
            if parser.peek() == "*" {
                _ = parser.nextCharacter()
            }
        }
        let mu = try parser.readDimensionAsMu(allowEm: allowEm, command: command)
        let atom = MathAtom.space(mu: mu)
        list.append(atom)
        prev = atom
    }

    private static func appendSizedDelimiter(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        command: String,
        multiplier: CGFloat
    ) throws {
        let delim = try parser.readDelimiter()
        guard let nucleus = AtomFactory.boundaryNucleus(forDelimiter: delim), !nucleus.isEmpty else {
            throw ParseError(code: .invalidDelimiter, message: "Invalid delimiter for \\\(command)")
        }

        let kind: AtomKind
        if command.hasSuffix("r") {
            kind = .close
        } else if command.hasSuffix("m") {
            kind = .relation
        } else {
            kind = .open
        }

        let left: String
        let right: String
        if command.hasSuffix("r") {
            left = ""
            right = nucleus
        } else {
            left = nucleus
            right = ""
        }

        let atom = MathAtom(
            kind: kind,
            payload: .inner(
                .init(
                    leftBoundary: left,
                    rightBoundary: right,
                    contents: MathList(),
                    delimiterHeight: multiplier
                )
            )
        )
        list.append(atom)
        prev = atom
    }

    private static func appendMiddle(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let delim = try parser.readDelimiter()
        guard let nucleus = AtomFactory.boundaryNucleus(forDelimiter: delim) else {
            throw ParseError(code: .invalidDelimiter, message: "Invalid \\middle delimiter")
        }
        let atom = MathAtom.boundary(nucleus)
        list.append(atom)
        prev = atom
    }

    private static func appendColor(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let color = try parser.readColor()
        guard MathColor.components(from: color) != nil else {
            throw ParseError(code: .invalidCommand, message: "Unknown color '\(color)'")
        }
        let contents = try parser.readArgument()
        let atom = MathAtom(
            kind: .ordinary,
            payload: .colored(.init(color: color, contents: contents))
        )
        list.append(atom)
        prev = atom
    }

    private static func appendMathChoice(
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

    private static func appendFraction(
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

    private static func appendBinom(
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

    private static func appendSqrt(
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

    private static func appendLeftRight(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let delim = try parser.readDelimiter()
        let contents = try parser.buildInternal(stop: .rightCommand)
        parser.skipSpaces()
        guard parser.hasCharacters, parser.nextCharacter() == "\\" else {
            throw ParseError(code: .missingRight, message: "Missing \\right")
        }
        let rightCmd = parser.readCommandName()
        guard rightCmd == "right" else {
            throw ParseError(code: .missingRight, message: "Missing \\right")
        }
        let rightDelim = try parser.readDelimiter()
        guard
            let leftNucleus = AtomFactory.boundaryNucleus(forDelimiter: delim),
            let rightNucleus = AtomFactory.boundaryNucleus(forDelimiter: rightDelim)
        else {
            throw ParseError(code: .invalidDelimiter, message: "Invalid left/right delimiter")
        }
        let atom = MathAtom(
            kind: .inner,
            payload: .inner(
                .init(
                    leftBoundary: leftNucleus,
                    rightBoundary: rightNucleus,
                    contents: contents
                )
            )
        )
        list.append(atom)
        prev = atom
    }

    private static func appendStyled(
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
}
