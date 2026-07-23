import Foundation

/// Parses and applies LaTeX table / matrix environment defaults.
enum TableEnvironment {
    struct ColumnSpec {
        var alignments: [MathAtom.Table.ColumnAlignment]
        var vlines: [Int] // length = alignments.count + 1
    }

    /// Matrix environments that get stretchy fences in layout.
    static let matrixFences: [String: (String, String)] = [
        "pmatrix": ("(", ")"),
        "bmatrix": ("[", "]"),
        "vmatrix": ("|", "|"),
        "Vmatrix": ("\u{2016}", "\u{2016}"),
        "Bmatrix": ("{", "}"),
        "matrix": ("", ""),
        "smallmatrix": ("", ""),
        "pmatrix*": ("(", ")"),
        "bmatrix*": ("[", "]"),
        "vmatrix*": ("|", "|"),
        "Vmatrix*": ("\u{2016}", "\u{2016}"),
        "Bmatrix*": ("{", "}"),
        "matrix*": ("", ""),
    ]

    static func alignedAtSpec(pairs: Int) -> ColumnSpec {
        var alignments: [MathAtom.Table.ColumnAlignment] = []
        for _ in 0..<pairs {
            alignments.append(.right)
            alignments.append(.left)
        }
        let vlines = Array(repeating: 0, count: alignments.count + 1)
        return ColumnSpec(alignments: alignments, vlines: vlines)
    }

    static func finalize(
        environment: String,
        rows: [[MathList]],
        columnSpec: ColumnSpec?,
        hlines: [Int] = []
    ) throws -> MathAtom.Table {
        let columnCount = rows.map(\.count).max() ?? 0
        let starred = environment.hasSuffix("*")
        let baseName = starred ? String(environment.dropLast()) : environment

        func withHLines(_ table: MathAtom.Table) -> MathAtom.Table {
            guard !hlines.isEmpty else { return table }
            var copy = table
            var lines = hlines
            while lines.count < rows.count + 1 { lines.append(0) }
            copy.hlines = Array(lines.prefix(rows.count + 1))
            return copy
        }

        if let columnSpec, baseName == "array" {
            return withHLines(
                MathAtom.Table(
                    environment: environment,
                    rows: rows,
                    alignments: padAlignments(columnSpec.alignments, to: columnCount),
                    interColumnSpacing: 18,
                    interRowAdditionalSpacing: 0,
                    vlines: padVlines(columnSpec.vlines, columns: max(columnCount, columnSpec.alignments.count)),
                    hlines: []
                )
            )
        }

        if let columnSpec, baseName == "alignedat" {
            return MathAtom.Table(
                environment: "alignedat",
                rows: rows,
                alignments: padAlignments(columnSpec.alignments, to: columnCount),
                interColumnSpacing: 0,
                interRowAdditionalSpacing: 1,
                vlines: []
            )
        }

        // Starred matrices: optional [l|c|r] broadcasts to all columns.
        if starred, matrixFences[environment] != nil || matrixFences[baseName] != nil {
            let align = columnSpec?.alignments.first ?? .center
            return MathAtom.Table(
                environment: baseName,
                rows: rows,
                alignments: Array(repeating: align, count: columnCount),
                interColumnSpacing: baseName == "smallmatrix" ? 6 : 18,
                interRowAdditionalSpacing: 0
            )
        }

        switch baseName {
        case "array":
            throw ParseError(
                code: .invalidEnvironment,
                message: "array requires a column specification like {c|cr}"
            )

        case "pmatrix", "bmatrix", "vmatrix", "Vmatrix", "Bmatrix", "matrix":
            return MathAtom.Table(
                environment: baseName,
                rows: rows,
                alignments: Array(repeating: .center, count: columnCount),
                interColumnSpacing: 18,
                interRowAdditionalSpacing: 0
            )

        case "smallmatrix":
            return MathAtom.Table(
                environment: baseName,
                rows: rows,
                alignments: Array(repeating: .center, count: columnCount),
                interColumnSpacing: 6,
                interRowAdditionalSpacing: 0
            )

        case "cases":
            guard columnCount == 1 || columnCount == 2 else {
                throw ParseError(
                    code: .invalidNumberOfColumns,
                    message: "cases environment can have 1 or 2 columns"
                )
            }
            return MathAtom.Table(
                environment: baseName,
                rows: rows,
                alignments: Array(repeating: .left, count: columnCount),
                interColumnSpacing: 18,
                interRowAdditionalSpacing: 0
            )

        case "aligned", "eqalign", "split":
            if baseName == "split", columnCount > 2 {
                throw ParseError(
                    code: .invalidNumberOfColumns,
                    message: "split environment can have at most 2 columns"
                )
            }
            var alignments: [MathAtom.Table.ColumnAlignment] = []
            for i in 0..<columnCount {
                alignments.append(i % 2 == 0 ? .right : .left)
            }
            return MathAtom.Table(
                environment: baseName,
                rows: rows,
                alignments: alignments,
                interColumnSpacing: 0,
                interRowAdditionalSpacing: 1
            )

        case "alignedat":
            throw ParseError(
                code: .invalidEnvironment,
                message: "alignedat requires a column-pair count like {2}"
            )

        case "gather", "gathered", "displaylines":
            guard columnCount == 1 else {
                throw ParseError(
                    code: .invalidNumberOfColumns,
                    message: "\(baseName) environment can only have 1 column"
                )
            }
            return MathAtom.Table(
                environment: baseName,
                rows: rows,
                alignments: [.center],
                interColumnSpacing: 0,
                interRowAdditionalSpacing: 1
            )

        case "eqnarray":
            guard columnCount == 3 else {
                throw ParseError(
                    code: .invalidNumberOfColumns,
                    message: "eqnarray environment can only have 3 columns"
                )
            }
            return MathAtom.Table(
                environment: baseName,
                rows: rows,
                alignments: [.right, .center, .left],
                interColumnSpacing: 18,
                interRowAdditionalSpacing: 1
            )

        case "substack":
            return MathAtom.Table(
                environment: "substack",
                rows: rows,
                alignments: Array(repeating: .center, count: max(columnCount, 1)),
                interColumnSpacing: 0,
                interRowAdditionalSpacing: 0
            )

        default:
            throw ParseError(
                code: .invalidEnvironment,
                message: "Unknown environment \(environment)"
            )
        }
    }

