import CoreGraphics
import Testing
@testable import SwiftTexMathCore

@Test func parseQuadraticFormula() throws {
    let list = try MathParser.parse(#"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#)
    #expect(!list.isEmpty)
    #expect(list.atoms.contains { $0.kind == .fraction })
}

@Test func parseScripts() throws {
    let list = try MathParser.parse("x^2_i")
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0].superscript != nil)
    #expect(list.atoms[0].subscript != nil)
}

@Test func parseLeftRight() throws {
    let list = try MathParser.parse(#"\left( \frac{a}{b} \right)"#)
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0].kind == .inner)
}

@Test func parseSumLimits() throws {
    let list = try MathParser.parse(#"\sum_{i=1}^{n} x_i"#)
    #expect(list.atoms.first?.kind == .largeOperator)
    #expect(list.atoms.first?.limits == true)
}

@Test func parseMatrix() throws {
    let list = try MathParser.parse(#"\begin{pmatrix} a & b \\ c & d \end{pmatrix}"#)
    #expect(list.atoms.first?.kind == .table)
    if case .table(let table) = list.atoms.first?.payload {
        #expect(table.rows.count == 2)
        #expect(table.rows[0].count == 2)
    } else {
        Issue.record("Expected table payload")
    }
}

@Test func parseUnknownCommandThrows() {
    #expect(throws: ParseError.self) {
        _ = try MathParser.parse(#"\unknowncmd"#)
    }
}

@Test func parseMismatchedBraceThrows() {
    #expect(throws: ParseError.self) {
        _ = try MathParser.parse(#"{a"#)
    }
}

@Test func normalizeBinaryOperatorAtStart() throws {
    let list = try MathParser.parse("-x")
    let normalized = MathNormalizer.normalize(list)
    #expect(normalized.atoms.first?.kind == .ordinary)
}

@Test func normalizeNumberFusion() throws {
    let list = MathList(atoms: [.number("1"), .number("2")])
    let normalized = MathNormalizer.normalize(list)
    #expect(normalized.atoms.count == 1)
    #expect(normalized.atoms[0].nucleus == "12")
}

@Test func layoutProducesPositiveSize() throws {
    let renderer = MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20))
    )
    let display = try renderer.layout(latex: #"E = mc^2"#)
    #expect(display.width > 0)
    #expect(display.ascent + display.descent > 0)
}

@Test func layoutFraction() throws {
    let display = try MathRenderer().layout(latex: #"\frac{1}{2}"#)
    #expect(display.width > 0)
    #expect(display.children.contains { if case .fraction = $0 { return true }; return false })
}

@Test func layoutRadical() throws {
    let display = try MathRenderer().layout(latex: #"\sqrt{2}"#)
    #expect(display.width > 0)
}

@Test func interElementSpacingRelation() {
    let space = InterElementSpacing.space(
        left: .ordinary,
        right: .relation,
        style: .text,
        parameters: .default,
        mathUnit: 1
    )
    #expect(space == 5) // thick muskip
}

@Test func fontRegistryLoadsLatinModern() {
    let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20))
    #expect(metrics != nil)
    #expect(metrics!.axisHeight > 0)
}

