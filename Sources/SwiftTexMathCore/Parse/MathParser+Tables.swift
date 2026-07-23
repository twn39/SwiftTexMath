import Foundation

extension MathParser {
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

    mutating func parseTable(
        environment: String,
        columnSpec: TableEnvironment.ColumnSpec? = nil
    ) throws -> MathAtom.Table {
        var rows: [[MathList]] = []
        var row: [MathList] = []
        var hlines: [Int] = []
        var fullWidthRows: Set<Int> = []
        let allowsHLine = environment == "array"
        let baseEnv = environment.hasSuffix("*") ? String(environment.dropLast()) : environment
        let allowsIntertext = [
            "align", "aligned", "alignedat", "gather", "gathered", "eqnarray", "split",
        ].contains(baseEnv)

        while true {
            try consumeHLines(into: &hlines, at: rows.count, allowed: allowsHLine)

            // `\intertext{…}` at a row boundary (amsmath): full-width text row.
            if allowsIntertext, startsWithIntertext() {
                _ = nextCharacter() // \
                _ = readCommandName()
                let text = try readArgument(allowSpaces: true)
                let upright = MathAtom(
                    kind: .ordinary,
                    payload: .styled(.init(variant: .upright, contents: text))
                )
                fullWidthRows.insert(rows.count)
                rows.append([MathList(atoms: [upright])])
                row = []
                continue
            }

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
                if cmd == "hline" {
                    guard allowsHLine else {
                        throw ParseError(
                            code: .invalidCommand,
                            message: "\\hline is only valid inside an array environment"
                        )
                    }
                    while hlines.count <= rows.count { hlines.append(0) }
                    hlines[rows.count] += 1
                    continue
                }
                if cmd == "intertext" {
                    guard allowsIntertext else {
                        throw ParseError(
                            code: .invalidCommand,
                            message: "\\intertext is only valid in align/gather-style environments"
                        )
                    }
                    // Finish current row if it has content, then full-width text row.
                    let hasContent = row.contains { !$0.atoms.isEmpty }
                    if hasContent {
                        rows.append(row)
                        row = []
                    } else {
                        row = []
                    }
                    let text = try readArgument(allowSpaces: true)
                    let upright = MathAtom(
                        kind: .ordinary,
                        payload: .styled(.init(variant: .upright, contents: text))
                    )
                    fullWidthRows.insert(rows.count)
                    rows.append([MathList(atoms: [upright])])
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
                    // Discard a trailing empty row created by `\\` before `\hline`/`\end`.
                    let hasContent = row.contains { !$0.atoms.isEmpty }
                    if hasContent || rows.isEmpty {
                        rows.append(row)
                    }
                    break
                }
                throw ParseError(code: .invalidEnvironment, message: "Unexpected \\\(cmd) in table")
            }

            throw ParseError(code: .missingEnd, message: "Missing \\end{\(environment)}")
        }

        while hlines.count < rows.count + 1 {
            hlines.append(0)
        }

        var table = try TableEnvironment.finalize(
            environment: environment,
            rows: rows,
            columnSpec: columnSpec,
            hlines: allowsHLine ? Array(hlines.prefix(rows.count + 1)) : []
        )
        table.fullWidthRows = fullWidthRows
        return table
    }

    func startsWithIntertext() -> Bool {
        var i = index
        guard i < string.endIndex, string[i] == "\\" else { return false }
        i = string.index(after: i)
        return peekCommandName(from: i) == "intertext"
    }

    /// Consume consecutive `\hline` markers at a row boundary.
    mutating func consumeHLines(into hlines: inout [Int], at boundary: Int, allowed: Bool) throws {
        while true {
            skipSpaces()
            guard peek() == "\\" else { return }
            let saved = index
            _ = nextCharacter()
            let cmd = readCommandName()
            if cmd == "hline" {
                guard allowed else {
                    throw ParseError(
                        code: .invalidCommand,
                        message: "\\hline is only valid inside an array environment"
                    )
                }
                while hlines.count <= boundary { hlines.append(0) }
                hlines[boundary] += 1
                continue
            }
            index = saved
            return
        }
    }

    /// Reads `{c|cr}` / `{c@{\quad}c}` after `\begin{array}` (nested braces allowed).
    mutating func readColumnSpec() throws -> TableEnvironment.ColumnSpec {
        skipSpaces()
        guard peek() == "{" else {
            throw ParseError(code: .missingEnvironment, message: "Expected {column spec}")
        }
        _ = nextCharacter()
        var raw = ""
        var depth = 1
        while hasCharacters, depth > 0 {
            let ch = nextCharacter()
            if ch == "{" {
                depth += 1
                raw.append(ch)
            } else if ch == "}" {
                depth -= 1
                if depth > 0 {
                    raw.append(ch)
                }
            } else {
                raw.append(ch)
            }
        }
        guard depth == 0 else {
            throw ParseError(code: .missingEnvironment, message: "Missing } after column specification")
        }
        return try TableEnvironment.parseColumnSpec(raw)
    }
}
