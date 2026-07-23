import CoreGraphics
import Foundation

enum AccentLayout {
    static func make(
        _ accent: MathAtom.Accent,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        let innerBase = typeset(accent.base, env.with(cramped: true))
        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics

        let accentGlyphID = styleMetrics.glyph(for: accent.accent)
        let measured = styleMetrics.measure(glyphs: [accentGlyphID])
        let italic = italicCorrection(of: .list(innerBase))
        let baseAdjust: CGFloat
        if case .glyphs(let run) = innerBase.children.last, let last = run.glyphIDs.last {
            baseAdjust = styleMetrics.topAccentAdjustment(for: CGGlyph(last))
        } else if let lastAtomNucleus = accent.base.atoms.last?.nucleus, !lastAtomNucleus.isEmpty {
            baseAdjust = styleMetrics.topAccentAdjustment(for: styleMetrics.glyph(for: lastAtomNucleus))
        } else {
            baseAdjust = innerBase.width / 2
        }
        let accentAdjust = styleMetrics.topAccentAdjustment(for: accentGlyphID)
        let skew = italic + (baseAdjust - accentAdjust)

        let delta = min(innerBase.ascent, styleMetrics.accentBaseHeight)
        let accentY = max(innerBase.ascent - delta, 0)

        let accentGlyph = GlyphRun(
            text: accent.accent,
            font: styleFont,
            ascent: measured.ascent,
            descent: measured.descent,
            width: measured.width,
            position: CGPoint(x: skew, y: accentY),
            glyphIDs: [UInt16(accentGlyphID)],
            italicCorrection: styleMetrics.italicCorrection(for: accentGlyphID)
        )

        let width = max(innerBase.width, skew + measured.width)
        let ascent = max(innerBase.ascent, accentY + measured.ascent)
        return .list(
            DisplayList(
                ascent: ascent,
                descent: innerBase.descent,
                width: width,
                children: [.list(innerBase), .glyphs(accentGlyph)]
            )
        )
    }

    private static func italicCorrection(of node: DisplayNode) -> CGFloat {
        switch node {
        case .glyphs(let run):
            return run.italicCorrection
        case .list(let list):
            return list.children.last.map(italicCorrection(of:)) ?? 0
        default:
            return 0
        }
    }
}
