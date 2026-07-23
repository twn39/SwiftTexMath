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
        var rows: [MathList] = []
        while true {
            let row = try parser.buildInternal(stop: .lineBreak)
            rows.append(row)
            if parser.consumeLineBreak() {
                continue
            }
            break
        }
        parser.skipSpaces()
        if parser.hasCharacters {
            throw ParseError(code: .mismatchedBraces, message: "Unused characters after parse")
        }

        var list: MathList
        if rows.count <= 1 {
            list = rows.first ?? MathList()
        } else {
            // Top-level `\\` → single-column gathered table (tex2math / display multiline).
            let table = MathAtom.Table(
                environment: "gathered",
                rows: rows.map { [$0] },
                alignments: [.center],
                interColumnSpacing: 0,
                interRowAdditionalSpacing: 1
            )
            list = MathList(atoms: [MathAtom(kind: .table, payload: .table(table))])
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
        /// Stop before top-level `\\` / `\cr` (or at EOF).
        case lineBreak
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
            case .eof, .character, .rightCommand, .tableCell, .substackCell, .lineBreak:
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
                if case .lineBreak = stop, startsWithRowBreak() {
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

    func startsWithRowBreak() -> Bool {
        var i = index
        guard i < string.endIndex, string[i] == "\\" else { return false }
        i = string.index(after: i)
        let name = peekCommandName(from: i)
        return name == "\\" || name == "cr"
    }

    /// Consume a top-level `\\` or `\cr`. Returns `true` if a row break was present.
    mutating func consumeLineBreak() -> Bool {
        skipSpaces()
        guard startsWithRowBreak() else { return false }
        _ = nextCharacter() // '\'
        _ = readCommandName()
        return true
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
}
