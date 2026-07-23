import CoreGraphics
import Foundation

enum TableLayout {
    static func make(
        _ table: MathAtom.Table,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        let cellEnv: MathEnvironment
        switch table.environment {
        case "smallmatrix", "substack":
            cellEnv = env.with(style: .script)
        default:
            cellEnv = env
        }
        let cells = table.rows.map { row in row.map { typeset($0, cellEnv) } }
        let columnCount = max(cells.map(\.count).max() ?? 0, table.alignments.count)
        guard columnCount > 0 else {
            return .list(DisplayList())
        }

        var columnWidths = Array(repeating: CGFloat(0), count: columnCount)
        var rowAscent = Array(repeating: CGFloat(0), count: cells.count)
        var rowDescent = Array(repeating: CGFloat(0), count: cells.count)

        for (r, row) in cells.enumerated() {
            for (c, cell) in row.enumerated() {
                columnWidths[c] = max(columnWidths[c], cell.width)
                rowAscent[r] = max(rowAscent[r], cell.ascent)
                rowDescent[r] = max(rowDescent[r], cell.descent)
            }
        }

        let columnGap = table.interColumnSpacing * metrics.mathUnit
        let rowGap = (12 + 12 * table.interRowAdditionalSpacing) * metrics.mathUnit
        let ruleThickness = max(metrics.fractionRuleThickness, 0.4)
        let vlineGap = metrics.mathUnit
        let hlinePad = metrics.mathUnit

        var vlines = table.vlines
        if vlines.count < columnCount + 1 {
            vlines.append(contentsOf: Array(repeating: 0, count: columnCount + 1 - vlines.count))
        } else if vlines.count > columnCount + 1 {
            vlines = Array(vlines.prefix(columnCount + 1))
        }

        var hlines = table.hlines
        while hlines.count < cells.count + 1 { hlines.append(0) }
        hlines = Array(hlines.prefix(cells.count + 1))

        func vlineBandWidth(_ count: Int) -> CGFloat {
            guard count > 0 else { return 0 }
            return CGFloat(count) * ruleThickness + CGFloat(max(count - 1, 0)) * vlineGap
        }

        func hlineBandHeight(_ count: Int) -> CGFloat {
            guard count > 0 else { return 0 }
            return CGFloat(count) * ruleThickness
                + CGFloat(max(count - 1, 0)) * vlineGap
                + 2 * hlinePad
        }

        let contentWidth =
            columnWidths.reduce(0, +)
            + CGFloat(max(columnCount - 1, 0)) * columnGap
            + (0...columnCount).reduce(CGFloat(0)) { $0 + vlineBandWidth(vlines[$1]) }

        let hlineHeight = hlines.reduce(CGFloat(0)) { $0 + hlineBandHeight($1) }
        let totalHeight = zip(rowAscent, rowDescent).map(+).reduce(0, +)
            + CGFloat(max(cells.count - 1, 0)) * rowGap
            + hlineHeight
        let totalAscent = totalHeight / 2
        let totalDescent = totalHeight / 2

        var children: [DisplayNode] = []
        var y = totalAscent

        func appendHLines(_ count: Int, at yCenter: inout CGFloat) {
            guard count > 0 else { return }
            yCenter -= hlinePad
            for i in 0..<count {
                if i > 0 { yCenter -= vlineGap }
                yCenter -= ruleThickness / 2
                children.append(
                    .rule(
                        RuleDisplay(
                            thickness: ruleThickness,
                            isVertical: false,
                            ascent: ruleThickness / 2,
                            descent: ruleThickness / 2,
                            width: contentWidth,
                            position: CGPoint(x: 0, y: yCenter)
                        )
                    )
                )
                yCenter -= ruleThickness / 2
            }
            yCenter -= hlinePad
        }

        for (r, row) in cells.enumerated() {
            appendHLines(hlines[r], at: &y)
            y -= rowAscent[r]
            var x: CGFloat = 0

            for c in 0..<columnCount {
                let before = vlines[c]
                if before > 0 {
                    for i in 0..<before {
                        if i > 0 { x += vlineGap }
                        children.append(
                            .rule(
                                RuleDisplay(
                                    thickness: ruleThickness,
                                    isVertical: true,
                                    ascent: totalAscent,
                                    descent: totalDescent,
                                    width: ruleThickness,
                                    position: CGPoint(x: x, y: 0)
                                )
                            )
                        )
                        x += ruleThickness
                    }
                }

                if c < row.count {
                    var placed = row[c]
                    let align = table.alignments.indices.contains(c) ? table.alignments[c] : .center
                    let cellX: CGFloat
                    switch align {
                    case .left: cellX = x
                    case .right: cellX = x + columnWidths[c] - placed.width
                    case .center: cellX = x + (columnWidths[c] - placed.width) / 2
                    }
                    placed.position = CGPoint(x: cellX, y: y)
                    children.append(.list(placed))
                }
                x += columnWidths[c]
                if c < columnCount - 1 {
                    x += columnGap
                }
            }

            let after = vlines[columnCount]
            if after > 0 {
                for i in 0..<after {
                    if i > 0 { x += vlineGap }
                    children.append(
                        .rule(
                            RuleDisplay(
                                thickness: ruleThickness,
                                isVertical: true,
                                ascent: totalAscent,
                                descent: totalDescent,
                                width: ruleThickness,
                                position: CGPoint(x: x, y: 0)
                            )
                        )
                    )
                    x += ruleThickness
                }
            }

            y -= rowDescent[r]
            if r < cells.count - 1 {
                y -= rowGap
            }
        }

        appendHLines(hlines[cells.count], at: &y)

        var leftFence = ""
        var rightFence = ""
        switch table.environment {
        case "pmatrix": leftFence = "("; rightFence = ")"
        case "bmatrix": leftFence = "["; rightFence = "]"
        case "vmatrix": leftFence = "|"; rightFence = "|"
        case "Vmatrix": leftFence = "\u{2016}"; rightFence = "\u{2016}"
        case "Bmatrix": leftFence = "{"; rightFence = "}"
        case "cases": leftFence = "{"; rightFence = ""
        default: break
        }

        if leftFence.isEmpty, rightFence.isEmpty {
            return .list(
                DisplayList(
                    ascent: totalAscent,
                    descent: totalDescent,
                    width: contentWidth,
                    children: children
                )
            )
        }

        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics
        let glyphHeight = totalAscent + totalDescent
        let padding = styleMetrics.mathUnit * 2

        var wrapped: [DisplayNode] = []
        var x: CGFloat = 0
        var ascent = totalAscent
        var descent = totalDescent

        func appendFence(_ nucleus: String) {
            guard !nucleus.isEmpty else { return }
            let sized = styleMetrics.sizedDelimiter(forNucleus: nucleus, height: glyphHeight)
            var glyph = GlyphRun.from(
                sized: sized,
                text: nucleus,
                font: styleFont,
                metrics: styleMetrics,
                centerOnAxis: true
            )
            glyph.position = CGPoint(x: x, y: 0)
            ascent = max(ascent, glyph.ascent - glyph.shiftDown)
            descent = max(descent, glyph.descent + glyph.shiftDown)
            wrapped.append(.glyphs(glyph))
            x += glyph.width
        }

        if !leftFence.isEmpty {
            appendFence(leftFence)
            x += padding
        }
        for var child in children {
            var pos = child.position
            pos.x += x
            child.position = pos
            wrapped.append(child)
        }
        x += contentWidth
        if !rightFence.isEmpty {
            x += padding
            appendFence(rightFence)
        }

        return .list(DisplayList(ascent: ascent, descent: descent, width: x, children: wrapped))
    }
}
