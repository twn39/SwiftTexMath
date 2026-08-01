import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

/// Shared helpers for geometric clearance / axis assertions.
enum LayoutClearance {
    static func metrics(size: CGFloat = 20) -> FontMetrics? {
        FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: size))
    }

    static func firstNode(in display: DisplayList, matching: (DisplayNode) -> Bool) -> DisplayNode? {
        for child in display.children {
            if matching(child) { return child }
            if let found = firstNode(in: child, matching: matching) { return found }
        }
        return nil
    }

    /// Depth-first search into compound nodes (list / fraction / radical / …).
    static func firstNode(in node: DisplayNode, matching: (DisplayNode) -> Bool) -> DisplayNode? {
        if matching(node) { return node }
        switch node {
        case .list(let list):
            return firstNode(in: list, matching: matching)
        case .fraction(let frac):
            if let n = firstNode(in: frac.numerator, matching: matching) { return n }
            return firstNode(in: frac.denominator, matching: matching)
        case .radical(let rad):
            if let n = firstNode(in: rad.radicand, matching: matching) { return n }
            if let degree = rad.degree, let n = firstNode(in: degree, matching: matching) {
                return n
            }
            return nil
        case .largeOperator(let op):
            if let upper = op.upperLimit, let n = firstNode(in: upper, matching: matching) {
                return n
            }
            if let lower = op.lowerLimit, let n = firstNode(in: lower, matching: matching) {
                return n
            }
            return nil
        case .line(let line):
            return firstNode(in: line.inner, matching: matching)
        case .colored(let colored):
            return firstNode(in: colored.inner, matching: matching)
        case .box(let box):
            return firstNode(in: box.child, matching: matching)
        case .stack(let stack):
            if let n = firstNode(in: stack.base, matching: matching) { return n }
            if let over = stack.over, let n = firstNode(in: over, matching: matching) { return n }
            if let under = stack.under, let n = firstNode(in: under, matching: matching) {
                return n
            }
            return nil
        case .glyphs, .rule:
            return nil
        }
    }

    static func fraction(in display: DisplayList) -> FractionDisplay? {
        if case .fraction(let f)? = firstNode(in: display, matching: {
            if case .fraction = $0 { return true }
            return false
        }) { return f }
        return nil
    }

    static func radical(in display: DisplayList) -> RadicalDisplay? {
        if case .radical(let r)? = firstNode(in: display, matching: {
            if case .radical = $0 { return true }
            return false
        }) { return r }
        return nil
    }

    static func line(in display: DisplayList) -> LineDisplay? {
        if case .line(let l)? = firstNode(in: display, matching: {
            if case .line = $0 { return true }
            return false
        }) { return l }
        return nil
    }

    static func largeOperator(in display: DisplayList) -> LargeOperatorDisplay? {
        if case .largeOperator(let op)? = firstNode(in: display, matching: {
            if case .largeOperator = $0 { return true }
            return false
        }) { return op }
        return nil
    }

    static func stack(in display: DisplayList) -> StackDisplay? {
        if case .stack(let s)? = firstNode(in: display, matching: {
            if case .stack = $0 { return true }
            return false
        }) { return s }
        return nil
    }

    /// Every fraction in the tree (depth-first), for nested / multi-row formulas.
    static func allFractions(in display: DisplayList) -> [FractionDisplay] {
        var out: [FractionDisplay] = []
        collectFractions(display, into: &out)
        return out
    }

    private static func collectFractions(_ display: DisplayList, into out: inout [FractionDisplay]) {
        for child in display.children {
            collectFractions(child, into: &out)
        }
    }

    private static func collectFractions(_ node: DisplayNode, into out: inout [FractionDisplay]) {
        switch node {
        case .fraction(let frac):
            out.append(frac)
            collectFractions(frac.numerator, into: &out)
            collectFractions(frac.denominator, into: &out)
        case .list(let list):
            collectFractions(list, into: &out)
        case .radical(let rad):
            collectFractions(rad.radicand, into: &out)
            if let degree = rad.degree { collectFractions(degree, into: &out) }
        case .largeOperator(let op):
            if let upper = op.upperLimit { collectFractions(upper, into: &out) }
            if let lower = op.lowerLimit { collectFractions(lower, into: &out) }
        case .line(let line):
            collectFractions(line.inner, into: &out)
        case .colored(let colored):
            collectFractions(colored.inner, into: &out)
        case .box(let box):
            collectFractions(box.child, into: &out)
        case .stack(let stack):
            collectFractions(stack.base, into: &out)
            if let over = stack.over { collectFractions(over, into: &out) }
            if let under = stack.under { collectFractions(under, into: &out) }
        case .glyphs, .rule:
            break
        }
    }

    /// Absolute math-space origin of `node` when walking from a root list (y-up, baseline 0 at root).
    struct PlacedFraction {
        var fraction: FractionDisplay
        var origin: CGPoint
    }

    static func placedFractions(in display: DisplayList) -> [PlacedFraction] {
        var out: [PlacedFraction] = []
        // Root display position is applied once (same as CGContext.draw).
        collectPlacedFractions(display, origin: .zero, into: &out)
        return out
    }

    private static func collectPlacedFractions(
        _ display: DisplayList,
        origin: CGPoint,
        into out: inout [PlacedFraction]
    ) {
        let base = CGPoint(x: origin.x + display.position.x, y: origin.y + display.position.y)
        for child in display.children {
            collectPlacedFractions(child, origin: base, into: &out)
        }
    }

    private static func collectPlacedFractions(
        _ node: DisplayNode,
        origin: CGPoint,
        into out: inout [PlacedFraction]
    ) {
        switch node {
        case .fraction(let frac):
            let o = CGPoint(x: origin.x + frac.position.x, y: origin.y + frac.position.y)
            out.append(PlacedFraction(fraction: frac, origin: o))
            // Match CGContext draw: num/den y come from offsets, not list.position.y.
            let numOrigin = CGPoint(
                x: o.x + frac.numerator.position.x,
                y: o.y + frac.numeratorOffset
            )
            let denOrigin = CGPoint(
                x: o.x + frac.denominator.position.x,
                y: o.y - frac.denominatorOffset
            )
            for child in frac.numerator.children {
                collectPlacedFractions(child, origin: numOrigin, into: &out)
            }
            for child in frac.denominator.children {
                collectPlacedFractions(child, origin: denOrigin, into: &out)
            }
        case .list(let list):
            collectPlacedFractions(list, origin: origin, into: &out)
        case .radical(let rad):
            let o = CGPoint(x: origin.x + rad.position.x, y: origin.y + rad.position.y)
            collectPlacedFractions(rad.radicand, origin: o, into: &out)
            if let degree = rad.degree {
                collectPlacedFractions(degree, origin: o, into: &out)
            }
        case .largeOperator(let op):
            let o = CGPoint(x: origin.x + op.position.x, y: origin.y + op.position.y)
            if let upper = op.upperLimit { collectPlacedFractions(upper, origin: o, into: &out) }
            if let lower = op.lowerLimit { collectPlacedFractions(lower, origin: o, into: &out) }
        case .line(let line):
            let o = CGPoint(x: origin.x + line.position.x, y: origin.y + line.position.y)
            collectPlacedFractions(line.inner, origin: o, into: &out)
        case .colored(let colored):
            let o = CGPoint(x: origin.x + colored.position.x, y: origin.y + colored.position.y)
            collectPlacedFractions(colored.inner, origin: o, into: &out)
        case .box(let box):
            let o = CGPoint(x: origin.x + box.position.x, y: origin.y + box.position.y)
            collectPlacedFractions(box.child, origin: o, into: &out)
        case .stack(let stack):
            let o = CGPoint(x: origin.x + stack.position.x, y: origin.y + stack.position.y)
            collectPlacedFractions(stack.base, origin: o, into: &out)
            if let over = stack.over { collectPlacedFractions(over, origin: o, into: &out) }
            if let under = stack.under { collectPlacedFractions(under, origin: o, into: &out) }
        case .glyphs, .rule:
            break
        }
    }

    // MARK: - Style-aware fraction / radical clearances

    /// Stack gap between numerator bottom and denominator top (rule-independent).
    static func stackGap(of frac: FractionDisplay) -> CGFloat {
        let numBottom = frac.numeratorOffset - frac.numerator.descent
        let denTop = -frac.denominatorOffset + frac.denominator.ascent
        return numBottom - denTop
    }

    static func numeratorRuleClearance(of frac: FractionDisplay) -> CGFloat {
        let numBottom = frac.numeratorOffset - frac.numerator.descent
        return numBottom - (frac.ruleOffset + frac.ruleThickness / 2)
    }

    static func denominatorRuleClearance(of frac: FractionDisplay) -> CGFloat {
        let denTop = -frac.denominatorOffset + frac.denominator.ascent
        return gapAbove(
            contentTop: denTop,
            ruleOffset: frac.ruleOffset,
            ruleThickness: frac.ruleThickness
        )
    }

    static func radicalOverbarClearance(of rad: RadicalDisplay) -> CGFloat {
        gapAbove(
            contentTop: rad.radicand.ascent,
            ruleOffset: rad.ruleOffset,
            ruleThickness: rad.ruleThickness
        )
    }

    /// Assert numerator/denominator clear the fraction rule using MATH gap mins.
    ///
    /// - When `style` is provided, uses style-specific gap constants (strict).
    /// - When `style` is nil, accepts either text or display mins (nested contexts).
    /// - When `ruleThickness ≈ 0` (`\binom` / `\atop`), delegates to stack-gap assert.
    static func assertFractionRuleClearances(
        _ frac: FractionDisplay,
        metrics: FontMetrics,
        style: MathStyle? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        if frac.ruleThickness < 0.05 {
            assertStackFractionClearance(
                frac, metrics: metrics, style: style ?? .display,
                sourceLocation: sourceLocation
            )
            return
        }

        let numGap: CGFloat
        let denGap: CGFloat
        if let style {
            numGap = metrics.fractionNumeratorGapMin(for: style)
            denGap = metrics.fractionDenominatorGapMin(for: style)
        } else {
            numGap = min(
                metrics.fractionNumeratorGapMin,
                metrics.fractionNumeratorDisplayStyleGapMin
            )
            denGap = min(
                metrics.fractionDenominatorGapMin,
                metrics.fractionDenominatorDisplayStyleGapMin
            )
        }

        let denClear = denominatorRuleClearance(of: frac)
        let numClear = numeratorRuleClearance(of: frac)

        if let style {
            #expect(
                denClear + 0.01 >= denGap,
                "denominator clearance \(denClear) < style \(style) gap \(denGap)",
                sourceLocation: sourceLocation
            )
            #expect(
                numClear + 0.01 >= numGap,
                "numerator clearance \(numClear) < style \(style) gap \(numGap)",
                sourceLocation: sourceLocation
            )
        } else {
            let denOK =
                denClear + 0.01 >= metrics.fractionDenominatorGapMin
                || denClear + 0.01 >= metrics.fractionDenominatorDisplayStyleGapMin
            #expect(
                denOK,
                "denominator clearance \(denClear) < gap mins (text \(metrics.fractionDenominatorGapMin), display \(metrics.fractionDenominatorDisplayStyleGapMin))",
                sourceLocation: sourceLocation
            )
            let numOK =
                numClear + 0.01 >= metrics.fractionNumeratorGapMin
                || numClear + 0.01 >= metrics.fractionNumeratorDisplayStyleGapMin
            #expect(
                numOK,
                "numerator clearance \(numClear)",
                sourceLocation: sourceLocation
            )
        }
    }

    /// Zero-thickness genfrac (`\binom`, `\atop`, `\choose`): require stack separation.
    static func assertStackFractionClearance(
        _ frac: FractionDisplay,
        metrics: FontMetrics,
        style: MathStyle = .display,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        // No-rule stacks honor OpenType StackGapMin / StackDisplayStyleGapMin.
        let minStack = metrics.stackGapMin(for: style)
        let gap = stackGap(of: frac)
        #expect(
            gap + 0.01 >= minStack,
            "stack gap \(gap) < StackGapMin \(minStack) for style \(style)",
            sourceLocation: sourceLocation
        )
        // Num should sit above axis; den below (soft: allow equal for tiny content).
        #expect(
            frac.numeratorOffset + 0.01 >= metrics.axisHeight,
            "numerator offset \(frac.numeratorOffset) should clear axis \(metrics.axisHeight)",
            sourceLocation: sourceLocation
        )
    }

    /// Radical overbar clearance for a known outer style.
    static func assertRadicalClearance(
        _ rad: RadicalDisplay,
        metrics: FontMetrics,
        style: MathStyle,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let gapMin = metrics.radicalVerticalGap(for: style)
        let clearance = radicalOverbarClearance(of: rad)
        #expect(
            clearance + 0.01 >= gapMin,
            "radical clearance \(clearance) < style \(style) gap \(gapMin)",
            sourceLocation: sourceLocation
        )
    }

    /// Soft radical assert: accept text or display gap (unknown nesting style).
    static func assertRadicalClearanceSoft(
        _ rad: RadicalDisplay,
        metrics: FontMetrics,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let clearance = radicalOverbarClearance(of: rad)
        let ok =
            clearance + 0.01 >= metrics.radicalVerticalGap
            || clearance + 0.01 >= metrics.radicalDisplayStyleVerticalGap
        #expect(
            ok,
            "radical clearance \(clearance) < gaps (text \(metrics.radicalVerticalGap), display \(metrics.radicalDisplayStyleVerticalGap))",
            sourceLocation: sourceLocation
        )
    }

    /// Every radical in the tree (depth-first).
    static func allRadicals(in display: DisplayList) -> [RadicalDisplay] {
        var out: [RadicalDisplay] = []
        collectRadicals(display, into: &out)
        return out
    }

    private static func collectRadicals(_ display: DisplayList, into out: inout [RadicalDisplay]) {
        for child in display.children {
            collectRadicals(child, into: &out)
        }
    }

    private static func collectRadicals(_ node: DisplayNode, into out: inout [RadicalDisplay]) {
        switch node {
        case .radical(let rad):
            out.append(rad)
            collectRadicals(rad.radicand, into: &out)
            if let degree = rad.degree { collectRadicals(degree, into: &out) }
        case .list(let list):
            collectRadicals(list, into: &out)
        case .fraction(let frac):
            collectRadicals(frac.numerator, into: &out)
            collectRadicals(frac.denominator, into: &out)
        case .largeOperator(let op):
            if let upper = op.upperLimit { collectRadicals(upper, into: &out) }
            if let lower = op.lowerLimit { collectRadicals(lower, into: &out) }
        case .line(let line):
            collectRadicals(line.inner, into: &out)
        case .colored(let colored):
            collectRadicals(colored.inner, into: &out)
        case .box(let box):
            collectRadicals(box.child, into: &out)
        case .stack(let stack):
            collectRadicals(stack.base, into: &out)
            if let over = stack.over { collectRadicals(over, into: &out) }
            if let under = stack.under { collectRadicals(under, into: &out) }
        case .glyphs, .rule:
            break
        }
    }

    static func firstGlyphRun(in node: DisplayNode) -> GlyphRun? {
        switch node {
        case .glyphs(let run):
            return run
        case .list(let list):
            for child in list.children {
                if let run = firstGlyphRun(in: child) { return run }
            }
            return nil
        case .largeOperator(let op):
            return op.nucleus
        case .radical(let rad):
            return rad.radicalGlyph
        case .stack(let stack):
            if let over = stack.over, let run = firstGlyphRun(in: .list(over)) {
                return run
            }
            if let under = stack.under, let run = firstGlyphRun(in: .list(under)) {
                return run
            }
            return firstGlyphRun(in: .list(stack.base))
        default:
            return nil
        }
    }

    /// Collect every glyph run under a display node (depth-first).
    static func allGlyphRuns(in node: DisplayNode) -> [GlyphRun] {
        var runs: [GlyphRun] = []
        collectGlyphRuns(node, into: &runs)
        return runs
    }

    private static func collectGlyphRuns(_ node: DisplayNode, into runs: inout [GlyphRun]) {
        switch node {
        case .glyphs(let run):
            runs.append(run)
        case .list(let list):
            for child in list.children { collectGlyphRuns(child, into: &runs) }
        case .fraction(let frac):
            for child in frac.numerator.children { collectGlyphRuns(child, into: &runs) }
            for child in frac.denominator.children { collectGlyphRuns(child, into: &runs) }
        case .radical(let rad):
            runs.append(rad.radicalGlyph)
            for child in rad.radicand.children { collectGlyphRuns(child, into: &runs) }
            if let degree = rad.degree {
                for child in degree.children { collectGlyphRuns(child, into: &runs) }
            }
        case .largeOperator(let op):
            runs.append(op.nucleus)
            if let upper = op.upperLimit {
                for child in upper.children { collectGlyphRuns(child, into: &runs) }
            }
            if let lower = op.lowerLimit {
                for child in lower.children { collectGlyphRuns(child, into: &runs) }
            }
        case .line(let line):
            for child in line.inner.children { collectGlyphRuns(child, into: &runs) }
        case .colored(let colored):
            for child in colored.inner.children { collectGlyphRuns(child, into: &runs) }
        case .box(let box):
            for child in box.child.children { collectGlyphRuns(child, into: &runs) }
        case .stack(let stack):
            for child in stack.base.children { collectGlyphRuns(child, into: &runs) }
            if let over = stack.over {
                for child in over.children { collectGlyphRuns(child, into: &runs) }
            }
            if let under = stack.under {
                for child in under.children { collectGlyphRuns(child, into: &runs) }
            }
        case .rule:
            break
        }
    }

    /// Rule bottom − content top (positive = clear).
    static func gapAbove(contentTop: CGFloat, ruleOffset: CGFloat, ruleThickness: CGFloat) -> CGFloat {
        (ruleOffset - ruleThickness / 2) - contentTop
    }

    /// Content bottom − rule top when content is below the rule (positive = clear).
    static func gapBelow(contentBottom: CGFloat, ruleOffset: CGFloat, ruleThickness: CGFloat) -> CGFloat {
        contentBottom - (ruleOffset + ruleThickness / 2)
    }
}
