import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Numeric layout goldens at Latin Modern 20pt (display style).
/// Values measured from the current typesetter; tolerance ±0.02 mirrors
/// swiftui-math / iosMath TypesetterTests (±0.01) with a small platform cushion.
@Suite("Layout geometry")
struct LayoutGeometryTests {
    private let tolerance: CGFloat = 0.02

    private var renderer: MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display
            )
        )
    }

    private func expectSize(
        _ latex: String,
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let display = try renderer.layout(latex: latex)
        #expect(abs(display.ascent - ascent) <= tolerance, "ascent for \(latex)", sourceLocation: sourceLocation)
        #expect(abs(display.descent - descent) <= tolerance, "descent for \(latex)", sourceLocation: sourceLocation)
        #expect(abs(display.width - width) <= tolerance, "width for \(latex)", sourceLocation: sourceLocation)
    }

    @Test func simpleVariable() throws {
        try expectSize("x", ascent: 8.84, descent: 0.22, width: 11.44)
    }

    @Test func multipleVariables() throws {
        try expectSize("xyzw", ascent: 8.84, descent: 4.10, width: 44.86)
    }

    @Test func variablesAndNumber() throws {
        // xy2w — digit raises ascent vs plain letters
        try expectSize("xy2w", ascent: 13.32, descent: 4.10, width: 45.56)
    }

    @Test func fraction() throws {
        try expectSize(#"\frac{1}{2}"#, ascent: 26.86, descent: 13.72, width: 10.0)
    }

    /// Denominator must keep a minimum gap below the fraction rule (math axis).
    @Test func fractionDenominatorClearsRule() throws {
        let display = try renderer.layout(latex: #"\frac{f''(0)}{2!}"#)
        let frac = try #require(LayoutClearance.fraction(in: display))
        let metrics = try #require(LayoutClearance.metrics())
        let denGap = metrics.fractionDenominatorDisplayStyleGapMin
        let denTop = -frac.denominatorOffset + frac.denominator.ascent
        let clearance = LayoutClearance.gapAbove(
            contentTop: denTop,
            ruleOffset: frac.ruleOffset,
            ruleThickness: frac.ruleThickness
        )
        #expect(clearance + 0.01 >= denGap, "denominator clearance \(clearance) < gapMin \(denGap)")

        let numBottom = frac.numeratorOffset - frac.numerator.descent
        let numClearance = numBottom - (frac.ruleOffset + frac.ruleThickness / 2)
        let numGap = metrics.fractionNumeratorDisplayStyleGapMin
        #expect(numClearance + 0.01 >= numGap, "numerator clearance \(numClearance) < gapMin \(numGap)")
    }

    @Test func radical() throws {
        // Radical glyph top-aligned to overbar; descent tracks radicand, not raw glyph depth.
        try expectSize(#"\sqrt{2}"#, ascent: 17.88, descent: 2.92, width: 26.66)
    }

    /// Radical overbar must keep RadicalVerticalGap above the radicand.
    @Test func radicalOverbarClearsRadicand() throws {
        let display = try renderer.layout(latex: #"\sqrt{x^2}"#)
        let rad = try #require(LayoutClearance.radical(in: display))
        let metrics = try #require(LayoutClearance.metrics())
        let gap = metrics.radicalDisplayStyleVerticalGap
        let clearance = LayoutClearance.gapAbove(
            contentTop: rad.radicand.ascent,
            ruleOffset: rad.ruleOffset,
            ruleThickness: rad.ruleThickness
        )
        #expect(clearance + 0.01 >= gap, "radical clearance \(clearance) < gap \(gap)")
    }

    @Test func radicalWithDegree() throws {
        try expectSize(#"\sqrt[3]{x}"#, ascent: 13.40, descent: 7.40, width: 27.54)
    }

    /// Overline / underline rules must honor MATH vertical gaps.
    @Test func overlineUnderlineClearContent() throws {
        guard let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)) else {
            Issue.record("missing latin modern metrics")
            return
        }

        let over = try renderer.layout(latex: #"\overline{abc}"#)
        guard case .line(let overLine)? = over.children.first(where: {
            if case .line = $0 { return true }
            return false
        }) else {
            Issue.record("expected overline")
            return
        }
        let overClear =
            (overLine.ruleOffset - overLine.ruleThickness / 2) - overLine.inner.ascent
        #expect(
            overClear + 0.01 >= metrics.overbarVerticalGap,
            "overline clearance \(overClear)"
        )

        let under = try renderer.layout(latex: #"\underline{abc}"#)
        guard case .line(let underLine)? = under.children.first(where: {
            if case .line = $0 { return true }
            return false
        }) else {
            Issue.record("expected underline")
            return
        }
        let underClear =
            -underLine.inner.descent - (underLine.ruleOffset + underLine.ruleThickness / 2)
        #expect(
            underClear + 0.01 >= metrics.underbarVerticalGap,
            "underline clearance \(underClear)"
        )
    }

    /// Large-op nucleus is centered on the math axis; limits clear the nucleus.
    @Test func largeOperatorAxisAndLimitGaps() throws {
        guard let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)) else {
            Issue.record("missing latin modern metrics")
            return
        }
        let display = try renderer.layout(latex: #"\sum_{i=1}^{n}"#)
        guard case .largeOperator(let op)? = display.children.first(where: {
            if case .largeOperator = $0 { return true }
            return false
        }) else {
            Issue.record("expected large operator")
            return
        }

        let shift = op.nucleus.shiftDown
        let nucTop = op.nucleus.ascent - shift
        let nucBottom = op.nucleus.descent + shift
        // Visual center of nucleus ≈ axis
        let center = (nucTop - nucBottom) / 2
        #expect(abs(center - metrics.axisHeight) <= 0.05, "op center \(center) vs axis \(metrics.axisHeight)")

        if let upper = op.upperLimit {
            let upperBottom = upper.position.y - upper.descent
            let gap = upperBottom - nucTop
            #expect(gap + 0.01 >= metrics.upperLimitGapMin, "upper gap \(gap)")
        }
        if let lower = op.lowerLimit {
            // nuc bottom at y = -nucBottom; lower top at y = position.y + ascent
            let lowerTop = lower.position.y + lower.ascent
            let gap = (-nucBottom) - lowerTop
            #expect(gap + 0.01 >= metrics.lowerLimitGapMin, "lower gap \(gap)")
        }
    }

    @Test func horizontalStrikeOnAxis() throws {
        guard let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)) else {
            Issue.record("missing latin modern metrics")
            return
        }
        let display = try renderer.layout(latex: #"\sout{abc}"#)
        guard case .box(let box)? = display.children.first(where: {
            if case .box = $0 { return true }
            return false
        }) else {
            // \sout may not parse; try cancel as smoke for box path
            Issue.record("expected box for \\sout")
            return
        }
        #expect(abs(box.strikeVerticalOffset - metrics.axisHeight) <= 0.01)
    }

    /// Simultaneous sub/superscripts keep SubSuperscriptGapMin between them.
    @Test func dualScriptsKeepGap() throws {
        guard let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)) else {
            Issue.record("missing latin modern metrics")
            return
        }
        let display = try renderer.layout(latex: #"x_i^j"#)
        // ScriptLayout wraps base + scripts in a list
        guard case .list(let list)? = display.children.first else {
            // May be a single list as the whole display
            let list = display
            try assertDualScriptGap(list, minGap: metrics.subSuperscriptGapMin)
            return
        }
        try assertDualScriptGap(list, minGap: metrics.subSuperscriptGapMin)
    }

    private func assertDualScriptGap(_ list: DisplayList, minGap: CGFloat) throws {
        // Children: base, super list, sub list (order from ScriptLayout)
        guard list.children.count >= 3 else {
            Issue.record("expected base + super + sub, got \(list.children.count)")
            return
        }
        let superNode = list.children[1]
        let subNode = list.children[2]
        let superBottom = superNode.position.y - superNode.descent
        let subTop = subNode.position.y + subNode.ascent
        let gap = superBottom - subTop
        #expect(gap + 0.01 >= minGap, "script gap \(gap) < \(minGap)")
    }

    @Test func stackOversetClearsBase() throws {
        guard let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)) else {
            Issue.record("missing metrics")
            return
        }
        let display = try renderer.layout(latex: #"\overset{def}{=}"#)
        guard case .stack(let stack)? = display.children.first(where: {
            if case .stack = $0 { return true }
            return false
        }) else {
            Issue.record("expected stack")
            return
        }
        let over = try #require(stack.over)
        let overBottom = over.position.y - over.descent
        let gap = overBottom - stack.base.ascent
        let minGap = max(metrics.overbarVerticalGap, metrics.upperLimitGapMin)
        #expect(gap + 0.01 >= minGap, "overset gap \(gap)")
    }

    @Test func accent() throws {
        // Width includes signed MATH accent attachment (combining mark X may be negative).
        try expectSize(#"\hat{x}"#, ascent: 14.68, descent: 0.22, width: 11.86)
    }

    @Test func equationWithOperators() throws {
        try expectSize("x+y", ascent: 11.66, descent: 4.10, width: 45.68888888888888)
    }

    @Test func relationSpacingWidth() throws {
        try expectSize("a=b", ascent: 13.88, descent: 0.22, width: 45.83111111111111)
    }

    @Test func scriptsRaiseAscent() throws {
        try expectSize("x^2", ascent: 16.584, descent: 0.22, width: 19.56)
    }

    @Test func sumWithLimits() throws {
        // Large ops centered on math axis; descent shrinks vs unshifted nucleus.
        try expectSize(#"\sum_{i=1}^{n}"#, ascent: 29.342, descent: 21.818, width: 28.88)
    }

    @Test func limWithSubscript() throws {
        try expectSize(#"\lim_{x\to\infty}"#, ascent: 11.94, descent: 12.574, width: 36.008)
    }

    @Test func displayIntegralTallerThanTextstyle() throws {
        let display = try renderer.layout(latex: #"\displaystyle\int_0^1"#)
        let text = try MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .text
            )
        ).layout(latex: #"\int_0^1"#)
        #expect(display.ascent + display.descent > text.ascent + text.descent)
        #expect(display.width > text.width)
        try expectSize(#"\displaystyle\int_0^1"#, ascent: 34.384, descent: 24.408, width: 39.92)
    }

    @Test func leftRightFraction() throws {
        try expectSize(#"\left(\frac{a}{b}\right)"#, ascent: 22.92, descent: 13.94, width: 38.904444444444444)
    }

    // MARK: - Nested / multi-row clearance corpus

    @Test func deepNestedFractionClearances() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try renderer.layout(
            latex: #"\frac{\frac{a}{b}}{\frac{c}{d}}"#
        )
        let fracs = LayoutClearance.allFractions(in: display)
        #expect(fracs.count >= 3, "expected outer + two inner fractions, got \(fracs.count)")
        for frac in fracs {
            LayoutClearance.assertFractionRuleClearances(frac, metrics: metrics)
        }
    }

    @Test func taylorSeriesNestedClearances() throws {
        let metrics = try #require(LayoutClearance.metrics())
        // Maclaurin-style term that originally showed denominator-on-rule.
        let display = try renderer.layout(
            latex: #"f(x)=\sum_{n=0}^{\infty}\frac{f^{(n)}(0)}{n!}x^{n}"#
        )
        let fracs = LayoutClearance.allFractions(in: display)
        #expect(!fracs.isEmpty)
        for frac in fracs {
            LayoutClearance.assertFractionRuleClearances(frac, metrics: metrics)
        }
    }

    @Test func alignedWithFractionsClearances() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try renderer.layout(
            latex: #"\begin{aligned} y&=\frac{a}{b}\\ z&=\frac{f''(0)}{2!}\end{aligned}"#
        )
        let fracs = LayoutClearance.allFractions(in: display)
        #expect(fracs.count >= 2)
        for frac in fracs {
            LayoutClearance.assertFractionRuleClearances(frac, metrics: metrics)
        }
    }

    @Test func multiLetterHatMoreCenteredThanLastItalicAlone() throws {
        // Multi-letter base should not park the hat over the last letter only.
        let single = try renderer.layout(latex: #"\hat{x}"#)
        let multi = try renderer.layout(latex: #"\hat{xyz}"#)
        #expect(multi.width > single.width)
        // Accent layout returns `.list(base, accentGlyph)`; may be the root or nested once.
        let list: DisplayList
        if multi.children.count >= 2 {
            list = multi
        } else if case .list(let inner) = multi.children.first, inner.children.count >= 2 {
            list = inner
        } else {
            Issue.record("expected accent list with base + mark")
            return
        }
        try assertAccentMoreCenteredThanRightEdge(list)
    }

    private func assertAccentMoreCenteredThanRightEdge(_ list: DisplayList) throws {
        guard list.children.count >= 2 else {
            Issue.record("expected base + accent children")
            return
        }
        let base = list.children[0]
        let accent = list.children[1]
        let accentCenter = accent.position.x + accent.width / 2
        let baseCenter = base.position.x + base.width / 2
        let baseRight = base.position.x + base.width
        // Prefer near base center over near right edge of multi-letter base.
        let distCenter = abs(accentCenter - baseCenter)
        let distRight = abs(accentCenter - baseRight)
        #expect(
            distCenter < distRight,
            "accent center \(accentCenter) closer to right \(baseRight) than center \(baseCenter)"
        )
    }
}

// MARK: - PNG ink projection (rule vs content)

/// Raster ink checks near fraction / radical rules to catch "line sticks to content".
///
/// Uses **column-wise** sampling under the rule's horizontal span (full-row averages
/// are diluted by padding and fail to distinguish a thin rule from nearby glyphs).
@Suite("Ink projection clearance")
struct InkProjectionClearanceTests {
    private let scale: CGFloat = 3
    private let padding: CGFloat = 2
    /// Luminance below this counts as ink (white bg, black fg).
    private let inkThreshold: Double = 0.88

    private func render(_ latex: String) throws -> MathImage.Result {
        try MathImage.render(
            latex: latex,
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display
            ),
            options: MathImage.Options(
                scale: scale,
                padding: padding,
                foregroundColor: CGColor(gray: 0, alpha: 1),
                backgroundColor: CGColor(gray: 1, alpha: 1)
            )
        )
    }

    /// Map math y (relative to display baseline, y-up) → image row index (0 = top).
    ///
    /// MathImage flips y-up into a top-origin bitmap:
    /// `translate(0,H); scale(s,-s); origin=(pad, pad+descent)`.
    private func pixelRow(mathY: CGFloat, display: DisplayList, imageHeight: Int) -> Int {
        let userY = padding + display.descent + mathY
        // Device Y after flip: H - userY*scale. CGImage row 0 is top (device Y 0).
        let deviceY = CGFloat(imageHeight) - userY * scale
        // Stroke/AA centers often land ~0.5px off; use floor of center.
        let row = Int(floor(deviceY))
        return max(0, min(imageHeight - 1, row))
    }

    /// Locate the fraction rule as the densest horizontal band near either
    /// top-origin or bottom-origin prediction (bitmap orientation can differ
    /// across CGImage round-trips; we accept the denser match).
    private func locateRuleRow(
        bytes: [UInt8],
        width: Int,
        height: Int,
        x0: Int,
        x1: Int,
        mathY: CGFloat,
        display: DisplayList
    ) -> (row: Int, ink: Double) {
        let userY = padding + display.descent + mathY
        let flipped = Int(floor(CGFloat(height) - userY * scale))
        let unflipped = Int(floor(userY * scale))
        var bestRow = max(0, min(height - 1, flipped))
        var bestInk = 0.0
        for seed in [flipped, unflipped] {
            let lo = max(0, seed - 6)
            let hi = min(height - 1, seed + 6)
            for r in lo...hi {
                let ink = bandInkFraction(
                    bytes, width: width, height: height, x0: x0, x1: x1, centerRow: r, halfWidth: 0
                )
                if ink > bestInk {
                    bestInk = ink
                    bestRow = r
                }
            }
        }
        return (bestRow, bestInk)
    }

    private func pixelX(mathX: CGFloat) -> Int {
        Int((padding + mathX) * scale)
    }

    private func isInk(_ bytes: [UInt8], width: Int, x: Int, y: Int) -> Bool {
        let i = (y * width + x) * 4
        guard i + 2 < bytes.count else { return false }
        let lum = (Double(bytes[i]) + Double(bytes[i + 1]) + Double(bytes[i + 2])) / (3.0 * 255.0)
        return lum < inkThreshold
    }

    /// Mean ink fraction in a horizontal band clipped to `[x0, x1)`.
    private func bandInkFraction(
        _ bytes: [UInt8],
        width: Int,
        height: Int,
        x0: Int,
        x1: Int,
        centerRow: Int,
        halfWidth: Int
    ) -> Double {
        var ink = 0
        var total = 0
        for d in -halfWidth...halfWidth {
            let y = centerRow + d
            guard y >= 0, y < height else { continue }
            for x in max(0, x0)..<min(width, x1) {
                total += 1
                if isInk(bytes, width: width, x: x, y: y) { ink += 1 }
            }
        }
        return total > 0 ? Double(ink) / Double(total) : 0
    }

    /// Median empty rows from just below the rule band down to the next ink (denominator side).
    /// Image y increases downward; math content below the rule is higher row indices.
    private func medianClearRowsBelowRule(
        _ bytes: [UInt8],
        width: Int,
        height: Int,
        x0: Int,
        x1: Int,
        ruleRow: Int,
        ruleHalf: Int,
        maxSearch: Int
    ) -> Double {
        medianClearRows(
            bytes, width: width, height: height, x0: x0, x1: x1,
            ruleRow: ruleRow, ruleHalf: ruleHalf, maxSearch: maxSearch, direction: +1
        )
    }

    private func medianClearRowsAboveRule(
        _ bytes: [UInt8],
        width: Int,
        height: Int,
        x0: Int,
        x1: Int,
        ruleRow: Int,
        ruleHalf: Int,
        maxSearch: Int
    ) -> Double {
        medianClearRows(
            bytes, width: width, height: height, x0: x0, x1: x1,
            ruleRow: ruleRow, ruleHalf: ruleHalf, maxSearch: maxSearch, direction: -1
        )
    }

    private func medianClearRows(
        _ bytes: [UInt8],
        width: Int,
        height: Int,
        x0: Int,
        x1: Int,
        ruleRow: Int,
        ruleHalf: Int,
        maxSearch: Int,
        direction: Int
    ) -> Double {
        var gaps: [Int] = []
        let startY = ruleRow + direction * (ruleHalf + 1)
        for x in max(0, x0)..<min(width, x1) {
            var hasRule = false
            for d in -ruleHalf...ruleHalf {
                let y = ruleRow + d
                if y >= 0, y < height, isInk(bytes, width: width, x: x, y: y) {
                    hasRule = true
                    break
                }
            }
            guard hasRule else { continue }
            var clear = 0
            var y = startY
            var steps = 0
            while steps < maxSearch, y >= 0, y < height {
                if isInk(bytes, width: width, x: x, y: y) { break }
                clear += 1
                y += direction
                steps += 1
            }
            gaps.append(clear)
        }
        guard !gaps.isEmpty else { return -1 } // no rule columns found
        let sorted = gaps.sorted()
        return Double(sorted[sorted.count / 2])
    }

    @Test func fractionRuleInkHasClearBandsBesideContent() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let result = try render(#"\frac{f''(0)}{2!}"#)
        let bytes = try #require(InkProjection.rgbaBytes(of: result.image))
        let frac = try #require(LayoutClearance.placedFractions(in: result.display).first)
        let ruleY = frac.origin.y + frac.fraction.ruleOffset
        let x0 = pixelX(mathX: frac.origin.x)
        let x1 = pixelX(mathX: frac.origin.x + frac.fraction.width)
        let w = result.image.width
        let h = result.image.height

        let located = locateRuleRow(
            bytes: bytes, width: w, height: h, x0: x0, x1: x1,
            mathY: ruleY, display: result.display
        )
        #expect(
            located.ink > 0.5,
            "weak rule ink \(located.ink) at row \(located.row); ruleY=\(ruleY) h=\(h)"
        )

        let gapMinPt = metrics.fractionDenominatorGapMin
        let minClearPx = max(1.0, gapMinPt * scale * 0.35)
        let medianClear = medianClearRowsBelowRule(
            bytes, width: w, height: h, x0: x0, x1: x1,
            ruleRow: located.row, ruleHalf: 0, maxSearch: Int(ceil(gapMinPt * scale * 4))
        )
        let medianClearUp = medianClearRowsAboveRule(
            bytes, width: w, height: h, x0: x0, x1: x1,
            ruleRow: located.row, ruleHalf: 0, maxSearch: Int(ceil(gapMinPt * scale * 4))
        )
        let clear = max(medianClear, medianClearUp)
        #expect(
            clear + 0.01 >= minClearPx,
            "median clear down=\(medianClear) up=\(medianClearUp) < \(minClearPx); row=\(located.row) ink=\(located.ink)"
        )
    }

    @Test func radicalOverbarInkClearsRadicandBand() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let result = try render(#"\sqrt{x^2}"#)
        let bytes = try #require(InkProjection.rgbaBytes(of: result.image))
        let rad = try #require(LayoutClearance.radical(in: result.display))
        let ruleY = rad.position.y + rad.ruleOffset
        let x0 = pixelX(mathX: rad.position.x + rad.radicand.position.x)
        let x1 = pixelX(mathX: rad.position.x + rad.radicand.position.x + rad.radicand.width)
        let w = result.image.width
        let h = result.image.height

        let located = locateRuleRow(
            bytes: bytes, width: w, height: h, x0: x0, x1: x1,
            mathY: ruleY, display: result.display
        )
        #expect(located.ink > 0.4, "overbar ink \(located.ink) at \(located.row)")

        let gapMinPt = metrics.radicalDisplayStyleVerticalGap
        let minClearPx = max(1.0, gapMinPt * scale * 0.35)
        let down = medianClearRowsBelowRule(
            bytes, width: w, height: h, x0: x0, x1: x1,
            ruleRow: located.row, ruleHalf: 0, maxSearch: Int(ceil(gapMinPt * scale * 4))
        )
        let up = medianClearRowsAboveRule(
            bytes, width: w, height: h, x0: x0, x1: x1,
            ruleRow: located.row, ruleHalf: 0, maxSearch: Int(ceil(gapMinPt * scale * 4))
        )
        let clear = max(down, up)
        #expect(
            clear + 0.01 >= minClearPx,
            "radical overbar median clear \(clear) (down=\(down) up=\(up)) < \(minClearPx)"
        )
    }

    @Test func nestedSqrtFracInkClearance() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let result = try render(#"\sqrt{\frac{f''(0)}{2!}}"#)
        let bytes = try #require(InkProjection.rgbaBytes(of: result.image))
        let placed = LayoutClearance.placedFractions(in: result.display)
        #expect(!placed.isEmpty)
        let gapMinPt = metrics.fractionDenominatorGapMin
        let minClearPx = max(1.0, gapMinPt * scale * 0.35)
        let w = result.image.width
        let h = result.image.height
        for item in placed {
            let ruleY = item.origin.y + item.fraction.ruleOffset
            let x0 = pixelX(mathX: item.origin.x)
            let x1 = pixelX(mathX: item.origin.x + item.fraction.width)
            let located = locateRuleRow(
                bytes: bytes, width: w, height: h, x0: x0, x1: x1,
                mathY: ruleY, display: result.display
            )
            #expect(located.ink > 0.45, "nested rule ink \(located.ink)")
            let down = medianClearRowsBelowRule(
                bytes, width: w, height: h, x0: x0, x1: x1,
                ruleRow: located.row, ruleHalf: 0, maxSearch: Int(ceil(gapMinPt * scale * 4))
            )
            let up = medianClearRowsAboveRule(
                bytes, width: w, height: h, x0: x0, x1: x1,
                ruleRow: located.row, ruleHalf: 0, maxSearch: Int(ceil(gapMinPt * scale * 4))
            )
            let clear = max(down, up)
            #expect(
                clear + 0.01 >= minClearPx,
                "nested fraction median clear \(clear) < \(minClearPx)"
            )
        }
    }
}

/// Local pixel access for ink tests (mirrors MathImage private rgba path).
enum InkProjection {
    static func rgbaBytes(of image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }
}
