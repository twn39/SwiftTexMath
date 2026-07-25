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
        let columnCount = max(
            cells.enumerated()
                .filter { !table.fullWidthRows.contains($0.offset) }
                .map(\.element.count).max() ?? 0,
            table.alignments.count
        )
        guard columnCount > 0 || !cells.isEmpty else {
            return .list(DisplayList())
        }
        let effectiveColumns = max(columnCount, 1)

        var columnWidths = Array(repeating: CGFloat(0), count: effectiveColumns)
        var rowAscent = Array(repeating: CGFloat(0), count: cells.count)
        var rowDescent = Array(repeating: CGFloat(0), count: cells.count)

        for (r, row) in cells.enumerated() {
            if table.fullWidthRows.contains(r) {
                // Full-width rows (intertext) only affect row height, not column metrics.
                if let first = row.first {
                    rowAscent[r] = max(rowAscent[r], first.ascent)
                    rowDescent[r] = max(rowDescent[r], first.descent)
                }
                continue
            }
            for (c, cell) in row.enumerated() where c < effectiveColumns {
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

        let colCount = effectiveColumns

        var vlines = table.vlines
        if vlines.count < colCount + 1 {
            vlines.append(contentsOf: Array(repeating: 0, count: colCount + 1 - vlines.count))
        } else if vlines.count > colCount + 1 {
            vlines = Array(vlines.prefix(colCount + 1))
        }

        var inserts = table.columnInserts
        if inserts.count < colCount + 1 {
            inserts.append(contentsOf: Array(repeating: MathList?.none, count: colCount + 1 - inserts.count))
        } else if inserts.count > colCount + 1 {
            inserts = Array(inserts.prefix(colCount + 1))
        }

        // Typeset @{…} inserts once; empty lists suppress the default gap.
        var insertDisplays: [DisplayList?] = Array(repeating: nil, count: colCount + 1)
        for b in 0...colCount {
            if let list = inserts[b] {
                let display = typeset(list, cellEnv)
                insertDisplays[b] = display
                for r in 0..<rowAscent.count where !table.fullWidthRows.contains(r) {
                    rowAscent[r] = max(rowAscent[r], display.ascent)
                    rowDescent[r] = max(rowDescent[r], display.descent)
                }
            }
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

        func boundaryExtraWidth(_ boundary: Int) -> CGFloat {
            if boundary < insertDisplays.count, let display = insertDisplays[boundary] {
                return display.width
            }
            // Default inter-column gap only between columns (boundaries 1..<colCount).
            if boundary > 0, boundary < colCount {
                return columnGap
            }
            return 0
        }

        // Widen columns so full-width intertext rows fit.
        var intertextMaxWidth: CGFloat = 0
        for r in table.fullWidthRows where r < cells.count {
            intertextMaxWidth = max(intertextMaxWidth, cells[r].first?.width ?? 0)
        }

        var contentWidth =
            columnWidths.reduce(0, +)
            + (0...colCount).reduce(CGFloat(0)) {
                $0 + vlineBandWidth(vlines[$1]) + boundaryExtraWidth($1)
            }
        if intertextMaxWidth > contentWidth {
            let extra = intertextMaxWidth - contentWidth
            columnWidths[colCount - 1] += extra
            contentWidth = intertextMaxWidth
        }

        let hlineHeight = hlines.reduce(CGFloat(0)) { $0 + hlineBandHeight($1) }
        let totalHeight = zip(rowAscent, rowDescent).map(+).reduce(0, +)
            + CGFloat(max(cells.count - 1, 0)) * rowGap
            + hlineHeight
        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics
        let axis = styleMetrics.axisHeight
        let totalAscent = totalHeight / 2 + axis
        let totalDescent = totalHeight / 2 - axis

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

        func appendVLines(_ count: Int, x: inout CGFloat) {
            guard count > 0 else { return }
            for i in 0..<count {
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

        func appendInsert(_ boundary: Int, x: inout CGFloat, rowY: CGFloat) {
            guard let display = insertDisplays[boundary] else { return }
            var placed = display
            placed.position = CGPoint(x: x, y: rowY)
            children.append(.list(placed))
            x += placed.width
        }

        for (r, row) in cells.enumerated() {
            appendHLines(hlines[r], at: &y)
            y -= rowAscent[r]
            var x: CGFloat = 0

            if table.fullWidthRows.contains(r), let first = row.first {
                // Span the full table width; left-align the text block.
                var placed = first
                placed.position = CGPoint(x: 0, y: y)
                children.append(.list(placed))
            } else {
                for c in 0..<colCount {
                    appendVLines(vlines[c], x: &x)
                    if insertDisplays[c] != nil {
                        appendInsert(c, x: &x, rowY: y)
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

                    // Default gap after the cell, unless the next boundary has an `@{…}` insert
                    // (that insert is emitted at the start of the next column and replaces the gap).
                    if c < colCount - 1 {
                        if insertDisplays[c + 1] == nil {
                            x += columnGap
                        }
                    }
                }

                appendVLines(vlines[colCount], x: &x)
                appendInsert(colCount, x: &x, rowY: y)
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
