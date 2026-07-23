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
        let nucleus = GlyphRun(
            text: atom.nucleus,
            font: styleFont,
            ascent: measured.ascent,
            descent: measured.descent,
            width: measured.width,
            glyphIDs: [UInt16(glyphID)],
            italicCorrection: italic
        )

        let scriptStyle = env.style.scriptStyle
        var upper = atom.superscript.map { typeset($0, env.with(style: scriptStyle, cramped: false)) }
        var lower = atom.subscript.map { typeset($0, env.with(style: scriptStyle, cramped: true)) }

        let width = max(nucleus.width, upper?.width ?? 0, lower?.width ?? 0)
        var nuc = nucleus
        nuc.position = CGPoint(x: (width - nucleus.width) / 2, y: 0)

        var ascent = nuc.ascent
        var descent = nuc.descent

        if var u = upper {
            let gap = max(metrics.upperLimitGapMin, metrics.upperLimitBaselineRiseMin)
            u.position = CGPoint(x: (width - u.width) / 2, y: nuc.ascent + gap + u.descent)
            ascent = u.position.y + u.ascent
            upper = u
        }
        if var l = lower {
            let gap = max(metrics.lowerLimitGapMin, metrics.lowerLimitBaselineDropMin)
            l.position = CGPoint(x: (width - l.width) / 2, y: -(nuc.descent + gap + l.ascent))
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
