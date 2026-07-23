import CoreGraphics
import Foundation

enum RadicalLayout {
    static func make(
        _ radical: MathAtom.Radical,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        let radicandEnv = env.with(cramped: true)
        var radicand = typeset(radical.radicand, radicandEnv)

        let gap = env.style == .display
            ? metrics.radicalDisplayStyleVerticalGap
            : metrics.radicalVerticalGap
        let rule = metrics.radicalRuleThickness
        let extra = metrics.radicalExtraAscender

        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics

        let needed = radicand.ascent + radicand.descent + gap + rule
        let sized = styleMetrics.sizedRadical(height: needed)
        var radicalGlyph = GlyphRun.from(
            sized: sized,
            text: "\u{221A}",
            font: styleFont,
            metrics: styleMetrics,
            centerOnAxis: false
        )

        var degree: DisplayList?
        var degreeWidth: CGFloat = 0
        if let deg = radical.degree {
            let degEnv = env.with(style: .scriptScript)
            degree = typeset(deg, degEnv)
            degreeWidth = metrics.radicalKernBeforeDegree + (degree?.width ?? 0)
                + metrics.radicalKernAfterDegree
        }

        radicalGlyph.position = CGPoint(x: degreeWidth, y: 0)
        radicand.position = CGPoint(x: degreeWidth + radicalGlyph.width, y: 0)
        if var deg = degree {
            deg.position = CGPoint(
                x: metrics.radicalKernBeforeDegree,
                y: (radicand.ascent - radicand.descent) * 0.6
            )
            degree = deg
        }

        let ascent = max(radicalGlyph.ascent, radicand.ascent + gap + rule + extra)
        let descent = max(radicalGlyph.descent, radicand.descent)
        let width = degreeWidth + radicalGlyph.width + radicand.width

        return .radical(
            RadicalDisplay(
                radicand: radicand,
                degree: degree,
                radicalGlyph: radicalGlyph,
                ruleThickness: rule,
                ascent: ascent,
                descent: descent,
                width: width
            )
        )
    }
}
