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
        return .line(
            LineDisplay(
                inner: inner,
                isOverline: true,
                ruleThickness: thickness,
                ascent: inner.ascent + gap + thickness,
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
        return .line(
            LineDisplay(
                inner: inner,
                isOverline: false,
                ruleThickness: thickness,
                ascent: inner.ascent,
                descent: inner.descent + gap + thickness + extra,
                width: inner.width
            )
        )
    }
}
