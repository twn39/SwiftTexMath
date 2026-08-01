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
        // Stretchy nuclei (`\overbrace`, `\overrightarrow`, …) use StretchStack* MATH
        // gaps; plain `\overset` / `\underset` keep over/underbar + limit gaps.
        let usesStretchStack = stack.overNucleus != nil || stack.underNucleus != nil
        let overGap: CGFloat
        let underGap: CGFloat
        if usesStretchStack {
            overGap = max(metrics.stretchStackGapAboveMin, metrics.overbarVerticalGap)
            underGap = max(metrics.stretchStackGapBelowMin, metrics.underbarVerticalGap)
        } else {
            overGap = max(metrics.overbarVerticalGap, metrics.upperLimitGapMin)
            underGap = max(metrics.underbarVerticalGap, metrics.lowerLimitGapMin)
        }

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
            // Gap-based placement. StretchStackTop/BottomShift* are available on metrics
            // for future baseline-rise floors; applying them as absolute offsets collides
            // with multi-part underbrace/overbrace + script constructions.
            over.position = CGPoint(
                x: (width - over.width) / 2,
                y: base.ascent + overGap + over.descent
            )
            ascent = max(ascent, over.position.y + over.ascent)
            overDisplay = over
        }

        if var under = underDisplay {
            under.position = CGPoint(
                x: (width - under.width) / 2,
                y: -(base.descent + underGap + under.ascent)
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

    /// Prefer MATH horizontal variants, then `h_assembly`, when the base is wide.
    private static func stretchyOverlay(
        nucleus: String,
        width: CGFloat,
        env: MathEnvironment,
        metrics: FontMetrics,
        fonts: any FontProviding
    ) -> DisplayList {
        let styleFont = MathFont(name: env.font.name, size: metrics.styleFontSize(baseSize: env.font.size, style: env.style))
        let styleMetrics = fonts.metrics(for: styleFont) ?? metrics
        let baseGlyph = styleMetrics.glyph(for: nucleus)
        let sized = styleMetrics.sizedHorizontal(baseGlyph, coveringWidth: width)
        let run = GlyphRun.from(
            sized: sized,
            text: nucleus,
            font: styleFont,
            metrics: styleMetrics,
            centerOnAxis: false
        )
        // Report at least the requested coverage so parent centering stays correct.
        var adjusted = run
        adjusted.width = max(run.width, width)
        return DisplayList(
            ascent: adjusted.ascent,
            descent: adjusted.descent,
            width: adjusted.width,
            children: [.glyphs(adjusted)]
        )
    }
}
