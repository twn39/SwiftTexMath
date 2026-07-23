import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Font MATH-table / metrics checks adapted from swiftui-math `FontMetricsTests`
/// and iosMath `MTFontMathTable` / `MTFontManager` tests.
@Suite("Font metrics table")
struct FontMetricsTableTests {
    @Test func latinModernLoadsConstants() {
        let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20))
        #expect(metrics != nil)
        let m = metrics!
        #expect(m.axisHeight > 0)
        #expect(abs(m.mathUnit - 20.0 / 18.0) < 1e-9)
        #expect(m.constant(named: "AxisHeight") == m.axisHeight)
        #expect(m.accentBaseHeight > 0)
        #expect(m.minConnectorOverlap >= 0)
    }

    @Test func parenHasVerticalVariants() throws {
        let metrics = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)))
        let glyph = metrics.glyph(for: "(")
        let variants = metrics.verticalVariants(for: glyph)
        #expect(variants.count >= 2)
        #expect(variants.contains(glyph) || variants.first != 0)
    }

    @Test func italicCorrectionFiniteForItalicLetter() throws {
        let metrics = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)))
        let corr = metrics.italicCorrection(forNucleus: "f")
        #expect(corr.isFinite)
        #expect(corr >= 0)
    }

    @Test func topAccentAdjustmentFinite() throws {
        let metrics = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)))
        let glyph = metrics.glyph(for: "x")
        let adj = metrics.topAccentAdjustment(for: glyph)
        #expect(adj.isFinite)
        #expect(adj >= 0)
    }

    @Test func bundledFontsLoadMathTables() {
        for name in MathFont.Name.allBundled {
            let metrics = FontRegistry.shared.metrics(for: MathFont(name: name, size: 20))
            #expect(metrics != nil, "failed to load \(name.rawValue)")
            #expect(metrics!.axisHeight > 0, "axisHeight for \(name.rawValue)")
        }
    }

    @Test func displayStyleSelectsLargerOperatorGlyph() throws {
        let metrics = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)))
        let base = metrics.glyph(for: "∑")
        let larger = metrics.largerGlyph(base, forDisplayStyle: true)
        let baseSize = metrics.measure(glyphs: [base])
        let largeSize = metrics.measure(glyphs: [larger])
        #expect(largeSize.ascent + largeSize.descent >= baseSize.ascent + baseSize.descent - 0.01)
    }
}
