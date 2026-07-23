import Foundation

/// Hand-written recursive-descent LaTeX math parser.
public struct MathParser: Sendable {
    /// Maximum `buildInternal` nesting (groups / scripts / tables).
    /// Lower than iosMath's 150 to stay within typical Swift debug stack frames.
    static let maxRecursionDepth = 64

    var string: String
    var index: String.Index
    var spacesAllowed = false
    var recursionDepth = 0

    public init(_ latex: String) {
        let stripped = Self.stripMathDelimiters(latex)
        self.string = stripped.text
        self.index = self.string.startIndex
        self.detectedStyle = stripped.style
    }

    /// Style implied by surrounding `$…$` / `$$…$$` / `\(...\)` / `\[…\]` delimiters, if any.
    private(set) var detectedStyle: MathStyle?

    public static func parse(_ latex: String) throws -> MathList {
        var parser = MathParser(latex)
        var list = try parser.buildInternal(stop: .eof)
        parser.skipSpaces()
        if parser.hasCharacters {
            throw ParseError(code: .mismatchedBraces, message: "Unused characters after parse")
        }
        if let style = parser.detectedStyle {
            var atoms = list.atoms
            atoms.insert(MathAtom(kind: .style, payload: .style(style)), at: 0)
            list = MathList(atoms: atoms)
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

    private static func stripMathDelimiters(_ input: String) -> (text: String, style: MathStyle?) {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var style: MathStyle?
        if s.hasPrefix("$$"), s.hasSuffix("$$"), s.count >= 4 {
            s = String(s.dropFirst(2).dropLast(2))
            style = .display
        } else if s.hasPrefix("\\["), s.hasSuffix("\\]") {
            s = String(s.dropFirst(2).dropLast(2))
            style = .display
        } else if s.hasPrefix("$"), s.hasSuffix("$"), s.count >= 2 {
            s = String(s.dropFirst().dropLast())
            style = .text
        } else if s.hasPrefix("\\("), s.hasSuffix("\\)") {
            s = String(s.dropFirst(2).dropLast(2))
            style = .text
        }
        return (s.trimmingCharacters(in: .whitespacesAndNewlines), style)
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
        if recursionDepth >= Self.maxRecursionDepth {
            throw ParseError(code: .nestingTooDeep, message: "LaTeX nesting too deep")
        }
        recursionDepth += 1
        defer { recursionDepth -= 1 }

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

            // Prime shorthand: f' → f^{\prime}, f'' → f^{\prime\prime}, f'^2 → f^{\prime 2}
            if ch == "'" {
                try appendPrimes(into: &list, prev: &prev)
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

    /// Attach one or more primes as a superscript on `prev` (iosMath / TeX `'`).
    private mutating func appendPrimes(into list: inout MathList, prev: inout MathAtom?) throws {
        if prev == nil || prev?.superscript != nil || !(prev?.kind.allowsScripts ?? false) {
            let empty = MathAtom.ordinary("")
            list.append(empty)
            prev = empty
        }
        var primes = MathList(atoms: [MathAtom.ordinary("\u{2032}")])
        while peek() == "'" {
            _ = nextCharacter()
            primes.append(MathAtom.ordinary("\u{2032}"))
        }
        // Merge trailing ^: f'^2 → superscript = [′, 2]
        if peek() == "^" {
            _ = nextCharacter()
            let tail = try readScript()
            primes.atoms.append(contentsOf: tail.atoms)
        }
        var base = prev!
        base.superscript = primes
        list.atoms[list.atoms.count - 1] = base
        prev = base
    }

    func startsWithRightCommand() -> Bool {
        var i = index
        guard i < string.endIndex, string[i] == "\\" else { return false }
        i = string.index(after: i)
        let name = peekCommandName(from: i)
        return name == "right"
    }

    func startsWithRowBreakOrEnd() -> Bool {
        var i = index
        guard i < string.endIndex, string[i] == "\\" else { return false }
        i = string.index(after: i)
        let name = peekCommandName(from: i)
        return name == "\\" || name == "cr" || name == "end"
    }

    func peekCommandName(from start: String.Index) -> String {
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
        if ch == "'" {
            let atom = MathAtom.ordinary("\u{2032}")
            list.append(atom)
            prev = atom
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
}
