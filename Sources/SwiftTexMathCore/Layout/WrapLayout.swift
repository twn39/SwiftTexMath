import CoreGraphics
import Foundation

/// maxWidth paragraph wrapping for math lists (separate from `LineLayout` over/under rules).
enum WrapLayout {
    struct PlacedAtom {
        var atom: MathAtom
        var node: DisplayNode
        var spacingBefore: CGFloat
    }

    static func typeset(
        _ list: MathList,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding,
        makeNode: (MathAtom, LayoutContext) -> DisplayNode
    ) -> DisplayList {
        let maxWidth = env.maxWidth
        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics

        var env = env
        var items: [PlacedAtom] = []
        var prevKind: AtomKind?
        var pendingTag: DisplayNode?

        for atom in list.atoms {
            if case .style(let style) = atom.payload {
                env.style = style
                continue
            }
            if case .space(let mu) = atom.payload {
                let width = mu * styleMetrics.mathUnit
                items.append(
                    PlacedAtom(
                        atom: atom,
                        node: .glyphs(
                            GlyphRun(
                                text: "",
                                font: styleFont,
                                ascent: 0,
                                descent: 0,
                                width: width
                            )
                        ),
                        spacingBefore: 0
                    )
                )
                prevKind = .ordinary
                continue
            }
            if atom.kind == .boundary { continue }

            // Defer tags to the last line (flush-right); do not participate in wrapping.
            if case .tag = atom.payload {
                var childEnv = env
                childEnv.maxWidth = 0
                pendingTag = makeNode(
                    atom,
                    LayoutContext(env: childEnv, metrics: styleMetrics, fonts: fonts)
                )
                continue
            }

            let spacing: CGFloat
            if let prev = prevKind {
                spacing = InterElementSpacing.space(
                    left: prev,
                    right: atom.kind,
                    style: env.style,
                    parameters: env.parameters,
                    mathUnit: styleMetrics.mathUnit
                )
            } else {
                spacing = 0
            }

            // Nested content wraps to the full paragraph width; remaining-width
            // reflow happens when the outer packer places the node on a line.
            var childEnv = env
            childEnv.maxWidth = max(0, maxWidth)
            let node = makeNode(
                atom,
                LayoutContext(env: childEnv, metrics: styleMetrics, fonts: fonts)
            )
            items.append(PlacedAtom(atom: atom, node: node, spacingBefore: spacing))
            prevKind = atom.kind
        }

        guard !items.isEmpty || pendingTag != nil else { return DisplayList() }
        if items.isEmpty, let tag = pendingTag {
            var placed = tag
            placed.position = CGPoint(x: max(0, maxWidth - tag.width), y: 0)
            return DisplayList(
                ascent: tag.ascent,
                descent: tag.descent,
                width: maxWidth > 0 ? maxWidth : tag.width,
                children: [placed]
            )
        }

        var lines: [[PlacedAtom]] = [[]]
        var lineWidth: CGFloat = 0

        for item in items {
            let add = (lines[lines.count - 1].isEmpty ? 0 : item.spacingBefore) + item.node.width
            let wouldExceed = !lines[lines.count - 1].isEmpty && lineWidth + add > maxWidth

            if wouldExceed, canBreakBefore(item.atom, previous: lines[lines.count - 1].last?.atom) {
                lines.append([item])
                lineWidth = item.node.width
                continue
            }

            if wouldExceed, let breakAt = bestBreakIndex(in: lines[lines.count - 1], maxWidth: maxWidth, parameters: env.parameters) {
                appendByBreaking(
                    item,
                    breakAt: breakAt,
                    lines: &lines,
                    lineWidth: &lineWidth,
                    maxWidth: maxWidth
                )
                continue
            }

            // Last resort: mid-word / letter breaks when no soft opportunity exists.
            if wouldExceed, let breakAt = bestBreakIndex(in: lines[lines.count - 1], allowMidWord: true, maxWidth: maxWidth, parameters: env.parameters) {
                appendByBreaking(
                    item,
                    breakAt: breakAt,
                    lines: &lines,
                    lineWidth: &lineWidth,
                    maxWidth: maxWidth
                )
                continue
            }

            if wouldExceed, canBreakBefore(item.atom, previous: lines[lines.count - 1].last?.atom, allowMidWord: true) {
                lines.append([item])
                lineWidth = item.node.width
                continue
            }

            lines[lines.count - 1].append(item)
            lineWidth += add
        }

        // TeX-like paragraph spacing: floor baselineskip ≈ 1.2× size, plus a small
        // inter-line gap in mu (not full demerits / \baselineskip glue).
        let minBaselineSkip = styleFont.size * 1.2
        let interLineGap = max(styleFont.size * 0.25, styleMetrics.mathUnit * 3)
        let continuationIndent = styleMetrics.mathUnit * 12
        var lineDisplays: [DisplayList] = []
        var totalAscent: CGFloat = 0
        var totalDescent: CGFloat = 0
        var totalWidth: CGFloat = 0
        var y: CGFloat = 0

        for (lineIndex, line) in lines.enumerated() {
            let indent = lineIndex > 0 ? continuationIndent : 0
            let display = materializeLine(line, indent: indent)
            totalWidth = max(totalWidth, display.width)
            if lineIndex == 0 {
                totalAscent = display.ascent
                totalDescent = display.descent
                y = 0
            } else {
                let prev = lineDisplays[lineIndex - 1]
                let natural = prev.descent + interLineGap + display.ascent
                let step = max(natural, minBaselineSkip)
                y -= step
                totalDescent = -y + display.descent
            }
            var placed = display
            placed.position = CGPoint(x: 0, y: y)
            lineDisplays.append(placed)
        }

        // Flush-right tag on the last line when present.
        if var tag = pendingTag, !lineDisplays.isEmpty {
            let last = lineDisplays.count - 1
            var lastLine = lineDisplays[last]
            let gap = styleMetrics.mathUnit * 18
            let tagX = max(lastLine.width + gap, maxWidth - tag.width)
            tag.position = CGPoint(x: tagX, y: 0)
            lastLine.children.append(tag)
            lastLine.width = max(lastLine.width, tagX + tag.width)
            lastLine.ascent = max(lastLine.ascent, tag.ascent)
            lastLine.descent = max(lastLine.descent, tag.descent)
            lineDisplays[last] = lastLine
            totalWidth = max(totalWidth, lastLine.width)
            totalAscent = max(totalAscent, lineDisplays[0].ascent)
            totalDescent = max(totalDescent, -lineDisplays[last].position.y + lastLine.descent)
        }

        let children = lineDisplays.map { DisplayNode.list($0) }
        let finalWidth: CGFloat
        if maxWidth > 0 {
            // With a flush-right tag, occupy the full paragraph width.
            finalWidth = pendingTag != nil ? max(totalWidth, maxWidth) : min(totalWidth, maxWidth)
        } else {
            finalWidth = totalWidth
        }
        return DisplayList(
            ascent: totalAscent,
            descent: totalDescent,
            width: finalWidth,
            children: children
        )
    }

