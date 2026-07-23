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
        let bare = try renderer.layout(latex: "xyz")
        let display = try renderer.layout(latex: #"\widehat{xyz}"#)
        #expect(display.width > 0)
        #expect(display.ascent > 0)
        // Horizontal variants should cover (or nearly cover) the base width.
        #expect(display.width + 0.5 >= bare.width)
        // Accented form should not be dramatically narrower than the base.
        let accentOnly = try renderer.layout(latex: #"\hat{x}"#)
        #expect(display.width > accentOnly.width)
    }

    @Test func widehatWiderThanPlainHatOnLongBase() throws {
        let plain = try renderer.layout(latex: #"\hat{xyz}"#)
        let wide = try renderer.layout(latex: #"\widehat{xyz}"#)
        // Both map to U+0302; wide path should pick a longer horizontal variant.
        #expect(wide.width + 0.01 >= plain.width)
    }

    @Test func radicalGlyphTopAlignsWithOverbar() throws {
        let display = try renderer.layout(latex: #"\sqrt{\frac{a}{b}}"#)
        let rad = try #require(LayoutClearance.radical(in: display))
        let ruleTop = rad.ruleOffset + rad.ruleThickness / 2
        let glyphTop = rad.radicalGlyph.ascent - rad.radicalGlyph.shiftDown
        #expect(abs(glyphTop - ruleTop) <= 0.05, "glyph top \(glyphTop) vs rule top \(ruleTop)")
    }

    @Test func nestedRadicalFractionClearances() throws {
        guard let metrics = LayoutClearance.metrics() else {
            Issue.record("missing metrics")
            return
        }
        let display = try renderer.layout(latex: #"\sqrt{\frac{1}{2}}"#)
        let rad = try #require(LayoutClearance.radical(in: display))
        let gap = LayoutClearance.gapAbove(
            contentTop: rad.radicand.ascent,
            ruleOffset: rad.ruleOffset,
            ruleThickness: rad.ruleThickness
        )
        #expect(gap + 0.01 >= metrics.radicalVerticalGap || gap + 0.01 >= metrics.radicalDisplayStyleVerticalGap)

        // Nested fraction inside radicand still clears its own rule.
        if let frac = LayoutClearance.fraction(in: rad.radicand) {
            let denTop = -frac.denominatorOffset + frac.denominator.ascent
            let denGap = (frac.ruleOffset - frac.ruleThickness / 2) - denTop
            #expect(denGap + 0.01 >= metrics.fractionDenominatorGapMin
                        || denGap + 0.01 >= metrics.fractionDenominatorDisplayStyleGapMin)
        }
    }

    @Test func tallRadicalGrowsBeyondSingleVariantFloor() throws {
        let short = try renderer.layout(latex: #"\sqrt{2}"#)
        let tall = try renderer.layout(
            latex: #"\sqrt{\dfrac{a}{\dfrac{b}{\dfrac{c}{d}}}}"#
        )
        #expect(tall.ascent + tall.descent > short.ascent + short.descent + 10)
        let rad = try #require(LayoutClearance.radical(in: tall))
        // Assembly uses multiple glyph IDs; large variants still report positive size.
        #expect(rad.radicalGlyph.ascent + rad.radicalGlyph.descent > 20)
        let ruleTop = rad.ruleOffset + rad.ruleThickness / 2
        let glyphTop = rad.radicalGlyph.ascent - rad.radicalGlyph.shiftDown
        #expect(abs(glyphTop - ruleTop) <= 0.1)
    }

    @Test func utildeSitsBelowBase() throws {
        let bare = try renderer.layout(latex: "x")
        let under = try renderer.layout(latex: #"\utilde{x}"#)
        #expect(under.descent > bare.descent)
        #expect(under.ascent + 0.5 >= bare.ascent)
        // Accent glyph should be below the baseline of the base.
        guard case .list(let list) = under.children.first else {
            // Whole display may be the list
            try assertBelowAccent(under)
            return
        }
        try assertBelowAccent(list)
    }

    @Test func utildeWiderOnLongBase() throws {
        let short = try renderer.layout(latex: #"\utilde{x}"#)
        let long = try renderer.layout(latex: #"\utilde{xyz}"#)
        #expect(long.width > short.width)
    }

    private func assertBelowAccent(_ list: DisplayList) throws {
        #expect(list.children.count >= 2)
        let accentNode = list.children[1]
        #expect(accentNode.position.y < 0, "below accent y=\(accentNode.position.y)")
    }

    @Test func underaccentMarkListSitsBelow() throws {
        let bare = try renderer.layout(latex: "x")
        // Free-form mark (accents package): first arg is a symbol, not a combining command.
        let under = try renderer.layout(latex: #"\underaccent{\ast}{x}"#)
        #expect(under.descent > bare.descent)
        #expect(under.width + 0.5 >= bare.width)
    }

    @Test func accentMarkListSitsAbove() throws {
        let bare = try renderer.layout(latex: "x")
        let over = try renderer.layout(latex: #"\accent{\ast}{x}"#)
        #expect(over.ascent > bare.ascent)
    }

    @Test func underaccentWideBaseCentersMark() throws {
        let display = try renderer.layout(latex: #"\underaccent{\ast}{xyz}"#)
        #expect(display.width > 20)
        #expect(display.descent > 0)
    }

    @Test func parseUnderaccentAndAccentCommands() throws {
        let under = try MathParser.parse(#"\underaccent{\circ}{A}"#)
        #expect(under.atoms.first?.kind == .accent)
        if case .accent(let a) = under.atoms.first?.payload {
            #expect(a.isBelow)
            #expect(a.mark != nil || !a.accent.isEmpty)
        } else {
            Issue.record("expected accent payload")
        }

        let over = try MathParser.parse(#"\accent{\circ}{A}"#)
        if case .accent(let a) = over.atoms.first?.payload {
            #expect(!a.isBelow)
        } else {
            Issue.record("expected accent payload")
        }
    }

    @Test func underaccentBareTildeCommandParses() throws {
        // accents-package style: first arg is an accent *name*, not a full accent atom.
        let list = try MathParser.parse(#"\underaccent{\tilde}{x}"#)
        #expect(list.atoms.count == 1)
        guard case .accent(let a) = list.atoms.first?.payload else {
            Issue.record("expected accent")
            return
        }
        #expect(a.isBelow)
        #expect(a.mark == nil, "bare tilde should unwrap to single-glyph path")
        #expect(!a.accent.isEmpty)
        #expect(a.base.atoms.count >= 1)

        let emptyGroup = try MathParser.parse(#"\underaccent{\tilde{}}{x}"#)
        guard case .accent(let b) = emptyGroup.atoms.first?.payload else {
            Issue.record("expected accent for empty-base tilde")
            return
        }
        #expect(b.isBelow)
        #expect(b.mark == nil)
    }

    @Test func underaccentBareTildeLayoutsBelow() throws {
        let bare = try renderer.layout(latex: "x")
        let under = try renderer.layout(latex: #"\underaccent{\tilde}{x}"#)
        #expect(under.descent > bare.descent)
        #expect(under.ascent + 0.5 >= bare.ascent)
        // Comparable to dedicated `\utilde`.
        let utilde = try renderer.layout(latex: #"\utilde{x}"#)
        #expect(abs(under.descent - utilde.descent) < 4)
    }

    @Test func overrightarrowPositiveSize() throws {
        let display = try renderer.layout(latex: #"\overrightarrow{AB}"#)
        #expect(display.width > 0)
        #expect(display.ascent + display.descent > 0)
    }

    @Test func overrightarrowGrowsWithLongBase() throws {
        let short = try renderer.layout(latex: #"\overrightarrow{AB}"#)
        let long = try renderer.layout(latex: #"\overrightarrow{ABCDEFGHIJ}"#)
        #expect(long.width > short.width + 10)
        // Overlay should use assembly (multi-glyph) once past h-variants.
        if let stack = LayoutClearance.stack(in: long), let over = stack.over {
            let run = LayoutClearance.firstGlyphRun(in: .list(over))
            if let run, run.glyphIDs.count > 1 {
                #expect(run.glyphOffsetsX.count == run.glyphIDs.count)
            }
            #expect(over.width + 1 >= stack.base.width * 0.9)
        }
    }

    @Test func underrightarrowSitsBelowWideBase() throws {
        let bare = try renderer.layout(latex: "xyz")
        let under = try renderer.layout(latex: #"\underrightarrow{xyz}"#)
        #expect(under.descent > bare.descent)
        #expect(under.width + 0.5 >= bare.width)
    }

    @Test func hatOnTallBaseStillPositiveAscent() throws {
        // FlattenedAccentBaseHeight path: tall fraction base under a plain hat.
        let bare = try renderer.layout(latex: #"\frac{a}{b}"#)
        let accented = try renderer.layout(latex: #"\hat{\frac{a}{b}}"#)
        #expect(accented.ascent > bare.ascent - 0.5)
        #expect(accented.width + 0.5 >= bare.width * 0.5)
    }

    @Test func nestedSqrtFracDoublePrimeClearances() throws {
        guard let metrics = LayoutClearance.metrics() else {
            Issue.record("missing metrics")
            return
        }
        // Corpus-style nested formula that historically showed denominator-on-rule issues.
        let display = try renderer.layout(
            latex: #"\sqrt{\frac{f''(0)}{2!}}"#
        )
        let rad = try #require(LayoutClearance.radical(in: display))
        let radGap = LayoutClearance.gapAbove(
            contentTop: rad.radicand.ascent,
            ruleOffset: rad.ruleOffset,
            ruleThickness: rad.ruleThickness
        )
        #expect(
            radGap + 0.01 >= metrics.radicalVerticalGap
                || radGap + 0.01 >= metrics.radicalDisplayStyleVerticalGap
        )
        if let frac = LayoutClearance.fraction(in: rad.radicand) {
            let denTop = -frac.denominatorOffset + frac.denominator.ascent
            let denGap = (frac.ruleOffset - frac.ruleThickness / 2) - denTop
            #expect(
                denGap + 0.01 >= metrics.fractionDenominatorGapMin
                    || denGap + 0.01 >= metrics.fractionDenominatorDisplayStyleGapMin
            )
            let numBottom = frac.numeratorOffset - frac.numerator.descent
            let numGap = numBottom - (frac.ruleOffset + frac.ruleThickness / 2)
            #expect(
                numGap + 0.01 >= metrics.fractionNumeratorGapMin
                    || numGap + 0.01 >= metrics.fractionNumeratorDisplayStyleGapMin
            )
        }
    }

    @Test func overlineTallerThanBareContent() throws {
        let bare = try renderer.layout(latex: "x")
        let over = try renderer.layout(latex: #"\overline{x}"#)
        #expect(over.ascent > bare.ascent)
        #expect(over.width >= bare.width)
    }
}
