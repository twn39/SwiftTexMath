import CoreGraphics
import Foundation

extension MathParser {
    /// Like `readArgument`, but missing content at EOF yields an empty list (phantoms).
    mutating func readOptionalArgument(allowSpaces: Bool = false) throws -> MathList {
        skipSpaces()
        guard hasCharacters else { return MathList() }
        return try readArgument(allowSpaces: allowSpaces)
    }

    /// Parse a TeX dimension (`1em`, `2mu`, `3pt`, bare number as mu) into math units.
    mutating func readDimensionAsMu(allowEm: Bool, command: String) throws -> CGFloat {
        skipSpaces()
        guard peek() == "{" else {
            throw ParseError(code: .invalidCommand, message: "\\\(command) expects a braced dimension")
        }
        _ = nextCharacter()
        var raw = ""
        while hasCharacters, peek() != "}" {
            raw.append(nextCharacter())
        }
        guard hasCharacters, nextCharacter() == "}" else {
            throw ParseError(code: .mismatchedBraces, message: "Missing } after \\\(command) dimension")
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            throw ParseError(code: .invalidCommand, message: "Empty dimension for \\\(command)")
        }

        func parseNumber(_ s: String) throws -> CGFloat {
            guard let value = Double(s) else {
                throw ParseError(code: .invalidCommand, message: "Invalid number in \\\(command)")
            }
            return CGFloat(value)
        }

        if trimmed.hasSuffix("mu") {
            return try parseNumber(String(trimmed.dropLast(2)))
        }
        if trimmed.hasSuffix("em") {
            guard allowEm else {
                throw ParseError(code: .invalidCommand, message: "\\\(command) does not accept em units")
            }
            // 1em ≈ 18mu in math mode.
            return try parseNumber(String(trimmed.dropLast(2))) * 18
        }
        if trimmed.hasSuffix("pt") {
            guard allowEm else {
                throw ParseError(code: .invalidCommand, message: "\\\(command) does not accept pt units")
            }
            // Rough: 1pt ≈ 1mu at 10pt design size; scale with font later via mu.
            return try parseNumber(String(trimmed.dropLast(2)))
        }
        // Bare number → mu
        return try parseNumber(trimmed)
    }

    mutating func readBracedInteger() throws -> Int {
        skipSpaces()
        guard peek() == "{" else {
            throw ParseError(code: .invalidCommand, message: "Expected braced integer")
        }
        _ = nextCharacter()
        var raw = ""
        while hasCharacters, peek() != "}" {
            raw.append(nextCharacter())
        }
        guard hasCharacters, nextCharacter() == "}" else {
            throw ParseError(code: .mismatchedBraces, message: "Missing } after integer")
        }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let value = Int(trimmed), value > 0 else {
            throw ParseError(code: .invalidCommand, message: "Invalid integer '\(trimmed)'")
        }
        return value
    }

    /// Optional `[l|c|r]` alignment for starred matrix environments.
    mutating func readOptionalMatrixAlignment(columnsHint: Int?) throws -> TableEnvironment.ColumnSpec? {
        skipSpaces()
        guard peek() == "[" else { return nil }
        _ = nextCharacter()
        var raw = ""
        while hasCharacters, peek() != "]" {
            raw.append(nextCharacter())
        }
        guard hasCharacters, nextCharacter() == "]" else {
            throw ParseError(code: .characterNotFound, message: "Expected ] after matrix alignment")
        }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let align: MathAtom.Table.ColumnAlignment
        switch trimmed {
        case "l": align = .left
        case "r": align = .right
        case "c", "": align = .center
        default:
            throw ParseError(code: .invalidEnvironment, message: "Invalid matrix alignment [\(trimmed)]")
        }
        // Column count filled in later by finalize; provide a single alignment to broadcast.
        _ = columnsHint
        return TableEnvironment.ColumnSpec(alignments: [align], vlines: [0, 0])
    }

    mutating func readCommandName() -> String {
        guard hasCharacters else { return "" }
        let first = nextCharacter()
        if !first.isLetter {
            return String(first)
        }
        var name = String(first)
        while let ch = peek(), ch.isLetter {
            name.append(nextCharacter())
        }
        if peek() == "*" {
            name.append(nextCharacter())
        }
        return name
    }

    mutating func readArgument(allowSpaces: Bool = false) throws -> MathList {
        let previous = spacesAllowed
        if allowSpaces { spacesAllowed = true }
        defer { spacesAllowed = previous }

        skipSpaces()
        guard hasCharacters else {
            throw ParseError(code: .unexpectedEnd, message: "Missing argument")
        }
        if peek() == "{" {
            _ = nextCharacter()
            let list = try buildInternal(stop: .character("}"))
            guard hasCharacters, nextCharacter() == "}" else {
                throw ParseError(code: .mismatchedBraces, message: "Missing } for argument")
            }
            return list
        }
        var list = MathList()
        var prev: MathAtom?
        try appendOneAtom(into: &list, prev: &prev)
        return list
    }

    mutating func readDelimiter() throws -> String {
        skipSpaces()
        guard hasCharacters else {
            throw ParseError(code: .missingDelimiter, message: "Missing delimiter")
        }
        if peek() == "\\" {
            _ = nextCharacter()
            let name = readCommandName()
            guard AtomFactory.delimiters[name] != nil else {
                throw ParseError(code: .invalidDelimiter, message: "Invalid delimiter \\\(name)")
            }
            return name
        }
        let name = String(nextCharacter())
        guard AtomFactory.delimiters[name] != nil else {
            throw ParseError(code: .invalidDelimiter, message: "Invalid delimiter \(name)")
        }
        return name
    }

    mutating func readBracedName() throws -> String {
        skipSpaces()
        guard peek() == "{" else {
            throw ParseError(code: .missingEnvironment, message: "Expected {name}")
        }
        _ = nextCharacter()
        var name = ""
        while let ch = peek(), ch != "}" {
            name.append(nextCharacter())
        }
        guard hasCharacters, nextCharacter() == "}" else {
            throw ParseError(code: .missingEnvironment, message: "Missing } after name")
        }
        return name
    }

    /// Reads `\color{red}` / `\color{#cc0000}` brace argument.
    mutating func readColor() throws -> String {
        skipSpaces()
        guard peek() == "{" else {
            throw ParseError(code: .characterNotFound, message: "Missing { for color")
        }
        _ = nextCharacter()
        skipSpaces()
        var name = ""
        while let ch = peek(), ch != "}" {
            if ch == "#" || ch.isLetter || ch.isNumber {
                name.append(nextCharacter())
            } else if ch == " " || ch == "\t" {
                _ = nextCharacter()
            } else {
                break
            }
        }
        guard hasCharacters, nextCharacter() == "}" else {
            throw ParseError(code: .mismatchedBraces, message: "Missing } after color")
        }
        return name
    }
}
