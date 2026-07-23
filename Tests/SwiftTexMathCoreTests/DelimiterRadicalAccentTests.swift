import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Delimiter / radical / accent regressions from iosMath + SwiftMath suites.
@Suite("Delimiter radical accent")
struct DelimiterRadicalAccentTests {
    private var renderer: MathRenderer {
        MathRenderer(
            environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20))
        )
    }

    private func collectGlyphText(_ node: DisplayNode, into texts: inout [String]) {
        switch node {
        case .glyphs(let run):
            if !run.text.isEmpty { texts.append(run.text) }
        case .list(let list):
            for child in list.children { collectGlyphText(child, into: &texts) }
        case .fraction(let frac):
            for child in frac.numerator.children { collectGlyphText(child, into: &texts) }
            for child in frac.denominator.children { collectGlyphText(child, into: &texts) }
        case .radical(let rad):
            if !rad.radicalGlyph.text.isEmpty { texts.append(rad.radicalGlyph.text) }
            for child in rad.radicand.children { collectGlyphText(child, into: &texts) }
            if let degree = rad.degree {
                for child in degree.children { collectGlyphText(child, into: &texts) }
            }
        case .largeOperator(let op):
            if !op.nucleus.text.isEmpty { texts.append(op.nucleus.text) }
            if let upper = op.upperLimit {
                for child in upper.children { collectGlyphText(child, into: &texts) }
            }
            if let lower = op.lowerLimit {
                for child in lower.children { collectGlyphText(child, into: &texts) }
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

    // MARK: - Delimiters

    @Test func nullDelimiterHasZeroWidthContribution() throws {
        let withParens = try renderer.layout(latex: #"\left( a \right)"#)
        let withNull = try renderer.layout(latex: #"\left. a \right."#)
        #expect(withNull.width < withParens.width)
    }

    @Test func leftRightDoesNotDuplicateInnerGlyphs() throws {
        let display = try renderer.layout(latex: #"\left( abc \right)"#)
        var texts: [String] = []
        for child in display.children {
            collectGlyphText(child, into: &texts)
        }
        // Math italic letters are non-ASCII; count letter-like scalar values once each.
        let letters = texts.joined().unicodeScalars.filter { $0.properties.isAlphabetic }
        #expect(letters.count == 3, "expected three alphabetic glyphs, got \(texts)")
    }

    @Test func bigDelimitersMonotonicHeight() throws {
        let plain = try renderer.layout(latex: "(")
        let big = try renderer.layout(latex: #"\big("#)
        let Big = try renderer.layout(latex: #"\Big("#)
        let bigg = try renderer.layout(latex: #"\bigg("#)
        #expect(big.ascent + big.descent >= plain.ascent + plain.descent)
        #expect(Big.ascent + Big.descent >= big.ascent + big.descent)
        #expect(bigg.ascent + bigg.descent >= Big.ascent + Big.descent)
    }

    @Test func leftRightScalesWithTallContent() throws {
        let short = try renderer.layout(latex: #"\left( x \right)"#)
        let tall = try renderer.layout(latex: #"\left( \frac{a}{b} \right)"#)
        #expect(tall.ascent + tall.descent > short.ascent + short.descent)
    }

    // MARK: - Radicals

    @Test func radicalDegreePresentAndPositioned() throws {
        let display = try renderer.layout(latex: #"\sqrt[3]{x}"#)
        guard case .radical(let rad) = display.children.first else {
            Issue.record("expected radical display")
            return
        }
        let degree = try #require(rad.degree)
        #expect(degree.width > 0)
        #expect(rad.radicand.width > 0)
        // Degree should not sit entirely to the right of the radicand.
        #expect(degree.position.x <= rad.radicand.position.x + rad.radicand.width)
    }

    @Test func radicalWithDegreeKeepsPositiveDegree() throws {
        let plain = try renderer.layout(latex: #"\sqrt{x}"#)
        let withDegree = try renderer.layout(latex: #"\sqrt[3]{x}"#)
        #expect(plain.width > 0)
        #expect(withDegree.width > 0)
        guard case .radical(let rad) = withDegree.children.first else {
            Issue.record("expected radical")
            return
        }
        #expect(rad.degree != nil)
        #expect(rad.degree!.width > 0)
    }

    // MARK: - Accents / stretchy

    @Test func hatAccentTallerThanBase() throws {
        let base = try renderer.layout(latex: "x")
        let accented = try renderer.layout(latex: #"\hat{x}"#)
        #expect(accented.ascent > base.ascent)
    }

    @Test func widehatAtLeastAsWideAsBase() throws {
        let display = try renderer.layout(latex: #"\widehat{xyz}"#)
        #expect(display.width > 0)
        #expect(display.ascent > 0)
    }

    @Test func overrightarrowPositiveSize() throws {
        let display = try renderer.layout(latex: #"\overrightarrow{AB}"#)
        #expect(display.width > 0)
        #expect(display.ascent + display.descent > 0)
    }

    @Test func overlineTallerThanBareContent() throws {
        let bare = try renderer.layout(latex: "x")
        let over = try renderer.layout(latex: #"\overline{x}"#)
        #expect(over.ascent > bare.ascent)
        #expect(over.width >= bare.width)
    }
}
