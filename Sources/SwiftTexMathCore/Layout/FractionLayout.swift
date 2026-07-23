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
        numerator.position = CGPoint(x: (width - numerator.width) / 2, y: 0)
        denominator.position = CGPoint(x: (width - denominator.width) / 2, y: 0)

        let axis = metrics.axisHeight
        let thickness = fraction.hasRule ? metrics.fractionRuleThickness : 0

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

        var numeratorOffset = max(numShift, axis + thickness / 2 + numGap + numerator.descent)
        var denominatorOffset = max(denShift, -axis + thickness / 2 + denGap + denominator.ascent)

        // Clearance from axis
        if fraction.hasRule {
            let clearNum = numeratorOffset - numerator.descent - (axis + thickness / 2)
            if clearNum < numGap {
                numeratorOffset += numGap - clearNum
            }
            let clearDen = (axis - thickness / 2) - (-denominatorOffset + denominator.ascent)
            // denominator sits at -denominatorOffset baseline
            _ = clearDen
        }

        let ascent = numeratorOffset + numerator.ascent
        let descent = denominatorOffset + denominator.descent

        return .fraction(
            FractionDisplay(
                numerator: numerator,
                denominator: denominator,
                ruleThickness: thickness,
                numeratorOffset: numeratorOffset,
                denominatorOffset: denominatorOffset,
                ascent: ascent,
                descent: descent,
                width: width
            )
        )
    }
}
