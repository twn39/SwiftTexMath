import CoreGraphics
import Foundation

enum DelimiterLayout {
    static func makeInner(
        _ inner: MathAtom.Inner,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics

        let segments = splitOnBoundaries(inner.contents)
        let spacedEnv = env
        let segmentDisplays = segments.lists.map { typeset($0, spacedEnv) }

        let glyphHeight: CGFloat
        if let multiplier = inner.delimiterHeight {
            glyphHeight = env.styleFontSize * multiplier
        } else {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            for display in segmentDisplays {
                ascent = max(ascent, display.ascent)
                descent = max(descent, display.descent)
            }
            let axis = styleMetrics.axisHeight
            let delta = max(ascent - axis, descent + axis)
            let d1 = (delta / 500) * env.parameters.delimiterFactor
            let d2 = 2 * delta - env.parameters.delimiterShortfall
            glyphHeight = max(d1, d2)
        }

        let padding = styleMetrics.mathUnit * 2
        var children: [DisplayNode] = []
        var x: CGFloat = 0
        var ascent: CGFloat = 0
        var descent: CGFloat = 0

        func appendDelimiter(_ nucleus: String) {
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
            let node = DisplayNode.glyphs(glyph)
            // `DisplayNode` already folds `shiftDown` into visual ascent/descent.
            ascent = max(ascent, node.ascent)
            descent = max(descent, node.descent)
            children.append(node)
            x += glyph.width
        }

        if !inner.leftBoundary.isEmpty {
            appendDelimiter(inner.leftBoundary)
            if inner.delimiterHeight == nil || !segmentDisplays.isEmpty {
                x += padding
            }
        }

        // Explicit-height `\big` with empty content: only the delimiter glyph.
        if inner.delimiterHeight != nil, segments.lists.allSatisfy(\.isEmpty), segments.middles.isEmpty {
            return .list(DisplayList(ascent: ascent, descent: descent, width: x, children: children))
        }

        for (index, display) in segmentDisplays.enumerated() {
            var placed = display
            placed.position = CGPoint(x: x, y: 0)
            children.append(.list(placed))
            x += placed.width
            ascent = max(ascent, placed.ascent)
            descent = max(descent, placed.descent)

            if index < segments.middles.count {
                x += padding
                appendDelimiter(segments.middles[index])
                x += padding
            }
        }

        if !inner.rightBoundary.isEmpty {
            x += padding
            appendDelimiter(inner.rightBoundary)
        }

        return .list(DisplayList(ascent: ascent, descent: descent, width: x, children: children))
    }

    private struct Segments {
        var lists: [MathList]
        var middles: [String]
    }

    /// Split a `\left…\right` body on `.boundary` atoms produced by `\middle`.
    private static func splitOnBoundaries(_ list: MathList) -> Segments {
        var lists: [MathList] = [MathList()]
        var middles: [String] = []
        for atom in list.atoms {
            if atom.kind == .boundary {
                middles.append(atom.nucleus)
                lists.append(MathList())
            } else {
                lists[lists.count - 1].append(atom)
            }
        }
        return Segments(lists: lists, middles: middles)
    }
}
