import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Limit / large-operator regressions inspired by SwiftMath `LimitOperatorRegressionTests`.
@Suite("Large operator layout")
struct LargeOperatorLayoutTests {
    private func displayRenderer(style: MathStyle = .display) -> MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: style
            )
        )
    }

    private func collectGlyphText(_ node: DisplayNode, into texts: inout [String]) {
        switch node {
        case .glyphs(let run):
            if !run.text.isEmpty { texts.append(run.text) }
        case .list(let list):
            for child in list.children { collectGlyphText(child, into: &texts) }
        case .largeOperator(let op):
            if !op.nucleus.text.isEmpty { texts.append(op.nucleus.text) }
            if let upper = op.upperLimit {
                for child in upper.children { collectGlyphText(child, into: &texts) }
            }
            if let lower = op.lowerLimit {
                for child in lower.children { collectGlyphText(child, into: &texts) }
            }
        case .fraction(let frac):
            for child in frac.numerator.children { collectGlyphText(child, into: &texts) }
            for child in frac.denominator.children { collectGlyphText(child, into: &texts) }
        case .radical(let rad):
            if !rad.radicalGlyph.text.isEmpty { texts.append(rad.radicalGlyph.text) }
            for child in rad.radicand.children { collectGlyphText(child, into: &texts) }
            if let degree = rad.degree {
                for child in degree.children { collectGlyphText(child, into: &texts) }
            }
        case .line(let line):
            for child in line.inner.children { collectGlyphText(child, into: &texts) }
        case .colored(let colored):
            for child in colored.inner.children { collectGlyphText(child, into: &texts) }
        case .box(let box):
            for child in box.child.children { collectGlyphText(child, into: &texts) }
        case .stack(let stack):
            for child in stack.base.children { collectGlyphText(child, into: &texts) }
            if let over = stack.over {
                for child in over.children { collectGlyphText(child, into: &texts) }
            }
            if let under = stack.under {
                for child in under.children { collectGlyphText(child, into: &texts) }
            }
        case .rule:
            break
        }
    }

    private func firstLargeOp(_ display: DisplayList) -> LargeOperatorDisplay? {
        for child in display.children {
            if case .largeOperator(let op) = child { return op }
            if case .list(let list) = child {
                for nested in list.children {
                    if case .largeOperator(let op) = nested { return op }
                }
            }
        }
        return nil
    }

    @Test func limUsesLimitsDisplayInDisplayStyle() throws {
        let display = try displayRenderer().layout(latex: #"\lim_{x\to\infty}f(x)"#)
        let op = try #require(firstLargeOp(display))
        #expect(op.lowerLimit != nil)
        #expect(op.upperLimit == nil)
        #expect(op.nucleus.text.contains("lim") || op.nucleus.text == "lim")
        #expect(op.descent > op.nucleus.descent)
    }

    @Test func limNucleusNotDuplicatedInGlyphRuns() throws {
        let display = try displayRenderer().layout(latex: #"\lim_{x}y"#)
        var texts: [String] = []
        for child in display.children {
            collectGlyphText(child, into: &texts)
        }
        let limCount = texts.filter { $0 == "lim" || $0.contains("lim") }.count
        #expect(limCount == 1, "expected single lim nucleus, got \(texts)")
    }

    @Test func limTextStyleUsesSideScriptsNotLimitsDisplay() throws {
        let display = try displayRenderer(style: .text).layout(latex: #"\lim_{x}"#)
        #expect(firstLargeOp(display) == nil)
        // Side-script path: list or glyphs+script lists
        #expect(!display.children.isEmpty)
        #expect(display.descent > 0 || display.ascent > 0)
    }

    @Test func maxMinSupInfSameLimitsPathAsLim() throws {
        for cmd in [#"\max_{x}"#, #"\min_{x}"#, #"\sup_{x}"#, #"\inf_{x}"#] {
            let display = try displayRenderer().layout(latex: cmd)
            let op = try #require(firstLargeOp(display), "missing limits display for \(cmd)")
            #expect(op.lowerLimit != nil, "missing lower limit for \(cmd)")
        }
    }

    @Test func sumLimitsTallerThanBareSum() throws {
        let bare = try displayRenderer().layout(latex: #"\sum"#)
        let withLimits = try displayRenderer().layout(latex: #"\sum_{i=1}^{n}"#)
        #expect(withLimits.ascent + withLimits.descent > bare.ascent + bare.descent)
        let op = try #require(firstLargeOp(withLimits))
        #expect(op.lowerLimit != nil)
        #expect(op.upperLimit != nil)
    }

    @Test func displayIntegralLargerThanTextstyle() throws {
        let displayStyle = try displayRenderer(style: .display).layout(latex: #"\int_0^1"#)
        let textStyle = try displayRenderer(style: .text).layout(latex: #"\int_0^1"#)
        #expect(displayStyle.ascent > textStyle.ascent)
        #expect(displayStyle.width >= textStyle.width)
        // Integrals use side scripts (limits == false), not LargeOperatorDisplay.
        #expect(firstLargeOp(displayStyle) == nil)
        #expect(firstLargeOp(textStyle) == nil)
    }

    @Test func lowerLimitGapIsPositive() throws {
        let display = try displayRenderer().layout(latex: #"\lim_{x}"#)
        let op = try #require(firstLargeOp(display))
        let lower = try #require(op.lowerLimit)
        // Visual nucleus bottom after axis shift.
        let nucBottom = op.nucleus.descent + op.nucleus.shiftDown
        let gap = -lower.position.y - nucBottom - lower.ascent
        #expect(gap > 0.5, "lower limit gap should use MATH metrics, got \(gap)")
    }

    /// Side-script large ops (`\int`, text `\sum`) center on the math axis.
    @Test func sideScriptLargeOpCentersOnAxis() throws {
        guard let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)) else {
            Issue.record("missing metrics")
            return
        }
        let display = try displayRenderer().layout(latex: #"\int_0^1"#)
        // First child should be a list (base + scripts) or bare glyphs.
        func firstGlyphRun(_ node: DisplayNode) -> GlyphRun? {
            switch node {
            case .glyphs(let run): return run
            case .list(let list):
                for child in list.children {
                    if let run = firstGlyphRun(child) { return run }
                }
                return nil
            default: return nil
            }
        }
        let run = try #require(firstGlyphRun(.list(display)))
        let center = 0.5 * (run.ascent - run.descent) - run.shiftDown
        #expect(abs(center - metrics.axisHeight) <= 0.05, "∫ center \(center) vs axis \(metrics.axisHeight)")
        #expect(abs(run.shiftDown) > 0.01 || abs(0.5 * (run.ascent - run.descent) - metrics.axisHeight) <= 0.05)
    }

    @Test func textStyleSumSideScriptCentersOnAxis() throws {
        guard let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)) else {
            Issue.record("missing metrics")
            return
        }
        let display = try displayRenderer(style: .text).layout(latex: #"\sum_i"#)
        #expect(firstLargeOp(display) == nil)
        func firstGlyph(_ node: DisplayNode) -> GlyphRun? {
            switch node {
            case .glyphs(let r): return r
            case .list(let list):
                for c in list.children {
                    if let r = firstGlyph(c) { return r }
                }
                return nil
            default: return nil
            }
        }
        let run = try #require(firstGlyph(.list(display)))
        let visualTop = run.ascent - run.shiftDown
        let visualBottom = run.descent + run.shiftDown
        let center = (visualTop - visualBottom) / 2
        #expect(abs(center - metrics.axisHeight) <= 0.05)
    }
}
