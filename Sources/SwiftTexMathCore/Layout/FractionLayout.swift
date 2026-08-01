import CoreGraphics
import Foundation

enum FractionLayout {
    static func make(
        _ fraction: MathAtom.Fraction,
        env: MathEnvironment,
        metrics: FontMetrics,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        var env = env
        if let forced = fraction.forcedStyle {
            env.style = forced
        }

        let numStyle = env.style == .display ? MathStyle.text : env.style.scriptStyle
        let denStyle = numStyle
        let numEnv = env.with(style: numStyle, cramped: false)
        let denEnv = env.with(style: denStyle, cramped: true)

        var numerator = typeset(fraction.numerator, numEnv)
        var denominator = typeset(fraction.denominator, denEnv)

        let width = max(numerator.width, denominator.width)
        switch fraction.numeratorAlignment {
        case .left:
            numerator.position = .zero
        case .center:
            numerator.position = CGPoint(x: (width - numerator.width) / 2, y: 0)
        case .right:
            numerator.position = CGPoint(x: width - numerator.width, y: 0)
        }
        denominator.position = CGPoint(x: (width - denominator.width) / 2, y: 0)

        // Offsets are relative to the surrounding math baseline (TeX Appendix G).
        // The fraction rule is centered on the math axis, not on the baseline.
        // With-rule: style-aware fraction shifts/gaps. No-rule (`\atop`/`\binom`):
        // OpenType Stack* constants.
        let axis = metrics.axisHeight
        let thickness = fraction.hasRule ? metrics.fractionRuleThickness : 0
        let ruleOffset = fraction.hasRule ? axis : 0

        // Default shifts from the MATH table, then raise/lower to honor min gaps.
        var numeratorOffset: CGFloat
        var denominatorOffset: CGFloat

        if fraction.hasRule {
            let numShift = metrics.fractionNumeratorShiftUp(for: env.style)
            let denShift = metrics.fractionDenominatorShiftDown(for: env.style)
            let numGap = metrics.fractionNumeratorGapMin(for: env.style)
            let denGap = metrics.fractionDenominatorGapMin(for: env.style)
            numeratorOffset = numShift
            denominatorOffset = denShift
            // Gap above the rule: num baseline − num.descent − (axis + thickness/2)
            let minNum = axis + thickness / 2 + numGap + numerator.descent
            if numeratorOffset < minNum {
                numeratorOffset = minNum
            }
            // Gap below the rule: (axis − thickness/2) − (−denOffset + den.ascent)
            let minDen = denominator.ascent + denGap + thickness / 2 - axis
            if denominatorOffset < minDen {
                denominatorOffset = minDen
            }
        } else {
            // `\atop` / `\binom` / `\choose`: StackTop/Bottom shifts + StackGapMin.
            let numShift = metrics.stackTopShiftUp(for: env.style)
            let denShift = metrics.stackBottomShiftDown(for: env.style)
            let minStack = metrics.stackGapMin(for: env.style)
            numeratorOffset = numShift
            denominatorOffset = denShift
            // Keep num above axis and den below axis by at least half the stack gap
            // when content is tiny (mirrors classic axis-centered stack placement).
            let half = minStack / 2
            let minNum = axis + half + numerator.descent
            if numeratorOffset < minNum {
                numeratorOffset = minNum
            }
            let minDen = denominator.ascent + half - axis
            if denominatorOffset < minDen {
                denominatorOffset = minDen
            }
            // Enforce the full StackGapMin between num bottom and den top.
            let numBottom = numeratorOffset - numerator.descent
            let denTop = -denominatorOffset + denominator.ascent
            let stackGap = numBottom - denTop
            if stackGap + 0.001 < minStack {
                let need = minStack - stackGap
                numeratorOffset += need / 2
                denominatorOffset += need / 2
            }
        }

        let ascent = numeratorOffset + numerator.ascent
        let descent = denominatorOffset + denominator.descent

        return .fraction(
            FractionDisplay(
                numerator: numerator,
                denominator: denominator,
                ruleThickness: thickness,
                ruleOffset: ruleOffset,
                numeratorOffset: numeratorOffset,
                denominatorOffset: denominatorOffset,
                ascent: ascent,
                descent: descent,
                width: width
            )
        )
    }
}