    /// Parse `{c|cr}` / `{|l|c|r|}` style specs.
    static func parseColumnSpec(_ raw: String) throws -> ColumnSpec {
        var alignments: [MathAtom.Table.ColumnAlignment] = []
        var vlines: [Int] = [0]
        var index = raw.startIndex

        while index < raw.endIndex {
            let ch = raw[index]
            index = raw.index(after: index)
            switch ch {
            case "l":
                alignments.append(.left)
                vlines.append(0)
            case "c":
                alignments.append(.center)
                vlines.append(0)
            case "r":
                alignments.append(.right)
                vlines.append(0)
            case "|":
                if vlines.isEmpty {
                    vlines.append(1)
                } else {
                    vlines[vlines.count - 1] += 1
                }
            case " ", "\t", "\n":
                continue
            case "@":
                // Skip @{…} spacing inserts for now.
                if index < raw.endIndex, raw[index] == "{" {
                    index = raw.index(after: index)
                    var depth = 1
                    while index < raw.endIndex, depth > 0 {
                        let c = raw[index]
                        index = raw.index(after: index)
                        if c == "{" { depth += 1 }
                        if c == "}" { depth -= 1 }
                    }
                }
            default:
                throw ParseError(
                    code: .invalidEnvironment,
                    message: "Invalid array column spec character '\(ch)'"
                )
            }
        }

        guard !alignments.isEmpty else {
            throw ParseError(code: .invalidEnvironment, message: "Empty array column specification")
        }
        return ColumnSpec(alignments: alignments, vlines: vlines)
    }

    private static func padAlignments(
        _ alignments: [MathAtom.Table.ColumnAlignment],
        to count: Int
    ) -> [MathAtom.Table.ColumnAlignment] {
        let n = max(count, alignments.count)
        if alignments.count >= n { return Array(alignments.prefix(n)) }
        return alignments + Array(repeating: .center, count: n - alignments.count)
    }

    private static func padVlines(_ vlines: [Int], columns: Int) -> [Int] {
        var result = vlines
        let needed = columns + 1
        if result.count < needed {
            result.append(contentsOf: Array(repeating: 0, count: needed - result.count))
        }
        return Array(result.prefix(needed))
    }
}
