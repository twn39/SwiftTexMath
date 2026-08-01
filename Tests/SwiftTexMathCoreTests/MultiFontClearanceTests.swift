import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Phase-2: relative MATH clearances across multiple bundled fonts (not absolute pt goldens).
@Suite("Multi-font clearance")
struct MultiFontClearanceTests {
    /// Primary pair for dual-track geometry (LM + XITS).
    static let primaryFonts: [MathFont.Name] = [.latinModern, .xits]

    /// Smoke set across the bundle (axis + simple fraction).
    static let smokeFonts: [MathFont.Name] = [
        .latinModern, .xits, .asana, .libertinus, .termes
    ]

    private func renderer(name: MathFont.Name, style: MathStyle = .display) -> MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: name, size: 20),
                style: style
            )
        )
    }

    private func metrics(name: MathFont.Name) throws -> FontMetrics {
        try #require(FontRegistry.shared.metrics(for: MathFont(name: name, size: 20)))
    }

    // MARK: - Dual-track (LM + XITS)

    @Test(arguments: Self.primaryFonts)
    func displayFractionClearsRule(_ name: MathFont.Name) throws {
        let m = try metrics(name: name)
        let display = try renderer(name: name).layout(latex: #"\frac{1}{2}"#)
        let frac = try #require(LayoutClearance.fraction(in: display))
        LayoutClearance.assertFractionRuleClearances(frac, metrics: m, style: .display)
    }

    @Test(arguments: Self.primaryFonts)
    func displayRadicalClearsRadicand(_ name: MathFont.Name) throws {
        let m = try metrics(name: name)
        let display = try renderer(name: name).layout(latex: #"\sqrt{x}"#)
        let rad = try #require(LayoutClearance.radical(in: display))
        LayoutClearance.assertRadicalClearance(rad, metrics: m, style: .display)
    }

    @Test(arguments: Self.primaryFonts)
    func nestedSqrtFracClears(_ name: MathFont.Name) throws {
        let m = try metrics(name: name)
        let display = try renderer(name: name).layout(latex: #"\sqrt{\frac{a}{b}}"#)
        let rad = try #require(LayoutClearance.radical(in: display))
        LayoutClearance.assertRadicalClearance(rad, metrics: m, style: .display)
        for f in LayoutClearance.allFractions(in: display) {
            LayoutClearance.assertFractionRuleClearances(f, metrics: m)
        }
    }

    @Test(arguments: Self.primaryFonts)
    func binomStackGap(_ name: MathFont.Name) throws {
        let m = try metrics(name: name)
        let display = try renderer(name: name).layout(latex: #"\binom{n}{k}"#)
        let frac = try #require(LayoutClearance.fraction(in: display))
        #expect(frac.ruleThickness < 0.05)
        LayoutClearance.assertStackFractionClearance(frac, metrics: m, style: .display)
    }

    @Test(arguments: Self.primaryFonts)
    func dualScriptsKeepGap(_ name: MathFont.Name) throws {
        let m = try metrics(name: name)
        let display = try renderer(name: name).layout(latex: #"x_i^j"#)
        #expect(display.ascent > 0 && display.descent > 0)
        // Soft: height should exceed plain x.
        let plain = try renderer(name: name).layout(latex: "x")
        #expect(display.ascent + display.descent > plain.ascent + plain.descent)
        #expect(m.subSuperscriptGapMin >= 0)
    }

    @Test(arguments: Self.primaryFonts)
    func sumLimitsPositiveExtent(_ name: MathFont.Name) throws {
        let display = try renderer(name: name).layout(latex: #"\sum_{i=1}^{n}"#)
        #expect(display.ascent > 8 && display.descent > 5)
        #expect(display.width > 10)
    }

    // MARK: - Smoke across more fonts

    @Test(arguments: Self.smokeFonts)
    func simpleLayoutsPositiveSize(_ name: MathFont.Name) throws {
        let r = renderer(name: name)
        for latex in [#"a+b"#, #"\frac{1}{2}"#, #"\sqrt{2}"#, #"\left(\frac{a}{b}\right)"#] {
            let d = try r.layout(latex: latex)
            #expect(
                d.width > 0 && d.ascent + d.descent > 0,
                "\(name.rawValue) empty for \(latex)"
            )
        }
    }

    @Test(arguments: Self.smokeFonts)
    func axisHeightPositive(_ name: MathFont.Name) throws {
        let m = try metrics(name: name)
        #expect(m.axisHeight > 0)
        #expect(m.fractionRuleThickness >= 0)
        #expect(m.radicalVerticalGap(for: .display) >= 0)
    }

    /// Absolute sizes must differ across fonts (guards against hardcoded LM-only layout).
    @Test func latinModernAndXitsDifferOnQuadratic() throws {
        let lm = try renderer(name: .latinModern).layout(
            latex: #"x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}"#
        )
        let xits = try renderer(name: .xits).layout(
            latex: #"x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}"#
        )
        // Both valid; widths need not match.
        #expect(lm.width > 50 && xits.width > 50)
        let same =
            abs(lm.width - xits.width) < 0.01
            && abs(lm.ascent - xits.ascent) < 0.01
            && abs(lm.descent - xits.descent) < 0.01
        #expect(
            !same,
            "LM and XITS identical metrics — possible font selection bug"
        )
    }
}
