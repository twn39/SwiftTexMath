import CoreGraphics
import Foundation

/// Overline / underline rule boxes (TeX `\overline` / `\underline`).
enum LineLayout {
    static func makeOverline(
        _ list: MathList,
        env: MathEnvironment,
        metrics: FontMetrics,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        let inner = typeset(list, env.with(cramped: true))
        let thickness = metrics.overbarRuleThickness
        let gap = metrics.overbarVerticalGap
        // Stroke is centered on `ruleOffset`; keep `gap` clear of the inner top.
        let ruleOffset = inner.ascent + gap + thickness / 2
        return .line(
            LineDisplay(
                inner: inner,
                isOverline: true,
                ruleThickness: thickness,
                ruleOffset: ruleOffset,
                ascent: ruleOffset + thickness / 2,
                descent: inner.descent,
                width: inner.width
            )
        )
    }

    static func makeUnderline(
        _ list: MathList,
        env: MathEnvironment,
        metrics: FontMetrics,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        let inner = typeset(list, env)
        let thickness = metrics.underbarRuleThickness
        let gap = metrics.underbarVerticalGap
        let extra = metrics.underbarExtraDescender
        // Stroke centered; clear `gap` below the inner bottom, then extra descender.
        let ruleOffset = -(inner.descent + gap + thickness / 2)
        return .line(
            LineDisplay(
                inner: inner,
                isOverline: false,
                ruleThickness: thickness,
                ruleOffset: ruleOffset,
                ascent: inner.ascent,
                descent: -ruleOffset + thickness / 2 + extra,
                width: inner.width
            )
        )
    }
}
