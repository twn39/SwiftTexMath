import Foundation

/// Phantom / smash / lap / cancel / kern spacing command handlers.
enum BoxCommands {
    struct BoxSpec {
        var keepWidth: Bool
        var keepHeight: Bool
        var keepDepth: Bool
        var drawChild: Bool
        var hAlign: MathAtom.Box.HAlign
        var strike: MathAtom.Box.StrikeStyle
        var acceptsTB: Bool
        var synthParen: Bool
    }

    /// Phantom / smash / lap / cancel specs (iosMath `boxCommands`).
    static let boxCommands: [String: BoxSpec] = [
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
    static let spacingCommands: [String: Bool] = [
        "kern": true,
        "hspace": true,
        "hskip": true,
        "mkern": false,
        "mskip": false,
        "mspace": false,
    ]

    static func appendBox(
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

    static func appendKern(
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
}