    private static func appendByBreaking(
        _ item: PlacedAtom,
        breakAt: Int,
        lines: inout [[PlacedAtom]],
        lineWidth: inout CGFloat,
        maxWidth: CGFloat
    ) {
        let moved = Array(lines[lines.count - 1][breakAt...])
        lines[lines.count - 1] = Array(lines[lines.count - 1][..<breakAt])
        lines.append(moved)
        lineWidth = lineWidthOf(moved)
        let addAfterBreak =
            (lines[lines.count - 1].isEmpty ? 0 : item.spacingBefore) + item.node.width
        if lineWidth + addAfterBreak > maxWidth,
           canBreakBefore(item.atom, previous: moved.last?.atom, allowMidWord: true) {
            lines.append([item])
            lineWidth = item.node.width
        } else {
            lines[lines.count - 1].append(item)
            lineWidth += addAfterBreak
        }
    }

    private static func materializeLine(_ items: [PlacedAtom], indent: CGFloat = 0) -> DisplayList {
        var children: [DisplayNode] = []
        var x: CGFloat = indent
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        for (i, item) in items.enumerated() {
            if i > 0 { x += item.spacingBefore }
            var node = item.node
            node.position = CGPoint(x: x, y: 0)
            children.append(node)
            x += node.width
            ascent = max(ascent, node.ascent)
            descent = max(descent, node.descent)
        }
        return DisplayList(ascent: ascent, descent: descent, width: x, children: children)
    }

    private static func lineWidthOf(_ items: [PlacedAtom]) -> CGFloat {
        var w: CGFloat = 0
        for (i, item) in items.enumerated() {
            if i > 0 { w += item.spacingBefore }
            w += item.node.width
        }
        return w
    }

