import CoreGraphics
import Foundation

enum TableLayout {
    static func make(
        _ table: MathAtom.Table,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared,
        typeset: (MathList, MathEnvironment) -> DisplayList,
        equationCounter: EquationCounter? = nil,
        labelMap: EquationLabelMap? = nil
    ) -> DisplayNode {
        let hoistTags = Typesetter.tableEnvironmentHoistsTags(table.environment)
        let wantsNumbers =
            Typesetter.tableEnvironmentAutoNumbers(table.environment)
            && (
                env.numberEquations
                || Typesetter.tableEnvironmentForcesNumbering(table.environment)
            )
            && (env.style == .display || Typesetter.tableEnvironmentForcesNumbering(table.environment))
        let tableNumbers = wantsNumbers && equationCounter != nil

        var cellEnv: MathEnvironment
        switch table.environment {
        case "smallmatrix", "substack":
            cellEnv = env.with(style: .script)
        default:
            cellEnv = env
        }
        // Row-level tags/numbers own labels; keep cell layout free of auto `(n)`.
        if tableNumbers || hoistTags {
            cellEnv.numberEquations = false
        }

        // Strip `\tag` / `\notag` from cells so labels can sit at the row margin.
        let rowPolicies: [(suppress: Bool, explicitTag: MathAtom.Tag?)] = table.rows.map {
            Typesetter.rowTagPolicy(cells: $0)
        }
        let bodyRows: [[MathList]] = table.rows.map { row in
            guard hoistTags else { return row }
            return row.map { Typesetter.strippingTags(from: $0) }
        }
        let cells = bodyRows.map { row in row.map { typeset($0, cellEnv) } }
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
        let rowGap = max(metrics.overbarVerticalGap, (12 + 12 * table.interRowAdditionalSpacing) * metrics.mathUnit)
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

        // Widen columns so full-width intertext rows fit.
        var intertextMaxWidth: CGFloat = 0
        for r in table.fullWidthRows where r < cells.count {
            intertextMaxWidth = max(intertextMaxWidth, cells[r].first?.width ?? 0)
        }

        var contentWidth =
            columnWidths.reduce(0, +)
            + (0...colCount).reduce(CGFloat(0)) {
                $0 + vlineBandWidth(vlines[$1], ruleThickness: ruleThickness, vlineGap: vlineGap)
                    + boundaryExtraWidth($1, insertDisplays: insertDisplays, colCount: colCount, columnGap: columnGap)
            }
        if intertextMaxWidth > contentWidth {
            let extra = intertextMaxWidth - contentWidth
            columnWidths[colCount - 1] += extra
            contentWidth = intertextMaxWidth
        }

        let styleFont = MathFont(name: env.font.name, size: metrics.styleFontSize(baseSize: env.font.size, style: env.style))
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics
        let tagGap = styleMetrics.mathUnit * 18
        let tagTargetWidth = env.maxWidth > 0 ? max(env.maxWidth, contentWidth) : contentWidth

        // Pre-build row tags (explicit `\tag` or auto `(n)`) so height/width include them.
        var rowTags: [DisplayList?] = Array(repeating: nil, count: cells.count)
        var tagExtraWidth: CGFloat = 0
        if hoistTags {
            for r in 0..<cells.count where !table.fullWidthRows.contains(r) {
                let policy = r < rowPolicies.count
                    ? rowPolicies[r]
                    : (suppress: false, explicitTag: nil)
                let tagSpec: MathAtom.Tag?
                var bareMarker: String?
                if let explicit = policy.explicitTag {
                    tagSpec = explicit
                    bareMarker = EquationNumbering.flattenList(explicit.contents)
                } else if policy.suppress {
                    tagSpec = nil
                } else if tableNumbers, let counter = equationCounter {
                    let n = counter.take()
                    bareMarker = String(n)
                    tagSpec = MathAtom.Tag(
                        contents: Typesetter.numberList(n),
                        parenthesize: true
                    )
                } else {
                    tagSpec = nil
                }
                if let bare = bareMarker, !bare.isEmpty, let labelMap, r < table.rows.count {
                    for name in Typesetter.rowLabelNames(cells: table.rows[r]) {
                        labelMap.bind(name, to: bare)
                    }
                }
                guard let tagSpec else { continue }
                let tagDisplay = Typesetter.makeTagDisplay(tagSpec, env: cellEnv, typeset: typeset)
                rowTags[r] = tagDisplay
                rowAscent[r] = max(rowAscent[r], tagDisplay.ascent)
                rowDescent[r] = max(rowDescent[r], tagDisplay.descent)
                let tagX = max(contentWidth + tagGap, tagTargetWidth - tagDisplay.width)
                tagExtraWidth = max(tagExtraWidth, tagX + tagDisplay.width - contentWidth)
            }
        }

        let hlineHeight = hlines.reduce(CGFloat(0)) {
            $0 + hlineBandHeight($1, ruleThickness: ruleThickness, vlineGap: vlineGap, hlinePad: hlinePad)
        }
        let totalHeight = zip(rowAscent, rowDescent).map(+).reduce(0, +)
            + CGFloat(max(cells.count - 1, 0)) * rowGap
            + hlineHeight
        let axis = styleMetrics.axisHeight
        let totalAscent = totalHeight / 2 + axis
        let totalDescent = totalHeight / 2 - axis

        var children: [DisplayNode] = []
        var y = totalAscent

        for (r, row) in cells.enumerated() {
            y = appendHLines(
                hlines[r],
                startingAt: y,
                ruleThickness: ruleThickness,
                vlineGap: vlineGap,
                hlinePad: hlinePad,
                contentWidth: contentWidth,
                children: &children
            )
            y -= rowAscent[r]
            var x: CGFloat = 0

            if table.fullWidthRows.contains(r), let first = row.first {
                // Span the full table width; left-align the text block.
                var placed = first
                placed.position = CGPoint(x: 0, y: y)
                children.append(.list(placed))
            } else {
                for c in 0..<colCount {
                    x = appendVLines(
                        vlines[c],
                        startingAt: x,
                        ruleThickness: ruleThickness,
                        vlineGap: vlineGap,
                        totalAscent: totalAscent,
                        totalDescent: totalDescent,
                        children: &children
                    )
                    if insertDisplays[c] != nil {
                        x = appendInsert(
                            c,
                            startingAt: x,
                            rowY: y,
                            insertDisplays: insertDisplays,
                            children: &children
                        )
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

                x = appendVLines(
                    vlines[colCount],
                    startingAt: x,
                    ruleThickness: ruleThickness,
                    vlineGap: vlineGap,
                    totalAscent: totalAscent,
                    totalDescent: totalDescent,
                    children: &children
                )
                x = appendInsert(
                    colCount,
                    startingAt: x,
                    rowY: y,
                    insertDisplays: insertDisplays,
                    children: &children
                )

                // Flush-right row label (`\tag` / auto number).
                if var tagDisplay = rowTags[r] {
                    let tagX = max(contentWidth + tagGap, tagTargetWidth - tagDisplay.width)
                    tagDisplay.position = CGPoint(x: tagX, y: y)
                    children.append(.list(tagDisplay))
                }
            }

            y -= rowDescent[r]
            if r < cells.count - 1 {
                y -= rowGap
            }
        }

        y = appendHLines(
            hlines[cells.count],
            startingAt: y,
            ruleThickness: ruleThickness,
            vlineGap: vlineGap,
            hlinePad: hlinePad,
            contentWidth: contentWidth,
            children: &children
        )

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

        let finalContentWidth = contentWidth + tagExtraWidth

        if leftFence.isEmpty, rightFence.isEmpty {
            return .list(
                DisplayList(
                    ascent: totalAscent,
                    descent: totalDescent,
                    width: finalContentWidth,
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

        if !leftFence.isEmpty {
            appendFence(
                leftFence,
                glyphHeight: glyphHeight,
                styleFont: styleFont,
                styleMetrics: styleMetrics,
                x: &x,
                ascent: &ascent,
                descent: &descent,
                wrapped: &wrapped
            )
            x += padding
        }
        for var child in children {
            var pos = child.position
            pos.x += x
            child.position = pos
            wrapped.append(child)
        }
        x += finalContentWidth
        if !rightFence.isEmpty {
            x += padding
            appendFence(
                rightFence,
                glyphHeight: glyphHeight,
                styleFont: styleFont,
                styleMetrics: styleMetrics,
                x: &x,
                ascent: &ascent,
                descent: &descent,
                wrapped: &wrapped
            )
        }

        return .list(DisplayList(ascent: ascent, descent: descent, width: x, children: wrapped))
    }

    private static func vlineBandWidth(_ count: Int, ruleThickness: CGFloat, vlineGap: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * ruleThickness + CGFloat(max(count - 1, 0)) * vlineGap
    }

    private static func hlineBandHeight(_ count: Int, ruleThickness: CGFloat, vlineGap: CGFloat, hlinePad: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count) * ruleThickness
            + CGFloat(max(count - 1, 0)) * vlineGap
            + 2 * hlinePad
    }

    private static func boundaryExtraWidth(_ boundary: Int, insertDisplays: [DisplayList?], colCount: Int, columnGap: CGFloat) -> CGFloat {
        if boundary < insertDisplays.count, let display = insertDisplays[boundary] {
            return display.width
        }
        if boundary > 0, boundary < colCount {
            return columnGap
        }
        return 0
    }

    private static func appendHLines(
        _ count: Int,
        startingAt yStart: CGFloat,
        ruleThickness: CGFloat,
        vlineGap: CGFloat,
        hlinePad: CGFloat,
        contentWidth: CGFloat,
        children: inout [DisplayNode]
    ) -> CGFloat {
        var yCenter = yStart
        guard count > 0 else { return yCenter }
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
        return yCenter
    }

    private static func appendVLines(
        _ count: Int,
        startingAt xStart: CGFloat,
        ruleThickness: CGFloat,
        vlineGap: CGFloat,
        totalAscent: CGFloat,
        totalDescent: CGFloat,
        children: inout [DisplayNode]
    ) -> CGFloat {
        var x = xStart
        guard count > 0 else { return x }
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
        return x
    }

    private static func appendInsert(
        _ boundary: Int,
        startingAt xStart: CGFloat,
        rowY: CGFloat,
        insertDisplays: [DisplayList?],
        children: inout [DisplayNode]
    ) -> CGFloat {
        var x = xStart
        guard let display = insertDisplays[boundary] else { return x }
        var placed = display
        placed.position = CGPoint(x: x, y: rowY)
        children.append(.list(placed))
        x += placed.width
        return x
    }

    private static func appendFence(
        _ nucleus: String,
        glyphHeight: CGFloat,
        styleFont: MathFont,
        styleMetrics: FontMetrics,
        x: inout CGFloat,
        ascent: inout CGFloat,
        descent: inout CGFloat,
        wrapped: inout [DisplayNode]
    ) {
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
}
