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

        // Prefer style-scaled metrics so script/scriptscript radicals scale gaps with size.
        let styleFont = MathFont(name: env.font.name, size: metrics.styleFontSize(baseSize: env.font.size, style: env.style))
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics

        let gap = styleMetrics.radicalVerticalGap(for: env.style)
        let rule = styleMetrics.radicalRuleThickness
        let extra = styleMetrics.radicalExtraAscender

        // Cover radicand + gap + rule so the radical sign is tall enough for the overbar.
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
            degreeWidth = styleMetrics.radicalKernBeforeDegree + (degree?.width ?? 0)
                + styleMetrics.radicalKernAfterDegree
        }

        // Overbar center: radicand top + vertical gap + half rule (stroke is centered).
        let ruleOffset = radicand.ascent + gap + rule / 2
        let ruleTop = ruleOffset + rule / 2

        // Align the radical glyph's top with the overbar top (TeX radical construction).
        // Drawn at y − shiftDown → visual top = ascent − shiftDown.
        radicalGlyph.shiftDown = radicalGlyph.ascent - ruleTop
        radicalGlyph.position = CGPoint(x: degreeWidth, y: 0)
        radicand.position = CGPoint(x: degreeWidth + radicalGlyph.width, y: 0)

        let glyphTop = ruleTop
        let glyphBottom = radicalGlyph.descent + radicalGlyph.shiftDown
        var ascent = max(glyphTop + extra, ruleTop + extra)
        var descent = max(glyphBottom, radicand.descent)

        // OpenType: raise degree bottom by RadicalDegreeBottomRaisePercent of total height.
        if var deg = degree {
            let totalHeight = ascent + descent
            let raise = totalHeight * styleMetrics.radicalDegreeBottomRaisePercent
            // Bottom of degree at −descent + raise → baseline = that + deg.descent
            deg.position = CGPoint(
                x: styleMetrics.radicalKernBeforeDegree,
                y: -descent + raise + deg.descent
            )
            ascent = max(ascent, deg.position.y + deg.ascent)
            descent = max(descent, -deg.position.y + deg.descent)
            degree = deg
        }

        let width = degreeWidth + radicalGlyph.width + radicand.width

        return .radical(
            RadicalDisplay(
                radicand: radicand,
                degree: degree,
                radicalGlyph: radicalGlyph,
                ruleThickness: rule,
                ruleOffset: ruleOffset,
                ascent: ascent,
                descent: descent,
                width: width
            )
        )
    }
}