    /// Prefer breaks before relations / binary ops / after spaces.
    /// Mid-word letter breaks are opt-in (`allowMidWord`) for overflow rescue.
    static func canBreakBefore(
        _ atom: MathAtom,
        previous: MathAtom?,
        allowMidWord: Bool = false
    ) -> Bool {
        // Explicit break control commands
        if atom.nucleus == "\\allowbreak" { return true }
        if atom.nucleus == "\\nobreak" || previous?.nucleus == "\\nobreak" { return false }

        // Tags stay with the equation body (placed by Typesetter on single-line path).
        if case .tag = atom.payload { return false }

        // Never break before trailing punctuation (keep "word," together).
        if atom.kind == .punctuation { return false }

        if let previous {
            if previous.kind == .open { return false }
            // Space is an explicit break opportunity (common inside `\text{…}`).
            if case .space = previous.payload { return true }
            // Prefer keeping multi-letter text words intact.
            if isTextLetter(previous), isTextLetter(atom) {
                return allowMidWord
            }
        }

        switch atom.kind {
        case .relation, .binaryOperator:
            return true
        case .space:
            return true
        case .fraction, .radical, .inner, .table, .largeOperator:
            return true
        default:
            if case .colored = atom.payload { return previous.map(isGoodBreakAfter) ?? false }
            if case .styled = atom.payload { return previous.map(isGoodBreakAfter) ?? false }
            if case .box = atom.payload { return previous.map(isGoodBreakAfter) ?? false }
            if case .tag = atom.payload { return false }
            return previous.map(isGoodBreakAfter) ?? false
        }
    }

    private static func isGoodBreakAfter(_ previous: MathAtom) -> Bool {
        if case .space = previous.payload { return true }
        switch previous.kind {
        case .relation, .binaryOperator, .punctuation, .close:
            return true
        default:
            return false
        }
    }

    private static func isTextLetter(_ atom: MathAtom) -> Bool {
        guard atom.kind == .ordinary || atom.kind == .variable || atom.kind == .number else {
            return false
        }
        guard atom.nucleus.count == 1, let ch = atom.nucleus.first else { return false }
        return ch.isLetter || ch.isNumber
    }

    /// Higher score = better break (prefer end of line, relations over binary ops, top-level over nested).
    private static func breakScore(
        at index: Int,
        in line: [PlacedAtom],
        allowMidWord: Bool,
        maxWidth: CGFloat = 0,
        parameters: MathParameters = .default
    ) -> Int {
        let atom = line[index].atom
        let previous = line[index - 1].atom
        guard canBreakBefore(atom, previous: previous, allowMidWord: allowMidWord) else {
            return -1
        }
        if previous.nucleus == "\\nobreak" { return -1 }

        // Explicit break command \allowbreak gets top score (penalty = 0)
        if atom.nucleus == "\\allowbreak" {
            return 2000 + index
        }

        // Penalize breaks inside nested delimiters (open/close groups) so breaks prefer top-level.
        var openDepth = 0
        for k in 0..<index {
            if line[k].atom.kind == .open { openDepth += 1 } else if line[k].atom.kind == .close { openDepth = max(0, openDepth - 1) }
        }
        let nestPenalty = openDepth * 150

        // TeX penalty calculation: relpenalty (500) < binoppenalty (700) -> relations score higher than binary ops
        let endBias = index * 2
        let baseScore: Int
        switch atom.kind {
        case .relation:
            // 1000 - 500 = 500 base
            baseScore = (1000 - parameters.relpenalty) + endBias
        case .binaryOperator:
            // 1000 - 700 = 300 base
            baseScore = (1000 - parameters.binoppenalty) + endBias
        case .space:
            baseScore = 350 + endBias
        case .fraction, .radical, .inner, .table, .largeOperator:
            baseScore = 250 + endBias
        default:
            if case .space = previous.payload { baseScore = 350 + endBias } else if previous.kind == .close || previous.kind == .punctuation {
                baseScore = 200 + endBias
            } else {
                baseScore = allowMidWord ? 10 + endBias : -1
            }
        }

        // Knuth-Plass Demerits squared influence: penalize line width shortfall
        var badnessPenalty = 0
        if maxWidth > 0 {
            let currentWidth = lineWidthOf(Array(line[..<index]))
            let ratio = max(0, (maxWidth - currentWidth) / maxWidth)
            badnessPenalty = Int(min(100, ratio * ratio * 50))
        }

        return baseScore >= 0 ? max(0, baseScore - nestPenalty - badnessPenalty) : -1
    }

    private static func bestBreakIndex(
        in line: [PlacedAtom],
        allowMidWord: Bool = false,
        maxWidth: CGFloat = 0,
        parameters: MathParameters = .default
    ) -> Int? {
        guard line.count > 1 else { return nil }
        var bestIndex: Int?
        var bestScore = -1
        for i in 1..<line.count {
            let score = breakScore(at: i, in: line, allowMidWord: allowMidWord, maxWidth: maxWidth, parameters: parameters)
            if score > bestScore {
                bestScore = score
                bestIndex = i
            }
        }
        return bestScore >= 0 ? bestIndex : nil
    }
}
