import Foundation

/// Hand-written recursive-descent LaTeX math parser.
public struct MathParser: Sendable {
    var string: String
    var index: String.Index
    var spacesAllowed = false

    public init(_ latex: String) {
        self.string = Self.stripMathDelimiters(latex)
        self.index = self.string.startIndex
    }

    public static func parse(_ latex: String) throws -> MathList {
        var parser = MathParser(latex)
        let list = try parser.buildInternal(stop: .eof)
        parser.skipSpaces()
        if parser.hasCharacters {
            throw ParseError(code: .mismatchedBraces, message: "Unused characters after parse")
        }
        return list
    }

    enum Stop {
        case eof
        case character(Character)
        case rightCommand
        case tableCell
        /// Like `tableCell`, but also stops before a closing `}` (for `\substack{…}`).
        case substackCell
    }

    // MARK: - Delimiters

    private static func stripMathDelimiters(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("$$"), s.hasSuffix("$$"), s.count >= 4 {
            s = String(s.dropFirst(2).dropLast(2))
        } else if s.hasPrefix("$"), s.hasSuffix("$"), s.count >= 2 {
            s = String(s.dropFirst().dropLast())
        } else if s.hasPrefix("\\["), s.hasSuffix("\\]") {
            s = String(s.dropFirst(2).dropLast(2))
        } else if s.hasPrefix("\\("), s.hasSuffix("\\)") {
            s = String(s.dropFirst(2).dropLast(2))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Scanner

    var hasCharacters: Bool { index < string.endIndex }

    mutating func nextCharacter() -> Character {
        let ch = string[index]
        index = string.index(after: index)
        return ch
    }

    mutating func unlook() {
        if index > string.startIndex {
            index = string.index(before: index)
        }
    }

    func peek() -> Character? {
        guard hasCharacters else { return nil }
        return string[index]
    }

    mutating func skipSpaces() {
        while let ch = peek(), ch == " " || ch == "\n" || ch == "\t" || ch == "\r" {
            _ = nextCharacter()
        }
    }

    // MARK: - Core RD

    mutating func buildInternal(stop: Stop) throws -> MathList {
        var list = MathList()
        var prev: MathAtom?

        while hasCharacters {
            switch stop {
            case .character(let c) where peek() == c:
                return list
            case .tableCell where peek() == "&":
                return list
            case .substackCell where peek() == "&" || peek() == "}":
                return list
            case .eof, .character, .rightCommand, .tableCell, .substackCell:
                break
            }

            let ch = nextCharacter()

            if ch == "^" || ch == "_" {
                guard var base = prev, base.kind.allowsScripts else {
                    throw ParseError(code: .invalidCommand, message: "Script without base atom")
                }
                let script = try readScript()
                if ch == "^" {
                    guard base.superscript == nil else {
                        throw ParseError(code: .invalidCommand, message: "Double superscript")
                    }
                    base.superscript = script
                } else {
                    guard base.subscript == nil else {
                        throw ParseError(code: .invalidCommand, message: "Double subscript")
                    }
                    base.subscript = script
                }
                list.atoms[list.atoms.count - 1] = base
                prev = base
                continue
            }

            if ch == "{" {
                let inner = try buildInternal(stop: .character("}"))
                guard hasCharacters, nextCharacter() == "}" else {
                    throw ParseError(code: .mismatchedBraces, message: "Missing closing brace")
                }
                let atom: MathAtom
                if inner.atoms.count == 1, let only = inner.atoms.first,
                   only.superscript == nil, only.subscript == nil {
                    atom = only
                } else {
                    atom = MathAtom(kind: .inner, payload: .inner(.init(contents: inner)))
                }
                list.append(atom)
                prev = atom
                continue
            }

            if ch == "}" {
                if case .character("}") = stop {
                    unlook()
                    return list
                }
                if case .substackCell = stop {
                    unlook()
                    return list
                }
                throw ParseError(code: .mismatchedBraces, message: "Unexpected closing brace")
            }

            if ch == "&" {
                if case .tableCell = stop {
                    unlook()
                    return list
                }
                if case .substackCell = stop {
                    unlook()
                    return list
                }
                let atom = MathAtom.ordinary("&")
                list.append(atom)
                prev = atom
                continue
            }

            if ch == "\\" {
                unlook()
                if case .rightCommand = stop, startsWithRightCommand() {
                    return list
                }
                if case .tableCell = stop, startsWithRowBreakOrEnd() {
                    return list
                }
                if case .substackCell = stop, startsWithRowBreakOrEnd() {
                    return list
                }
                _ = nextCharacter()
                let outcome = try appendCommand(into: &list, prev: &prev, oneCharArgument: false)
                switch outcome {
                case .appended:
                    break
                case .infixFraction(let hasRule, let left, let right):
                    let denominator = try buildInternal(stop: stop)
                    let fraction = MathAtom(
                        kind: .fraction,
                        payload: .fraction(
                            .init(
                                numerator: list,
                                denominator: denominator,
                                hasRule: hasRule,
                                leftDelimiter: left,
                                rightDelimiter: right
                            )
                        )
                    )
                    return MathList(atoms: [fraction])
                }
                continue
            }

            if ch == " " || ch == "\n" || ch == "\t" || ch == "\r" {
                if spacesAllowed {
                    let atom = MathAtom.space(mu: 3)
                    list.append(atom)
                    prev = atom
                }
                continue
            }

            if let atom = AtomFactory.atom(forCharacter: ch) {
                list.append(atom)
                prev = atom
            }
        }

        if case .character(let c) = stop {
            throw ParseError(code: .mismatchedBraces, message: "Expected '\(c)' before end of input")
        }
        return list
    }

    private func startsWithRightCommand() -> Bool {
        var i = index
        guard i < string.endIndex, string[i] == "\\" else { return false }
        i = string.index(after: i)
        let name = peekCommandName(from: i)
        return name == "right"
    }

    private func startsWithRowBreakOrEnd() -> Bool {
        var i = index
        guard i < string.endIndex, string[i] == "\\" else { return false }
        i = string.index(after: i)
        let name = peekCommandName(from: i)
        return name == "\\" || name == "cr" || name == "end"
    }

    private func peekCommandName(from start: String.Index) -> String {
        guard start < string.endIndex else { return "" }
        var i = start
        let first = string[i]
        i = string.index(after: i)
        if !first.isLetter {
            return String(first)
        }
        var name = String(first)
        while i < string.endIndex, string[i].isLetter {
            name.append(string[i])
            i = string.index(after: i)
        }
        return name
    }

    private mutating func readScript() throws -> MathList {
        skipSpaces()
        guard hasCharacters else {
            throw ParseError(code: .unexpectedEnd, message: "Missing script")
        }
        if peek() == "{" {
            _ = nextCharacter()
            let list = try buildInternal(stop: .character("}"))
            guard hasCharacters, nextCharacter() == "}" else {
                throw ParseError(code: .mismatchedBraces, message: "Missing } after script")
            }
            return list
        }
        var list = MathList()
        var prev: MathAtom?
        try appendOneAtom(into: &list, prev: &prev)
        return list
    }

    mutating func appendOneAtom(into list: inout MathList, prev: inout MathAtom?) throws {
        guard hasCharacters else {
            throw ParseError(code: .unexpectedEnd, message: "Expected atom")
        }
        let ch = nextCharacter()
        if ch == "{" {
            let inner = try buildInternal(stop: .character("}"))
            guard hasCharacters, nextCharacter() == "}" else {
                throw ParseError(code: .mismatchedBraces, message: "Missing }")
            }
            if inner.atoms.count == 1, let only = inner.atoms.first {
                list.append(only)
                prev = only
            } else {
                let atom = MathAtom(kind: .inner, payload: .inner(.init(contents: inner)))
                list.append(atom)
                prev = atom
            }
            return
        }
        if ch == "\\" {
            try appendCommand(into: &list, prev: &prev, oneCharArgument: true)
            return
        }
        guard let atom = AtomFactory.atom(forCharacter: ch) else {
            throw ParseError(code: .characterNotFound, message: "Unexpected character \(ch)")
        }
        list.append(atom)
        prev = atom
    }

    enum AppendOutcome {
        case appended
        case infixFraction(hasRule: Bool, leftDelimiter: String, rightDelimiter: String)
    }

    @discardableResult
    mutating func appendCommand(
        into list: inout MathList,
        prev: inout MathAtom?,
        oneCharArgument: Bool = false
    ) throws -> AppendOutcome {
        let command = readCommandName()
        guard !command.isEmpty else {
            throw ParseError(code: .invalidCommand, message: "Missing command name")
        }

        switch try CommandHandlers.dispatch(
            command,
            parser: &self,
            list: &list,
            prev: &prev,
            oneCharArgument: oneCharArgument
        ) {
        case .handled:
            return .appended
        case .infixFraction(let hasRule, let left, let right):
            return .infixFraction(hasRule: hasRule, leftDelimiter: left, rightDelimiter: right)
        case .notHandled:
            break
        }

        if let accentNucleus = AtomFactory.accents[command] {
            let base = try readArgument()
            let atom = MathAtom(
                kind: .accent,
                nucleus: accentNucleus,
                payload: .accent(.init(accent: accentNucleus, base: base))
            )
            list.append(atom)
            prev = atom
            return .appended
        }

        guard let atom = AtomFactory.atom(forCommand: command) else {
            throw ParseError(code: .invalidCommand, message: "Unknown command \\\(command)")
        }
        list.append(atom)
        prev = atom
        return .appended
    }

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
        return TableEnvironment.ColumnSpec(alignments: [align], vlines: [0, 0])
    }

    mutating func parseSubstack() throws -> MathAtom.Table {
        skipSpaces()
        guard peek() == "{" else {
            throw ParseError(code: .mismatchedBraces, message: "\\substack expects a braced argument")
        }
        _ = nextCharacter()
        var rows: [[MathList]] = []
        var currentRow: [MathList] = []
        while true {
            let cell = try buildInternal(stop: .substackCell)
            currentRow.append(cell)
            skipSpaces()
            if peek() == "&" {
                _ = nextCharacter()
                continue
            }
            if peek() == "}" {
                _ = nextCharacter()
                rows.append(currentRow)
                break
            }
            if startsWithRowBreakOrEnd() {
                _ = nextCharacter() // \
                _ = readCommandName()
                rows.append(currentRow)
                currentRow = []
                continue
            }
            throw ParseError(code: .mismatchedBraces, message: "Unterminated \\substack")
        }
        if rows.isEmpty {
            rows = [[MathList()]]
        }
        return MathAtom.Table(
            environment: "substack",
            rows: rows,
            alignments: Array(repeating: .center, count: rows.map(\.count).max() ?? 1),
            interColumnSpacing: 0,
            interRowAdditionalSpacing: 0
        )
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

    mutating func parseTable(
        environment: String,
        columnSpec: TableEnvironment.ColumnSpec? = nil
    ) throws -> MathAtom.Table {
        var rows: [[MathList]] = []
        var row: [MathList] = []

        while true {
            skipSpaces()
            let cell = try buildInternal(stop: .tableCell)
            row.append(cell)
            skipSpaces()

            if peek() == "&" {
                _ = nextCharacter()
                continue
            }

            if peek() == "\\" {
                _ = nextCharacter()
                let cmd = readCommandName()
                if cmd == "\\" || cmd == "cr" {
                    rows.append(row)
                    row = []
                    continue
                }
                if cmd == "end" {
                    let name = try readBracedName()
                    guard name == environment else {
                        throw ParseError(
                            code: .invalidEnvironment,
                            message: "\\end{\(name)} does not match \\begin{\(environment)}"
                        )
                    }
                    if !row.isEmpty || rows.isEmpty {
                        rows.append(row)
                    }
                    break
                }
                throw ParseError(code: .invalidEnvironment, message: "Unexpected \\\(cmd) in table")
            }

            throw ParseError(code: .missingEnd, message: "Missing \\end{\(environment)}")
        }

        return try TableEnvironment.finalize(
            environment: environment,
            rows: rows,
            columnSpec: columnSpec
        )
    }

    /// Reads `{c|cr}` after `\begin{array}`.
    mutating func readColumnSpec() throws -> TableEnvironment.ColumnSpec {
        let raw = try readBracedName()
        return try TableEnvironment.parseColumnSpec(raw)
    }
}