@Test func mathRendererParseAndLayout() throws {
    let renderer = MathRenderer()
    let list = try renderer.parse(#"\alpha + \beta"#)
    let display = renderer.layout(list)
    #expect(display.width > 0)
}

@Test func delimiterVariantsGrowWithTallContent() throws {
    let short = try MathRenderer().layout(latex: #"\left( x \right)"#)
    let tall = try MathRenderer().layout(latex: #"\left( \frac{a}{b} \right)"#)
    #expect(tall.ascent + tall.descent > short.ascent + short.descent + 1)
}

@Test func radicalUsesSizedGlyph() throws {
    let simple = try MathRenderer().layout(latex: #"\sqrt{x}"#)
    let nested = try MathRenderer().layout(latex: #"\sqrt{\frac{a}{b}}"#)
    #expect(nested.ascent + nested.descent > simple.ascent + simple.descent)
}

@Test func dfracIsTallerThanTfrac() throws {
    let env = MathEnvironment(style: .text)
    let renderer = MathRenderer(environment: env)
    let dfrac = try renderer.layout(latex: #"\dfrac{1}{2}"#)
    let tfrac = try renderer.layout(latex: #"\tfrac{1}{2}"#)
    #expect(dfrac.ascent + dfrac.descent > tfrac.ascent + tfrac.descent)
}

@Test func mathrmKeepsUprightLetters() throws {
    let list = try MathParser.parse(#"\mathrm{sin}"#)
    #expect(list.atoms.count == 1)
    if case .styled(let styled) = list.atoms[0].payload {
        #expect(styled.variant == .upright)
    } else {
        Issue.record("Expected styled payload")
    }
}

@Test func textCommandAllowsSpaces() throws {
    let list = try MathParser.parse(#"\text{a b}"#)
    if case .styled(let styled) = list.atoms[0].payload {
        #expect(styled.contents.atoms.count >= 2)
    } else {
        Issue.record("Expected styled payload")
    }
}

@Test func italicCorrectionWidensSuperscriptedItalic() throws {
    let withScript = try MathRenderer().layout(latex: #"f^2"#)
    let plain = try MathRenderer().layout(latex: #"f"#)
    #expect(withScript.width > plain.width)
}

@Test func accentLayoutsAboveBase() throws {
    let display = try MathRenderer().layout(latex: #"\hat{a}"#)
    #expect(display.ascent > 0)
    #expect(display.width > 0)
}

@Test func verticalVariantsExistForParen() throws {
    let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20))!
    let glyph = metrics.glyph(for: "(")
    let variants = metrics.verticalVariants(for: glyph)
    #expect(variants.count > 1)
}

// MARK: - New commands & maxWidth

@Test func parseBigDelimiters() throws {
    let list = try MathParser.parse(#"\big( x \big)"#)
    #expect(list.atoms.count >= 3)
    #expect(list.atoms[0].kind == .open)
    if case .inner(let inner) = list.atoms[0].payload {
        #expect(inner.delimiterHeight == 1.0)
        #expect(inner.leftBoundary == "(")
    } else {
        Issue.record("Expected sized inner for \\big(")
    }
}

@Test func bigDelimiterTallerThanPlain() throws {
    let plain = try MathRenderer().layout(latex: "(")
    let big = try MathRenderer().layout(latex: #"\Big("#)
    #expect(big.ascent + big.descent > plain.ascent + plain.descent)
}

@Test func parseMiddleInLeftRight() throws {
    let list = try MathParser.parse(#"\left( a \middle| b \right)"#)
    #expect(list.atoms.count == 1)
    if case .inner(let inner) = list.atoms[0].payload {
        #expect(inner.contents.atoms.contains { $0.kind == .boundary })
    } else {
        Issue.record("Expected inner with \\middle")
    }
}

@Test func layoutMiddleProducesPositiveWidth() throws {
    let display = try MathRenderer().layout(latex: #"\left( \frac{a}{b} \middle| \frac{c}{d} \right)"#)
    #expect(display.width > 0)
}

@Test func parseColorNamedAndHex() throws {
    let named = try MathParser.parse(#"\color{red}{a}"#)
    #expect(named.atoms.count == 1)
    if case .colored(let c) = named.atoms[0].payload {
        #expect(c.color == "red")
    } else {
        Issue.record("Expected colored payload")
    }
    let hex = try MathParser.parse(#"\color{#00aa00}{b}"#)
    if case .colored(let c) = hex.atoms[0].payload {
        #expect(c.color == "#00aa00")
    } else {
        Issue.record("Expected hex colored payload")
    }
}

@Test func layoutColorNode() throws {
    let display = try MathRenderer().layout(latex: #"a+\color{blue}{b}+c"#)
    #expect(display.children.contains { if case .colored = $0 { return true }; return false })
}

@Test func parseMathChoice() throws {
    let list = try MathParser.parse(#"\mathchoice{D}{T}{S}{SS}"#)
    #expect(list.atoms.count == 1)
    if case .mathChoice(let choice) = list.atoms[0].payload {
        #expect(choice.display.atoms.count == 1)
        #expect(choice.text.atoms.count == 1)
    } else {
        Issue.record("Expected mathChoice payload")
    }
}

@Test func mathChoicePicksDisplayStyle() throws {
    let display = try MathRenderer(environment: MathEnvironment(style: .display))
        .layout(latex: #"\mathchoice{D}{T}{S}{SS}"#)
    let text = try MathRenderer(environment: MathEnvironment(style: .text))
        .layout(latex: #"\mathchoice{D}{T}{S}{SS}"#)
    // Different style choices should produce layouts (smoke + style path).
    #expect(display.width > 0)
    #expect(text.width > 0)
}

@Test func parseMathcal() throws {
    let list = try MathParser.parse(#"\mathcal{A}"#)
    #expect(list.atoms.count == 1)
    if case .styled(let styled) = list.atoms[0].payload {
        #expect(styled.variant == .caligraphic)
    } else {
        Issue.record("Expected caligraphic styled payload")
    }
}

@Test func maxWidthWrapsLongRelationChain() throws {
    let latex = #"a = b = c = d = e = f = g = h"#
    let wide = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20), maxWidth: 0)
    ).layout(latex: latex)
    let narrow = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20), maxWidth: 80)
    ).layout(latex: latex)
    #expect(narrow.width <= 80 + 1)
    #expect(narrow.ascent + narrow.descent > wide.ascent + wide.descent)
}

// MARK: - Golden layout sizes (Latin Modern 20pt)

@Test func goldenSizeSimpleEquals() throws {
    let display = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20))
    ).layout(latex: #"E = mc^2"#)
    #expect(display.width > 40 && display.width < 90)
    #expect(display.ascent + display.descent > 12 && display.ascent + display.descent < 40)
}

@Test func goldenSizeFraction() throws {
    let display = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20))
    ).layout(latex: #"\frac{1}{2}"#)
    #expect(display.width > 8 && display.width < 30)
    #expect(display.ascent + display.descent > 20)
}

@Test func goldenSizeQuadratic() throws {
    let display = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
    ).layout(latex: #"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#)
    #expect(display.width > 80)
    #expect(display.ascent + display.descent > 30)
}

// MARK: - Tables / array / fonts / text wrapping

@Test func parseArrayColumnSpec() throws {
    let list = try MathParser.parse(#"\begin{array}{c|cr} 1 & 2 & 3 \\ 4 & 5 & 6 \end{array}"#)
    #expect(list.atoms.first?.kind == .table)
    if case .table(let table) = list.atoms.first?.payload {
        #expect(table.alignments == [.center, .center, .right])
        #expect(table.vlines == [0, 1, 0, 0])
        #expect(table.rows.count == 2)
        #expect(table.rows[0].count == 3)
    } else {
        Issue.record("Expected array table")
    }
}

@Test func parseArrayLeadingTrailingVlines() throws {
    let list = try MathParser.parse(#"\begin{array}{|c|c|} a & b \end{array}"#)
    if case .table(let table) = list.atoms.first?.payload {
        #expect(table.vlines == [1, 1, 1])
    } else {
        Issue.record("Expected vlines")
    }
}

@Test func layoutArrayDrawsRules() throws {
    let display = try MathRenderer().layout(latex: #"\begin{array}{c|c} a & b \end{array}"#)
    #expect(display.children.contains { if case .rule = $0 { return true }; return false }
        || display.children.contains {
            if case .list(let inner) = $0 {
                return inner.children.contains { if case .rule = $0 { return true }; return false }
            }
            return false
        })
}

@Test func parseAlignedEnvironment() throws {
    let list = try MathParser.parse(#"\begin{aligned} a &= b \\ c &= d \end{aligned}"#)
    if case .table(let table) = list.atoms.first?.payload {
        #expect(table.alignments == [.right, .left])
        #expect(table.interColumnSpacing == 0)
    } else {
        Issue.record("Expected aligned table")
    }
}

@Test func parseBlackboardFrakturScript() throws {
    let bb = try MathParser.parse(#"\mathbb{R}"#)
    if case .styled(let s) = bb.atoms[0].payload {
        #expect(s.variant == .blackboard)
    } else {
        Issue.record("Expected blackboard")
    }
    let fr = try MathParser.parse(#"\mathfrak{g}"#)
    if case .styled(let s) = fr.atoms[0].payload {
        #expect(s.variant == .fraktur)
    } else {
        Issue.record("Expected fraktur")
    }
    let sc = try MathParser.parse(#"\mathscr{L}"#)
    if case .styled(let s) = sc.atoms[0].payload {
        #expect(s.variant == .script)
    } else {
        Issue.record("Expected script")
    }
}

@Test func layoutBlackboardProducesGlyphs() throws {
    let display = try MathRenderer().layout(latex: #"\mathbb{N}"#)
    #expect(display.width > 0)
}

@Test func textDoesNotBreakMidWord() throws {
    let latex = #"\text{abcdefghij}"#
    let narrow = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20), maxWidth: 40)
    ).layout(latex: latex)
    // Single word should not split into multiple shorter lines of letters.
    let lineCount = narrow.children.filter {
        if case .list = $0 { return true }
        return false
    }.count
    #expect(lineCount <= 1 || narrow.width > 40)
}

@Test func textBreaksOnSpaces() throws {
    let latex = #"\text{alpha beta gamma delta epsilon}"#
    let wide = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20), maxWidth: 0)
    ).layout(latex: latex)
    let narrow = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20), maxWidth: 70)
    ).layout(latex: latex)
    #expect(narrow.width <= 70 + 1)
    #expect(narrow.ascent + narrow.descent >= wide.ascent + wide.descent)
}

@Test func goldenSizePmatrix() throws {
    let display = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20))
    ).layout(latex: #"\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}"#)
    #expect(display.width > 20 && display.width < 80)
    #expect(display.ascent + display.descent > 20)
}

@Test func parsePhantomAndCancel() throws {
    let phantom = try MathParser.parse(#"a\phantom{xyz}b"#)
    #expect(phantom.atoms.count == 3)
    guard case .box(let box) = phantom.atoms[1].payload else {
        Issue.record("expected box"); return
    }
    #expect(box.keepWidth && box.keepHeight && !box.drawChild)

    let cancel = try MathParser.parse(#"\cancel{x}"#)
    guard case .box(let c) = cancel.atoms[0].payload else {
        Issue.record("expected cancel box"); return
    }
    #expect(c.strike == .forward && c.drawChild)
}

@Test func layoutPhantomOccupiesWidth() throws {
    let with = try MathRenderer().layout(latex: #"a\phantom{xxxxxx}b"#)
    let without = try MathRenderer().layout(latex: #"ab"#)
    #expect(with.width > without.width + 10)

    let hp = try MathRenderer().layout(latex: #"\hphantom{x}"#)
    #expect(hp.width > 0)
    #expect(hp.ascent + hp.descent == 0)

    let vp = try MathRenderer().layout(latex: #"\vphantom{\frac{1}{x}}"#)
    #expect(vp.width == 0)
    #expect(vp.ascent + vp.descent > 0)
}

@Test func parseInfixOverAndChoose() throws {
    let over = try MathParser.parse(#"{a \over b}"#)
    #expect(over.atoms.count == 1)
    guard case .fraction(let f) = over.atoms[0].payload else {
        Issue.record("expected fraction"); return
    }
    #expect(f.hasRule)

    let choose = try MathParser.parse(#"n \choose k"#)
    guard case .fraction(let c) = choose.atoms[0].payload else {
        Issue.record("expected choose"); return
    }
    #expect(!c.hasRule && c.leftDelimiter == "(" && c.rightDelimiter == ")")
}

@Test func parseKernAndHspace() throws {
    let list = try MathParser.parse(#"a\kern{1em}b\hspace{2mu}c"#)
    #expect(list.atoms.contains { atom in
        if case .space(let mu) = atom.payload { return mu == 18 }
        return false
    })
    #expect(list.atoms.contains { atom in
        if case .space(let mu) = atom.payload { return mu == 2 }
        return false
    })
}

@Test func parseOversetUndersetSubstack() throws {
    let overset = try MathParser.parse(#"\overset{a}{=}"#)
    guard case .stack(let s) = overset.atoms[0].payload else {
        Issue.record("expected stack"); return
    }
    #expect(s.over != nil)

    let arrow = try MathParser.parse(#"\overrightarrow{ABC}"#)
    guard case .stack(let a) = arrow.atoms[0].payload else {
        Issue.record("expected arrow stack"); return
    }
    #expect(a.overNucleus == "\u{2192}")

    let sub = try MathParser.parse(#"\sum_{\substack{i=1 \\ i\neq j}}"#)
    #expect(!sub.atoms.isEmpty)
}

@Test func parseBoldsymbolAndNot() throws {
    let bold = try MathParser.parse(#"\boldsymbol{\alpha}"#)
    guard case .styled(let styled) = bold.atoms[0].payload else {
        Issue.record("expected styled"); return
    }
    #expect(styled.variant == .boldItalic)

    let notEq = try MathParser.parse(#"a \not= b"#)
    #expect(notEq.atoms.contains { $0.nucleus == "\u{2260}" })
}

@Test func parseGatheredAndStarredMatrix() throws {
    let gathered = try MathParser.parse(#"\begin{gathered} a \\ b \end{gathered}"#)
    guard case .table(let t) = gathered.atoms[0].payload else {
        Issue.record("expected table"); return
    }
    #expect(t.environment == "gathered")

    let starred = try MathParser.parse(#"\begin{pmatrix*}[r] 1 & 2 \\ 3 & 4 \end{pmatrix*}"#)
    guard case .table(let m) = starred.atoms[0].payload else {
        Issue.record("expected matrix"); return
    }
    #expect(m.environment == "pmatrix")
    #expect(m.alignments.allSatisfy { $0 == .right })
}

@Test func extendedSymbolsResolve() throws {
    #expect(AtomFactory.atom(forCommand: "bigodot") != nil)
    #expect(AtomFactory.atom(forCommand: "iiiint") != nil)
    #expect(AtomFactory.atom(forCommand: "angstrom") != nil)
    #expect(AtomFactory.atom(forCommand: "AA") != nil)
    #expect(AtomFactory.atom(forCommand: ":") != nil)
}

@Test func alternateFontsLoad() {
    for name in [MathFont.Name.xits, .asana, .libertinus] {
        let metrics = FontRegistry.shared.metrics(for: MathFont(name: name, size: 20))
        #expect(metrics != nil, "failed to load \(name.rawValue)")
    }
}

