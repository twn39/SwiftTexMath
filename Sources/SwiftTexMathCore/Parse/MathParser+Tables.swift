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
        let allowsHLine = environment == "array"

        while true {
            try consumeHLines(into: &hlines, at: rows.count, allowed: allowsHLine)
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

        return try TableEnvironment.finalize(
            environment: environment,
            rows: rows,
            columnSpec: columnSpec,
            hlines: allowsHLine ? Array(hlines.prefix(rows.count + 1)) : []
        )
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

    /// Reads `{c|cr}` after `\begin{array}`.
    mutating func readColumnSpec() throws -> TableEnvironment.ColumnSpec {
        let raw = try readBracedName()
        return try TableEnvironment.parseColumnSpec(raw)
    }
}
