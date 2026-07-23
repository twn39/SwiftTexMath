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
        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics
        var glyphID = styleMetrics.glyph(for: atom.nucleus)
        if env.style == .display {
            glyphID = styleMetrics.largerGlyph(glyphID, forDisplayStyle: true)
        }
        let measured = styleMetrics.measure(glyphs: [glyphID])
        let italic = styleMetrics.italicCorrection(for: glyphID)
        // Center the operator on the math axis (TeX large-op convention).
        let axisShift = 0.5 * (measured.ascent - measured.descent) - styleMetrics.axisHeight
        let nucleus = GlyphRun(
            text: atom.nucleus,
            font: styleFont,
            ascent: measured.ascent,
            descent: measured.descent,
            width: measured.width,
            glyphIDs: [UInt16(glyphID)],
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
}
