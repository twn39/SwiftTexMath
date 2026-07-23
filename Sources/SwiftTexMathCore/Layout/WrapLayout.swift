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

        guard !items.isEmpty else { return DisplayList() }

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

            if wouldExceed, let breakAt = bestBreakIndex(in: lines[lines.count - 1]) {
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
            if wouldExceed, let breakAt = bestBreakIndex(in: lines[lines.count - 1], allowMidWord: true) {
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

        // Approximate TeX / SwiftMath line skip: ~1.5× font size between baselines.
        let lineGap = max(styleFont.size * 0.35, styleMetrics.mathUnit * 2)
        var lineDisplays: [DisplayList] = []
        var totalAscent: CGFloat = 0
        var totalDescent: CGFloat = 0
        var totalWidth: CGFloat = 0
        var y: CGFloat = 0

        for (lineIndex, line) in lines.enumerated() {
            let display = materializeLine(line)
            totalWidth = max(totalWidth, display.width)
            if lineIndex == 0 {
                totalAscent = display.ascent
                totalDescent = display.descent
                y = 0
            } else {
                let step = lineDisplays[lineIndex - 1].descent + lineGap + display.ascent
                y -= step
                totalDescent = -y + display.descent
            }
            var placed = display
            placed.position = CGPoint(x: 0, y: y)
            lineDisplays.append(placed)
        }

        let children = lineDisplays.map { DisplayNode.list($0) }
        return DisplayList(
            ascent: totalAscent,
            descent: totalDescent,
            width: min(totalWidth, maxWidth),
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
           canBreakBefore(item.atom, previous: moved.last?.atom, allowMidWord: true)
        {
            lines.append([item])
            lineWidth = item.node.width
        } else {
            lines[lines.count - 1].append(item)
            lineWidth += addAfterBreak
        }
    }

    private static func materializeLine(_ items: [PlacedAtom]) -> DisplayList {
        var children: [DisplayNode] = []
        var x: CGFloat = 0
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
            // Don't break immediately after a binary/relation (avoid dangling op at EOL).
            // Breaks happen *before* the next atom instead.
        }

        switch atom.kind {
        case .relation, .binaryOperator:
            return true
        case .space:
            return true
        case .fraction, .radical, .inner, .table, .largeOperator:
            // Prefer breaking before large constructs rather than overflowing.
            return true
        default:
            // Colored / styled / box / stack payloads behave like ordinary.
            if case .colored = atom.payload { return previous.map(isGoodBreakAfter) ?? false }
            if case .styled = atom.payload { return previous.map(isGoodBreakAfter) ?? false }
            if case .box = atom.payload { return previous.map(isGoodBreakAfter) ?? false }
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

    private static func bestBreakIndex(in line: [PlacedAtom], allowMidWord: Bool = false) -> Int? {
        guard line.count > 1 else { return nil }
        // Prefer relation / binary breaks closest to the end.
        for i in stride(from: line.count - 1, through: 1, by: -1) {
            let atom = line[i].atom
            if atom.kind == .relation || atom.kind == .binaryOperator,
               canBreakBefore(atom, previous: line[i - 1].atom, allowMidWord: allowMidWord)
            {
                return i
            }
        }
        for i in stride(from: line.count - 1, through: 1, by: -1) {
            if canBreakBefore(line[i].atom, previous: line[i - 1].atom, allowMidWord: allowMidWord) {
                return i
            }
        }
        return nil
    }
}
