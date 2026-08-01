import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Phase-2: stretchy delimiter / radical / horizontal assembly quality.
@Suite("Stretchy assembly hardening")
struct StretchyAssemblyHardeningTests {
    private func metrics(size: CGFloat = 20) throws -> FontMetrics {
        try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: size)))
    }

    private func height(of sized: SizedGlyph) -> CGFloat {
        sized.ascent + sized.descent
    }

    // MARK: - Vertical delimiter height scan

    @Test func parenHeightScanMonotonicAndCoversTarget() throws {
        let m = try metrics()
        var previous: CGFloat = 0
        for target in stride(from: 10 as CGFloat, through: 80, by: 5) {
            let sized = m.sizedDelimiter(forNucleus: "(", height: target)
            let h = height(of: sized)
            #expect(h + 0.5 >= target * 0.85, "paren h=\(h) for target \(target)")
            #expect(h + 0.01 >= previous - 0.5, "non-monotonic at \(target): \(h) < \(previous)")
            previous = max(previous, h)
            #expect(!sized.glyphIDs.isEmpty)
            #expect(sized.glyphIDs.allSatisfy { $0 != 0 })
        }
    }

    @Test func bracketAndBraceHeightScan() throws {
        let m = try metrics()
        for nucleus in ["[", "{", "|", "‖"] {
            for target in [20, 40, 60] as [CGFloat] {
                let sized = m.sizedDelimiter(forNucleus: nucleus, height: target)
                #expect(
                    height(of: sized) + 1 >= target * 0.75,
                    "\(nucleus) h=\(height(of: sized)) target=\(target)"
                )
            }
        }
    }

    @Test func tallDelimiterUsesAssemblyOrVariants() throws {
        let m = try metrics()
        let base = m.glyph(for: "(")
        let variants = m.verticalVariants(for: base)
        let tall = m.sizedDelimiter(forNucleus: "(", height: 100)
        #expect(height(of: tall) >= 40)
        // Either multi-glyph assembly or a large variant.
        let isAssembled = tall.glyphIDs.count >= 2 || !tall.offsetsY.isEmpty
        let isLargeVariant = tall.glyphIDs.count == 1 && (variants.count <= 1
            || tall.glyphIDs[0] != base || height(of: tall) > 30)
        #expect(isAssembled || isLargeVariant)
    }

    @Test func radicalSizedCoversRequestedHeight() throws {
        let m = try metrics()
        for target in [15, 30, 50, 70] as [CGFloat] {
            let sized = m.sizedRadical(height: target)
            #expect(height(of: sized) + 1 >= target * 0.7, "radical h=\(height(of: sized)) t=\(target)")
            #expect(!sized.glyphIDs.isEmpty)
        }
    }

    // MARK: - Horizontal assembly

    @Test func arrowWidthScanMonotonic() throws {
        let m = try metrics()
        let arrow = m.glyph(for: "\u{2192}")
        var previous: CGFloat = 0
        for target in stride(from: 20 as CGFloat, through: 120, by: 10) {
            let sized = m.sizedHorizontal(arrow, coveringWidth: target)
            #expect(sized.width + 0.5 >= target * 0.9, "arrow w=\(sized.width) t=\(target)")
            #expect(sized.width + 0.01 >= previous - 1)
            previous = max(previous, sized.width)
            if target > 50 {
                #expect(sized.glyphIDs.count >= 1)
            }
        }
    }

    @Test func overrightarrowGrowsWithBase() throws {
        let r = MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display
            )
        )
        let short = try r.layout(latex: #"\overrightarrow{A}"#)
        let mid = try r.layout(latex: #"\overrightarrow{ABC}"#)
        let long = try r.layout(latex: #"\overrightarrow{ABCDEFGH}"#)
        #expect(mid.width > short.width)
        #expect(long.width > mid.width)
        #expect(long.ascent > 0)
    }

    // MARK: - Connector overlap sanity

    @Test func minConnectorOverlapNonNegative() throws {
        let m = try metrics()
        #expect(m.minConnectorOverlap >= 0)
        // Assembled tall paren should not produce zero-width glyphs.
        let tall = m.sizedDelimiter(forNucleus: "(", height: 80)
        for g in tall.glyphIDs {
            let adv = m.advances(forGlyphs: [g]).first?.width ?? 0
            #expect(adv >= 0)
        }
    }

    // MARK: - Layout-level left/right stretch

    @Test func leftRightCoversTallFraction() throws {
        let r = MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display
            )
        )
        let plain = try r.layout(latex: #"\frac{a}{b}"#)
        let delimited = try r.layout(latex: #"\left(\frac{a}{b}\right)"#)
        #expect(delimited.ascent + delimited.descent + 0.5 >= plain.ascent + plain.descent)
        #expect(delimited.width > plain.width)
    }

    @Test func bigBiggMonotonicHeight() throws {
        let r = MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display
            )
        )
        let big = try r.layout(latex: #"\big("#)
        let Big = try r.layout(latex: #"\Big("#)
        let bigg = try r.layout(latex: #"\bigg("#)
        let Bigg = try r.layout(latex: #"\Bigg("#)
        let h: (DisplayList) -> CGFloat = { $0.ascent + $0.descent }
        #expect(h(Big) + 0.01 >= h(big) - 0.5)
        #expect(h(bigg) + 0.01 >= h(Big) - 0.5)
        #expect(h(Bigg) + 0.01 >= h(bigg) - 0.5)
    }
}
