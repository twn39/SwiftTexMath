import CoreGraphics
import Foundation

/// Delimiter and fence command handlers (`\left`/`\right`, `\middle`, `\big…`).
enum DelimiterCommands {
    /// TeX `\big` / `\Big` / `\bigg` / `\Bigg` (+ l/r/m) multipliers × font size.
    /// Aligned with SwiftMath / common TeX practice (`\Big` ≈ 1.4×).
    static let sizeMultipliers: [String: CGFloat] = [
        "big": 1.0, "Big": 1.4, "bigg": 1.8, "Bigg": 2.2,
        "bigl": 1.0, "Bigl": 1.4, "biggl": 1.8, "Biggl": 2.2,
        "bigr": 1.0, "Bigr": 1.4, "biggr": 1.8, "Biggr": 2.2,
        "bigm": 1.0, "Bigm": 1.4, "biggm": 1.8, "Biggm": 2.2
    ]

    static func appendSizedDelimiter(
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

    static func appendMiddle(
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

    static func appendLeftRight(
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
}
