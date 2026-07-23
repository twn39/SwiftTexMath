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
        let axis = metrics.axisHeight
        let thickness = fraction.hasRule ? metrics.fractionRuleThickness : 0
        let ruleOffset = fraction.hasRule ? axis : 0

        let numShift: CGFloat
        let denShift: CGFloat
        let numGap: CGFloat
        let denGap: CGFloat
        if env.style == .display {
            numShift = metrics.fractionNumeratorDisplayStyleShiftUp
            denShift = metrics.fractionDenominatorDisplayStyleShiftDown
            numGap = metrics.fractionNumeratorDisplayStyleGapMin
            denGap = metrics.fractionDenominatorDisplayStyleGapMin
        } else {
            numShift = metrics.fractionNumeratorShiftUp
            denShift = metrics.fractionDenominatorShiftDown
            numGap = metrics.fractionNumeratorGapMin
            denGap = metrics.fractionDenominatorGapMin
        }

        // Default shifts from the MATH table, then raise/lower to honor min gaps.
        var numeratorOffset = numShift
        var denominatorOffset = denShift

        if fraction.hasRule {
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
            // `\atop` / stack without a rule: keep a minimum separation around the axis.
            let minNum = axis + numGap + numerator.descent
            if numeratorOffset < minNum {
                numeratorOffset = minNum
            }
            let minDen = denominator.ascent + denGap - axis
            if denominatorOffset < minDen {
                denominatorOffset = minDen
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
