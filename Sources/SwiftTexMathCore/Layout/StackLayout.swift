import CoreGraphics
import Foundation

/// Layout for `\overset` / `\underset` / stretchy over/under constructions.
enum StackLayout {
    static func make(
        _ stack: MathAtom.Stack,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding = FontRegistry.shared,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        let base = typeset(stack.base, env)
        let scriptEnv = env.with(style: env.style.scriptStyle)
        let gap = metrics.overbarVerticalGap

        var overDisplay: DisplayList?
        if let over = stack.over {
            overDisplay = typeset(over, scriptEnv)
        } else if let nucleus = stack.overNucleus {
            overDisplay = stretchyOverlay(
                nucleus: nucleus, width: base.width, env: env, metrics: metrics, fonts: fonts
            )
        }

        var underDisplay: DisplayList?
        if let under = stack.under {
            underDisplay = typeset(under, scriptEnv)
        } else if let nucleus = stack.underNucleus {
            underDisplay = stretchyOverlay(
                nucleus: nucleus, width: base.width, env: env, metrics: metrics, fonts: fonts
            )
        }

        let width = max(base.width, overDisplay?.width ?? 0, underDisplay?.width ?? 0)

        var placedBase = base
        placedBase.position = CGPoint(x: (width - base.width) / 2, y: 0)

        var ascent = base.ascent
        var descent = base.descent

        if var over = overDisplay {
            over.position = CGPoint(
                x: (width - over.width) / 2,
                y: base.ascent + gap + over.descent
            )
            ascent = max(ascent, over.position.y + over.ascent)
            overDisplay = over
        }

        if var under = underDisplay {
            under.position = CGPoint(
                x: (width - under.width) / 2,
                y: -(base.descent + gap + under.ascent)
            )
            descent = max(descent, -under.position.y + under.descent)
            underDisplay = under
        }

        return .stack(
            StackDisplay(
                base: placedBase,
                over: overDisplay,
                under: underDisplay,
                ascent: ascent,
                descent: descent,
                width: width
            )
        )
    }

    /// Prefer a single glyph; if MATH horizontal variants exist and are wider, use the best fit.
    private static func stretchyOverlay(
        nucleus: String,
        width: CGFloat,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding
    ) -> DisplayList {
        let styleFont = MathFont(name: env.font.name, size: env.styleFontSize)
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics
        let glyph = styleMetrics.glyph(for: nucleus)
        let measured = styleMetrics.measure(glyphs: [glyph])
        let run = GlyphRun(
            text: nucleus,
            font: styleFont,
            ascent: measured.ascent,
            descent: measured.descent,
            width: max(measured.width, width),
            glyphIDs: [UInt16(glyph)]
        )
        return DisplayList(
            ascent: run.ascent,
            descent: run.descent,
            width: run.width,
            children: [.glyphs(run)]
        )
    }
}
