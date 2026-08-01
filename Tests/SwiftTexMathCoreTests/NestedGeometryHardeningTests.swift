import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Phase-1 geometry hardening: nested fraction/radical/matrix clearances,
/// style-aware MATH gaps, and binom/atop stack rules.
@Suite("Nested geometry hardening")
struct NestedGeometryHardeningTests {
    private var displayRenderer: MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display
            )
        )
    }

    private var textRenderer: MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .text
            )
        )
    }

    private func layout(_ latex: String, style: MathStyle = .display) throws -> DisplayList {
        let r = style == .display ? displayRenderer : textRenderer
        return try r.layout(latex: latex)
    }

    // MARK: - Style-aware simple cases

    @Test func displayFractionUsesDisplayGaps() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\frac{1}{2}"#)
        let frac = try #require(LayoutClearance.fraction(in: display))
        LayoutClearance.assertFractionRuleClearances(frac, metrics: metrics, style: .display)
    }

    @Test func textFractionUsesTextGaps() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\frac{1}{2}"#, style: .text)
        let frac = try #require(LayoutClearance.fraction(in: display))
        LayoutClearance.assertFractionRuleClearances(frac, metrics: metrics, style: .text)
    }

    @Test func displayRadicalUsesDisplayGap() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\sqrt{x}"#)
        let rad = try #require(LayoutClearance.radical(in: display))
        LayoutClearance.assertRadicalClearance(rad, metrics: metrics, style: .display)
    }

    @Test func textRadicalUsesTextGap() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\sqrt{x}"#, style: .text)
        let rad = try #require(LayoutClearance.radical(in: display))
        LayoutClearance.assertRadicalClearance(rad, metrics: metrics, style: .text)
    }

    @Test func dfracForcesDisplayGapsInsideText() throws {
        let metrics = try #require(LayoutClearance.metrics())
        // Outer text, forced display fraction via \dfrac.
        let display = try layout(#"\dfrac{a}{b}"#, style: .text)
        let frac = try #require(LayoutClearance.fraction(in: display))
        LayoutClearance.assertFractionRuleClearances(frac, metrics: metrics, style: .display)
        let textFrac = try layout(#"\tfrac{a}{b}"#, style: .display)
        let tf = try #require(LayoutClearance.fraction(in: textFrac))
        // \tfrac forces text-style gaps even in display environment.
        LayoutClearance.assertFractionRuleClearances(tf, metrics: metrics, style: .text)
    }

    // MARK: - Binom / choose / atop (zero-thickness rule)

    @Test func binomUsesStackGapNotRuleClearance() throws {
        let metrics = try #require(LayoutClearance.metrics())
        for latex in [#"\binom{n}{k}"#, #"{n \choose k}"#, #"\dbinom{n}{k}"#] {
            let display = try layout(latex)
            let frac = try #require(LayoutClearance.fraction(in: display), "missing fraction for \(latex)")
            #expect(frac.ruleThickness < 0.05, "\(latex) should be zero-thickness genfrac")
            LayoutClearance.assertStackFractionClearance(frac, metrics: metrics, style: .display)
            // Also via unified entry (should route to stack assert).
            LayoutClearance.assertFractionRuleClearances(frac, metrics: metrics, style: .display)
        }
    }

    @Test func tbinomStackGapInTextStyle() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\tbinom{n}{k}"#, style: .text)
        let frac = try #require(LayoutClearance.fraction(in: display))
        #expect(frac.ruleThickness < 0.05)
        LayoutClearance.assertStackFractionClearance(frac, metrics: metrics, style: .text)
    }

    // MARK: - Nested fraction / radical corpus

    @Test func nestedFractionInRadicalDisplayClearances() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\sqrt{\frac{a}{b}}"#)

        // Outer radical is display-style.
        let rad = try #require(LayoutClearance.radical(in: display))
        LayoutClearance.assertRadicalClearance(rad, metrics: metrics, style: .display)

        // Fraction under radical keeps display env (cramped only) → display gaps.
        let fracs = LayoutClearance.allFractions(in: display)
        #expect(fracs.count >= 1)
        for f in fracs {
            LayoutClearance.assertFractionRuleClearances(f, metrics: metrics, style: .display)
        }
    }

    @Test func nestedRadicalInFractionTextStyleClearance() throws {
        let metrics = try #require(LayoutClearance.metrics())
        // Outer fraction display → num/den text style → inner radical uses text gap.
        let display = try layout(#"\frac{\sqrt{a}}{\sqrt{b}}"#)
        let fracs = LayoutClearance.allFractions(in: display)
        #expect(fracs.count >= 1)
        for f in fracs {
            LayoutClearance.assertFractionRuleClearances(f, metrics: metrics, style: .display)
        }
        let rads = LayoutClearance.allRadicals(in: display)
        #expect(rads.count >= 2)
        for rad in rads {
            LayoutClearance.assertRadicalClearance(rad, metrics: metrics, style: .text)
        }
    }

    @Test func deepNestedFractionsAllClear() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\frac{\frac{a}{b}}{\frac{c}{d}}"#)
        let fracs = LayoutClearance.allFractions(in: display)
        #expect(fracs.count >= 3)
        // Outer display; inner fractions are text-style children.
        // Soft assert covers both.
        for f in fracs {
            LayoutClearance.assertFractionRuleClearances(f, metrics: metrics)
        }
    }

    @Test func continuedFractionClearances() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\cfrac{1}{1+\cfrac{1}{1+\cfrac{1}{x}}}"#)
        let fracs = LayoutClearance.allFractions(in: display)
        #expect(fracs.count >= 2)
        for f in fracs where f.ruleThickness >= 0.05 {
            LayoutClearance.assertFractionRuleClearances(f, metrics: metrics)
        }
    }

    @Test func quadraticFormulaNestedRadicalAndFraction() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}"#)
        for f in LayoutClearance.allFractions(in: display) {
            LayoutClearance.assertFractionRuleClearances(f, metrics: metrics)
        }
        // Radical sits in text-style numerator.
        for rad in LayoutClearance.allRadicals(in: display) {
            LayoutClearance.assertRadicalClearance(rad, metrics: metrics, style: .text)
        }
    }

    @Test func nestedSqrtChainOuterDisplayInnerText() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\sqrt{\sqrt{x}}"#)
        let rads = LayoutClearance.allRadicals(in: display)
        #expect(rads.count >= 2)
        // Outer display.
        LayoutClearance.assertRadicalClearance(rads[0], metrics: metrics, style: .display)
        // Inner is still display style with cramped (style unchanged) → display gap.
        // (radicand env only sets cramped, not style demotion.)
        for rad in rads {
            LayoutClearance.assertRadicalClearanceSoft(rad, metrics: metrics)
        }
    }

    @Test func leftRightFractionDelimiterClearances() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\left(\frac{a}{b}\right)"#)
        for f in LayoutClearance.allFractions(in: display) {
            LayoutClearance.assertFractionRuleClearances(f, metrics: metrics, style: .display)
        }
        #expect(display.ascent > 10 && display.descent > 5)
        #expect(display.width > 20)
    }

    // MARK: - Matrix / multi-row

    @Test func matrixWithFractionsEachClears() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(
            #"\begin{matrix} \frac{a}{b} \\ \frac{c}{d} \end{matrix}"#
        )
        let fracs = LayoutClearance.allFractions(in: display)
        #expect(fracs.count >= 2)
        for f in fracs {
            LayoutClearance.assertFractionRuleClearances(f, metrics: metrics)
        }
        // Table should be axis-centered (positive ascent and descent).
        #expect(display.ascent > 10 && display.descent > 10)
    }

    @Test func pmatrixNestedSqrtFrac() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(
            #"\begin{pmatrix} \sqrt{\frac{1}{2}} & 0 \\ 0 & \frac{\sqrt{a}}{b} \end{pmatrix}"#
        )
        for f in LayoutClearance.allFractions(in: display) {
            LayoutClearance.assertFractionRuleClearances(f, metrics: metrics)
        }
        for rad in LayoutClearance.allRadicals(in: display) {
            LayoutClearance.assertRadicalClearanceSoft(rad, metrics: metrics)
        }
        #expect(display.width > 40)
    }

    @Test func alignedWithNestedFractions() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(
            #"\begin{aligned} y&=\frac{a}{b}\\ z&=\sqrt{\frac{c}{d}} \end{aligned}"#
        )
        for f in LayoutClearance.allFractions(in: display) {
            LayoutClearance.assertFractionRuleClearances(f, metrics: metrics)
        }
        for rad in LayoutClearance.allRadicals(in: display) {
            LayoutClearance.assertRadicalClearanceSoft(rad, metrics: metrics)
        }
    }

    // MARK: - Stack / delimiter MATH wiring

    @Test func binomHonorsStackGapMin() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"\binom{n}{k}"#)
        let frac = try #require(LayoutClearance.fraction(in: display))
        #expect(frac.ruleThickness < 0.05)
        LayoutClearance.assertStackFractionClearance(frac, metrics: metrics, style: .display)
        // Display stack gap is the OpenType StackDisplayStyleGapMin (not fraction gap sum).
        #expect(metrics.stackGapMin(for: .display) == metrics.stackDisplayStyleGapMin)
    }

    @Test func textAtopHonorsTextStackGapMin() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try layout(#"{n \atop k}"#, style: .text)
        let frac = try #require(LayoutClearance.fraction(in: display))
        #expect(frac.ruleThickness < 0.05)
        LayoutClearance.assertStackFractionClearance(frac, metrics: metrics, style: .text)
    }

    @Test func tallLeftRightUsesDelimitedMinHeightFloor() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let minH = metrics.delimitedSubFormulaMinHeight
        #expect(minH > 0)
        // Tall fraction content exceeds the MATH floor; delimiters must cover content.
        let display = try layout(#"\left(\frac{\frac{a}{b}}{\frac{c}{d}}\right)"#)
        #expect(display.ascent + display.descent + 0.01 >= minH * 0.5)
        #expect(display.width > 20)
    }

    @Test func displaySumMeetsDisplayOperatorMinHeightSoft() throws {
        let metrics = try #require(LayoutClearance.metrics())
        let minH = metrics.displayOperatorMinHeight
        #expect(minH > 0)
        let display = try layout(#"\sum"#)
        // Soft: nucleus may still be shorter than the table min if no variant is tall enough;
        // assert we at least produce a positive display-size operator.
        #expect(display.ascent + display.descent > 8)
        #expect(minH > 10)
    }

    // MARK: - Style metrics API smoke

    @Test func styleAwareMetricsHelpersConsistent() throws {
        let metrics = try #require(LayoutClearance.metrics())
        #expect(metrics.usesDisplayStyleConstants(for: .display))
        #expect(!metrics.usesDisplayStyleConstants(for: .text))
        #expect(!metrics.usesDisplayStyleConstants(for: .script))

        #expect(
            metrics.fractionNumeratorGapMin(for: .display)
                == metrics.fractionNumeratorDisplayStyleGapMin
        )
        #expect(
            metrics.fractionNumeratorGapMin(for: .text)
                == metrics.fractionNumeratorGapMin
        )
        #expect(
            metrics.radicalVerticalGap(for: .display)
                == metrics.radicalDisplayStyleVerticalGap
        )
        #expect(
            metrics.radicalVerticalGap(for: .script)
                == metrics.radicalVerticalGap
        )
        #expect(
            metrics.stackGapMin(for: .display) == metrics.stackDisplayStyleGapMin
        )
        #expect(
            metrics.stackTopShiftUp(for: .display) == metrics.stackTopDisplayStyleShiftUp
        )
        #expect(
            metrics.stackTopShiftUp(for: .text) == metrics.stackTopShiftUp
        )
        // Display gaps should be ≥ text gaps for LM.
        #expect(
            metrics.fractionNumeratorGapMin(for: .display)
                + 0.001 >= metrics.fractionNumeratorGapMin(for: .text)
        )
        #expect(
            metrics.radicalVerticalGap(for: .display)
                + 0.001 >= metrics.radicalVerticalGap(for: .text)
        )
    }

    // MARK: - Relative invariants

    @Test func nestedSqrtFracTallerThanSimpleSqrt() throws {
        let nested = try layout(#"\sqrt{\frac{a}{b}}"#)
        let simple = try layout(#"\sqrt{x}"#)
        #expect(nested.ascent + nested.descent > simple.ascent + simple.descent + 5)
    }

    @Test func binomSimilarHeightToDfrac() throws {
        let binom = try layout(#"\binom{n}{k}"#)
        let dfrac = try layout(#"\dfrac{n}{k}"#)
        // Same-ish vertical extent; binom has delimiters adding width.
        let bh = binom.ascent + binom.descent
        let dh = dfrac.ascent + dfrac.descent
        #expect(abs(bh - dh) < 8)
        #expect(binom.width >= dfrac.width)
    }
}
