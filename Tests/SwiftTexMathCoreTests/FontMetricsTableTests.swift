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

    @Test func horizontalAssemblyCoversWideTarget() throws {
        let metrics = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)))
        // U+2192 arrowright has only a couple of h-variants but a full h_assembly.
        let arrow = metrics.glyph(for: "\u{2192}")
        let target: CGFloat = 80
        let variantOnly = metrics.findHorizontalVariantSized(arrow, coveringWidth: target)
        let sized = metrics.sizedHorizontal(arrow, coveringWidth: target)
        #expect(sized.width + 0.5 >= target, "assembled width \(sized.width) < \(target)")
        // When variants cannot cover the target, assembly should grow past the variant floor.
        if variantOnly.width + 0.1 < target {
            #expect(sized.glyphIDs.count >= 2, "expected multi-part assembly, got \(sized.glyphIDs.count)")
            #expect(!sized.offsetsX.isEmpty)
            #expect(sized.offsetsX.count == sized.glyphIDs.count)
        }
    }

    @Test func flattenedAccentBaseHeightIsPositive() throws {
        let metrics = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)))
        #expect(metrics.flattenedAccentBaseHeight > metrics.accentBaseHeight)
    }

    @Test func belowAccentGlyphHasAttachmentEntry() throws {
        let metrics = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)))
        let below = metrics.glyphID(named: "tildebelowcmb")
        #expect(below != 0)
        #expect(metrics.hasAccentAttachment(for: below))
        // Attachment is finite (may be negative for combining forms).
        let x = metrics.accentAttachmentX(for: below)
        #expect(x.isFinite)
    }

    @Test func verticalAssemblyExtenderStretchIsMonotonic() throws {
        let metrics = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)))
        let paren = metrics.glyph(for: "(")
        let short = metrics.sizedDelimiter(forNucleus: "(", height: 30)
        let tall = metrics.sizedDelimiter(forNucleus: "(", height: 80)
        #expect(tall.ascent + tall.descent + 0.01 >= short.ascent + short.descent)
        // Very tall targets should multi-part assemble when variants run out.
        if tall.glyphIDs.count > 1 {
            #expect(tall.offsetsY.count == tall.glyphIDs.count)
        }
        _ = paren
    }

    /// Newly wired MATH constants must be present and positive on Latin Modern @ 20pt.
    @Test func newlyWiredMathConstantsArePositiveOnLatinModern() throws {
        let m = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)))
        #expect(m.delimitedSubFormulaMinHeight > 10)
        #expect(m.displayOperatorMinHeight > 10)
        #expect(m.stackTopDisplayStyleShiftUp > 0)
        #expect(m.stackTopShiftUp > 0)
        #expect(m.stackBottomDisplayStyleShiftDown > 0)
        #expect(m.stackBottomShiftDown > 0)
        #expect(m.stackDisplayStyleGapMin > 0)
        #expect(m.stackGapMin > 0)
        #expect(m.stackGapMin(for: .display) == m.stackDisplayStyleGapMin)
        #expect(m.stackGapMin(for: .text) == m.stackGapMin)
        #expect(m.stretchStackGapAboveMin > 0)
        #expect(m.stretchStackGapBelowMin > 0)
        #expect(m.stretchStackTopShiftUp >= 0)
        #expect(m.stretchStackBottomShiftDown > 0)
        #expect(m.mathLeading > 0)
        // Display stack gap is typically larger than text stack gap.
        #expect(m.stackDisplayStyleGapMin + 0.01 >= m.stackGapMin)
    }
}
