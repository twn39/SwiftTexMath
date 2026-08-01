import CoreGraphics
import Foundation

enum LargeOperatorLayout {
    static func make(
        atom: MathAtom,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        let styleFont = MathFont(name: env.font.name, size: metrics.styleFontSize(baseSize: env.font.size, style: env.style))
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics
        var glyphIDs = styleMetrics.glyphs(for: atom.nucleus)
        if env.style == .display, glyphIDs.count == 1 {
            glyphIDs = [Self.displayOperatorGlyph(
                base: glyphIDs.first ?? 0,
                metrics: styleMetrics
            )]
        }
        let measured = styleMetrics.measure(glyphs: glyphIDs)
        let italic = glyphIDs.count == 1 ? styleMetrics.italicCorrection(for: glyphIDs.first ?? 0) : 0
        // Center the operator on the math axis (TeX large-op convention).
        let axisShift = 0.5 * (measured.ascent - measured.descent) - styleMetrics.axisHeight
        let nucleus = GlyphRun(
            text: atom.nucleus,
            font: styleFont,
            ascent: measured.ascent,
            descent: measured.descent,
            width: measured.width,
            glyphIDs: glyphIDs.map { UInt16($0) },
            shiftDown: axisShift,
            italicCorrection: italic
        )

        let scriptStyle = env.style.scriptStyle
        var upper = atom.superscript.map { typeset($0, env.with(style: scriptStyle, cramped: false)) }
        var lower = atom.subscript.map { typeset($0, env.with(style: scriptStyle, cramped: true)) }

        let width = max(nucleus.width, upper?.width ?? 0, lower?.width ?? 0)
        var nuc = nucleus
        nuc.position = CGPoint(x: (width - nucleus.width) / 2, y: 0)

        // Visual extents after axis shift (glyph is drawn at y - shiftDown).
        let nucTop = nuc.ascent - axisShift
        let nucBottom = nuc.descent + axisShift
        var ascent = nucTop
        var descent = nucBottom

        if var u = upper {
            // GapMin: clear the visual top of the nucleus; BaselineRiseMin: from math baseline.
            let fromGap = nucTop + metrics.upperLimitGapMin + u.descent
            let fromRise = metrics.upperLimitBaselineRiseMin
            u.position = CGPoint(x: (width - u.width) / 2, y: max(fromGap, fromRise))
            ascent = u.position.y + u.ascent
            upper = u
        }
        if var l = lower {
            let fromGap = nucBottom + metrics.lowerLimitGapMin + l.ascent
            let fromDrop = metrics.lowerLimitBaselineDropMin
            l.position = CGPoint(x: (width - l.width) / 2, y: -max(fromGap, fromDrop))
            descent = -l.position.y + l.descent
            lower = l
        }

        return .largeOperator(
            LargeOperatorDisplay(
                nucleus: nuc,
                upperLimit: upper,
                lowerLimit: lower,
                ascent: ascent,
                descent: descent,
                width: width
            )
        )
    }

    /// Display-style large-op nucleus: prefer `largerGlyph`, then the smallest
    /// vertical variant that meets `DisplayOperatorMinHeight` when available.
    private static func displayOperatorGlyph(base: CGGlyph, metrics: FontMetrics) -> CGGlyph {
        let minH = metrics.displayOperatorMinHeight
        let preferred = metrics.largerGlyph(base, forDisplayStyle: true)
        guard minH > 0 else { return preferred }

        let variants = metrics.verticalVariants(for: base)
        guard !variants.isEmpty else { return preferred }

        func height(of glyph: CGGlyph) -> CGFloat {
            let m = metrics.measure(glyphs: [glyph])
            return m.ascent + m.descent
        }

        var best = preferred
        var bestH = height(of: preferred)
        var foundClearing = bestH + 0.01 >= minH

        for v in variants {
            let h = height(of: v)
            if h + 0.01 >= minH {
                if !foundClearing || h < bestH - 0.01 {
                    best = v
                    bestH = h
                    foundClearing = true
                }
            } else if !foundClearing, h > bestH + 0.01 {
                best = v
                bestH = h
            }
        }
        return best
    }
}
