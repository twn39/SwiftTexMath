import CoreGraphics
import Foundation

/// Style-aware OpenType MATH constants (TeX display vs text/script parameter sets).
///
/// Display style uses the `*DisplayStyle*` MATH constants; text, script, and
/// scriptscript share the non-display parameter set (TeX / OpenType convention).
extension FontMetrics {
    /// Whether `style` should use display-style MATH constants.
    public func usesDisplayStyleConstants(for style: MathStyle) -> Bool {
        style == .display
    }

    // MARK: Script size scale (OpenType MATH)

    /// `ScriptPercentScaleDown` as a fraction (e.g. 70 → 0.70). Falls back to 0.70.
    public var scriptPercentScaleDown: CGFloat {
        let p = percentConstant(named: "ScriptPercentScaleDown")
        return p > 0.01 ? p : 0.7
    }

    /// `ScriptScriptPercentScaleDown` as a fraction (e.g. 50 → 0.50). Falls back to 0.50.
    ///
    /// Both script levels are relative to the **text/display base size** (OpenType
    /// suggested values), matching TeX-like layout engines.
    public var scriptScriptPercentScaleDown: CGFloat {
        let p = percentConstant(named: "ScriptScriptPercentScaleDown")
        return p > 0.01 ? p : 0.5
    }

    /// Multiplier applied to the environment base font size for `style`.
    public func sizeMultiplier(for style: MathStyle) -> CGFloat {
        switch style {
        case .display, .text: return 1
        case .script: return scriptPercentScaleDown
        case .scriptScript: return scriptScriptPercentScaleDown
        }
    }

    /// Style font size given a base (text/display) design size.
    public func styleFontSize(baseSize: CGFloat, style: MathStyle) -> CGFloat {
        baseSize * sizeMultiplier(for: style)
    }

    // MARK: Fractions

    public func fractionNumeratorGapMin(for style: MathStyle) -> CGFloat {
        usesDisplayStyleConstants(for: style)
            ? fractionNumeratorDisplayStyleGapMin
            : fractionNumeratorGapMin
    }

    public func fractionDenominatorGapMin(for style: MathStyle) -> CGFloat {
        usesDisplayStyleConstants(for: style)
            ? fractionDenominatorDisplayStyleGapMin
            : fractionDenominatorGapMin
    }

    public func fractionNumeratorShiftUp(for style: MathStyle) -> CGFloat {
        usesDisplayStyleConstants(for: style)
            ? fractionNumeratorDisplayStyleShiftUp
            : fractionNumeratorShiftUp
    }

    public func fractionDenominatorShiftDown(for style: MathStyle) -> CGFloat {
        usesDisplayStyleConstants(for: style)
            ? fractionDenominatorDisplayStyleShiftDown
            : fractionDenominatorShiftDown
    }

    // MARK: Radicals

    public func radicalVerticalGap(for style: MathStyle) -> CGFloat {
        usesDisplayStyleConstants(for: style)
            ? radicalDisplayStyleVerticalGap
            : radicalVerticalGap
    }

    // MARK: No-rule stacks (`\atop` / `\binom` / `\choose`)

    public func stackTopShiftUp(for style: MathStyle) -> CGFloat {
        usesDisplayStyleConstants(for: style)
            ? stackTopDisplayStyleShiftUp
            : stackTopShiftUp
    }

    public func stackBottomShiftDown(for style: MathStyle) -> CGFloat {
        usesDisplayStyleConstants(for: style)
            ? stackBottomDisplayStyleShiftDown
            : stackBottomShiftDown
    }

    /// Minimum gap between numerator bottom and denominator top for a no-rule stack.
    public func stackGapMin(for style: MathStyle) -> CGFloat {
        usesDisplayStyleConstants(for: style)
            ? stackDisplayStyleGapMin
            : stackGapMin
    }

    // MARK: Multi-line leading

    /// Inter-line gap used by wrap / multi-line layout: OpenType `MathLeading`, with
    /// a `mu` floor so sparse tables still separate lines.
    public func mathInterLineGap(muFloorMultiplier: CGFloat = 3) -> CGFloat {
        let leading = mathLeading
        let muFloor = mathUnit * muFloorMultiplier
        if leading > 0 {
            return max(leading, muFloor)
        }
        return max(size * 0.25, muFloor)
    }
}

extension FontMetricsProtocol {
    /// Protocol-facing script scale (uses MATH percent constants when available).
    public func sizeMultiplier(for style: MathStyle) -> CGFloat {
        switch style {
        case .display, .text:
            return 1
        case .script:
            let p = percentConstant(named: "ScriptPercentScaleDown")
            return p > 0.01 ? p : 0.7
        case .scriptScript:
            let p = percentConstant(named: "ScriptScriptPercentScaleDown")
            return p > 0.01 ? p : 0.5
        }
    }

    public func styleFontSize(baseSize: CGFloat, style: MathStyle) -> CGFloat {
        baseSize * sizeMultiplier(for: style)
    }
}
