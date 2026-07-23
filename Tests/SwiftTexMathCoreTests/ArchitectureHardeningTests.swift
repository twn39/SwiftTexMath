import CoreGraphics
import Testing
@testable import SwiftTexMathCore

// MARK: - Table / environment failure modes

private func expectParseError(
    _ latex: String,
    code: ParseError.Code,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    do {
        _ = try MathParser.parse(latex)
        Issue.record("Expected ParseError.\(code) for \(latex)", sourceLocation: sourceLocation)
    } catch let error as ParseError {
        #expect(error.code == code, "\(latex) → \(error)", sourceLocation: sourceLocation)
    } catch {
        Issue.record("Unexpected error \(error) for \(latex)", sourceLocation: sourceLocation)
    }
}

@Test func arrayMissingColumnSpecFails() {
    expectParseError(#"\begin{array} 1 \end{array}"#, code: .missingEnvironment)
}

@Test func arrayEmptyColumnSpecFails() {
    expectParseError(#"\begin{array}{} 1 \end{array}"#, code: .invalidEnvironment)
}

@Test func arrayInvalidColumnSpecCharFails() {
    expectParseError(#"\begin{array}{x} 1 \end{array}"#, code: .invalidEnvironment)
}

@Test func mismatchedTableEndFails() {
    expectParseError(#"\begin{pmatrix} a \end{matrix}"#, code: .invalidEnvironment)
}

@Test func missingTableEndFails() {
    expectParseError(#"\begin{pmatrix} a"#, code: .missingEnd)
}

@Test func casesWithThreeColumnsFails() {
    expectParseError(#"\begin{cases} a & b & c \end{cases}"#, code: .invalidNumberOfColumns)
}

@Test func gatherWithTwoColumnsFails() {
    expectParseError(#"\begin{gather} a & b \end{gather}"#, code: .invalidNumberOfColumns)
}

@Test func eqnarrayRequiresThreeColumns() {
    expectParseError(#"\begin{eqnarray} a & b \end{eqnarray}"#, code: .invalidNumberOfColumns)
}

@Test func splitWithThreeColumnsFails() {
    expectParseError(#"\begin{split} a & b & c \end{split}"#, code: .invalidNumberOfColumns)
}

@Test func alignedatMissingPairCountFails() {
    expectParseError(#"\begin{alignedat} a \end{alignedat}"#, code: .invalidCommand)
}

@Test func hlineInsidePmatrixFails() {
    expectParseError(#"\begin{pmatrix} a \\ \hline b \end{pmatrix}"#, code: .invalidCommand)
}

@Test func parseColumnSpecDirectlyRejectsJunk() {
    #expect(throws: ParseError.self) {
        _ = try TableEnvironment.parseColumnSpec("!")
    }
    #expect(throws: ParseError.self) {
        _ = try TableEnvironment.parseColumnSpec("")
    }
}

@Test func parseColumnSpecAcceptsVLines() throws {
    let spec = try TableEnvironment.parseColumnSpec("|c|cr|")
    #expect(spec.alignments == [.center, .center, .right])
    #expect(spec.vlines == [1, 1, 0, 1])
}

// MARK: - Delimiter assembly

private func collectGlyphRuns(_ node: DisplayNode) -> [GlyphRun] {
    switch node {
    case .glyphs(let run):
        return [run]
    case .list(let list):
        return list.children.flatMap(collectGlyphRuns)
    case .fraction(let frac):
        return collectGlyphRuns(.list(frac.numerator)) + collectGlyphRuns(.list(frac.denominator))
    case .radical(let rad):
        var runs = [rad.radicalGlyph] + collectGlyphRuns(.list(rad.radicand))
        if let degree = rad.degree { runs += collectGlyphRuns(.list(degree)) }
        return runs
    case .line(let line):
        return collectGlyphRuns(.list(line.inner))
    case .largeOperator(let op):
        var runs = [op.nucleus]
        if let lim = op.upperLimit { runs += collectGlyphRuns(.list(lim)) }
        if let lim = op.lowerLimit { runs += collectGlyphRuns(.list(lim)) }
        return runs
    case .colored(let colored):
        return collectGlyphRuns(.list(colored.inner))
    case .box(let box):
        return collectGlyphRuns(.list(box.child))
    case .stack(let stack):
        var runs = collectGlyphRuns(.list(stack.base))
        if let over = stack.over { runs += collectGlyphRuns(.list(over)) }
        if let under = stack.under { runs += collectGlyphRuns(.list(under)) }
        return runs
    case .rule:
        return []
    }
}

@Test func leftRightEmitsLeftAndRightDelimiterGlyphs() throws {
    let display = try MathRenderer().layout(latex: #"\left( x \right)"#)
    let runs = collectGlyphRuns(.list(display))
    let left = runs.filter { $0.text == "(" }
    let right = runs.filter { $0.text == ")" }
    #expect(left.count == 1)
    #expect(right.count == 1)
    #expect(left[0].shiftDown != 0 || left[0].ascent > 0)
}

@Test func middleProducesThreeDelimiterGlyphs() throws {
    let display = try MathRenderer().layout(latex: #"\left( a \middle| b \right)"#)
    let runs = collectGlyphRuns(.list(display))
    #expect(runs.contains { $0.text == "(" })
    #expect(runs.contains { $0.text == "|" })
    #expect(runs.contains { $0.text == ")" })
}

@Test func tallContentSelectsLargerDelimiterVariantOrAssembly() throws {
    let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20))!
    let short = metrics.sizedDelimiter(forNucleus: "(", height: 10)
    let tall = metrics.sizedDelimiter(forNucleus: "(", height: 80)
    let shortSpan = short.ascent + short.descent
    let tallSpan = tall.ascent + tall.descent
    #expect(tallSpan + 0.5 >= shortSpan)
    // Either a larger variant, multi-piece assembly, or measurably taller span.
    #expect(
        tall.glyphIDs != short.glyphIDs
            || tall.glyphIDs.count > 1
            || tallSpan > shortSpan + 1
    )
}

@Test func biggLeftRightTallerThanBig() throws {
    let big = try MathRenderer().layout(latex: #"\Big( x \Big)"#)
    let bigg = try MathRenderer().layout(latex: #"\bigg( x \bigg)"#)
    #expect(bigg.ascent + bigg.descent > big.ascent + big.descent)
}

@Test func emptyBigDelimiterIsSingleGlyphList() throws {
    let display = try MathRenderer().layout(latex: #"\Big("#)
    let runs = collectGlyphRuns(.list(display))
    #expect(runs.contains { $0.text == "(" })
    #expect(display.width > 0)
}

@Test func delimiterLayoutCentersOnAxis() throws {
    let display = try MathRenderer().layout(latex: #"\left( \frac{a}{b} \right)"#)
    let paren = collectGlyphRuns(.list(display)).first { $0.text == "(" }
    #expect(paren != nil)
    #expect(paren!.shiftDown > 0)
}

// MARK: - Wrap / table layout hardening

@Test func wrapDoesNotBreakAfterOpenBeforeLetter() {
    let open = MathAtom.open("(")
    let letter = MathAtom.variable("x")
    #expect(!WrapLayout.canBreakBefore(letter, previous: open))
}

@Test func wrapBreaksBeforeBinaryAfterOrd() {
    let bin = MathAtom.binaryOperator("+")
    let letter = MathAtom.variable("a")
    #expect(WrapLayout.canBreakBefore(bin, previous: letter))
}

@Test func tableVLinesProduceVerticalRules() throws {
    let display = try MathRenderer().layout(latex: #"\begin{array}{|c|c|} a & b \end{array}"#)
    func countVerticalRules(_ node: DisplayNode) -> Int {
        switch node {
        case .rule(let rule) where rule.isVertical:
            return 1
        case .list(let list):
            return list.children.reduce(0) { $0 + countVerticalRules($1) }
        default:
            return 0
        }
    }
    #expect(countVerticalRules(.list(display)) >= 3)
}

@Test func arrayHLinesProduceHorizontalRules() throws {
    let display = try MathRenderer().layout(
        latex: #"\begin{array}{c} \hline a \\ \hline \end{array}"#
    )
    func countHorizontalRules(_ node: DisplayNode) -> Int {
        switch node {
        case .rule(let rule) where !rule.isVertical:
            return 1
        case .list(let list):
            return list.children.reduce(0) { $0 + countHorizontalRules($1) }
        default:
            return 0
        }
    }
    #expect(countHorizontalRules(.list(display)) >= 2)
}

@Test func pmatrixLayoutWiderThanBareMatrixContent() throws {
    let bare = try MathRenderer().layout(latex: #"\begin{matrix} 1 & 0 \\ 0 & 1 \end{matrix}"#)
    let fenced = try MathRenderer().layout(latex: #"\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}"#)
    #expect(fenced.width > bare.width)
}

// MARK: - FontProviding partial doubles

/// Returns metrics only for a single font identity (size + name).
private struct SelectiveFontProvider: FontProviding {
    let allowed: MathFont
    func metrics(for font: MathFont) -> FontMetrics? {
        guard font.name == allowed.name, font.size == allowed.size else { return nil }
        return FontRegistry.shared.metrics(for: font)
    }
}

@Test func selectiveFontProviderLayoutsWhenSizeMatches() throws {
    let font = MathFont(name: .latinModern, size: 20)
    let renderer = MathRenderer(
        environment: MathEnvironment(font: font),
        fonts: SelectiveFontProvider(allowed: font)
    )
    let display = try renderer.layout(latex: #"x^2"#)
    #expect(display.width > 0)
}

@Test func selectiveFontProviderYieldsEmptyWhenSizeMismatches() throws {
    let allowed = MathFont(name: .latinModern, size: 20)
    let used = MathFont(name: .latinModern, size: 24)
    let renderer = MathRenderer(
        environment: MathEnvironment(font: used),
        fonts: SelectiveFontProvider(allowed: allowed)
    )
    let display = try renderer.layout(latex: #"x^2"#)
    #expect(display.width == 0)
    #expect(display.children.isEmpty)
}

@Test func mathImageHonorsInjectedFontProvider() throws {
    let result = try MathImage.render(
        latex: #"E=mc^2"#,
        fonts: EmptyFonts()
    )
    #expect(result.display.width == 0)
}

private struct EmptyFonts: FontProviding {
    func metrics(for font: MathFont) -> FontMetrics? { nil }
}

// MARK: - iosMath parity: primes, symbols, depth, cfrac

@Test func primeShorthandAttachesSuperscript() throws {
    let list = try MathParser.parse(#"f'"#)
    #expect(list.atoms.count == 1)
    let f = list.atoms[0]
    #expect(f.nucleus == "f")
    #expect(f.superscript?.atoms.count == 1)
    #expect(f.superscript?.atoms[0].nucleus == "\u{2032}")
}

@Test func doublePrimeAndCaretMerge() throws {
    let list = try MathParser.parse(#"f''^2"#)
    #expect(list.atoms.count == 1)
    let primes = try #require(list.atoms[0].superscript)
    #expect(primes.atoms.count == 3)
    #expect(primes.atoms[0].nucleus == "\u{2032}")
    #expect(primes.atoms[1].nucleus == "\u{2032}")
    #expect(primes.atoms[2].nucleus == "2")
}

@Test func multiIntegralCommandsParse() throws {
    for cmd in ["oiint", "oiiint", "fint", "varointclockwise", "ointctrclockwise"] {
        let list = try MathParser.parse("\\\(cmd)")
        #expect(list.atoms.count == 1, "\\\(cmd)")
        #expect(list.atoms[0].kind == .largeOperator, "\\\(cmd)")
    }
}

@Test func highFrequencyAMSAliasesResolve() throws {
    #expect(AtomFactory.atom(forCommand: "lt")?.nucleus == "<")
    #expect(AtomFactory.atom(forCommand: "gt")?.nucleus == ">")
    #expect(AtomFactory.atom(forCommand: "impliedby")?.nucleus == "\u{27F8}")
    #expect(AtomFactory.atom(forCommand: "therefore")?.nucleus == "\u{2234}")
    #expect(AtomFactory.atom(forCommand: "because")?.nucleus == "\u{2235}")
    #expect(AtomFactory.atom(forCommand: "square")?.nucleus == "\u{25A1}")
    #expect(AtomFactory.atom(forCommand: "dotsc")?.nucleus == "\u{2026}")
    #expect(AtomFactory.atom(forCommand: "dotsb")?.nucleus == "\u{22EF}")
    #expect(AtomFactory.atom(forCommand: "rightleftharpoons")?.nucleus == "\u{21CC}")
    #expect(AtomFactory.atom(forCommand: "twoheadrightarrow")?.nucleus == "\u{21A0}")
}

@Test func nestingTooDeepFails() {
    let depth = MathParser.maxRecursionDepth + 10
    let latex = String(repeating: "{", count: depth) + "x" + String(repeating: "}", count: depth)
    expectParseError(latex, code: .nestingTooDeep)
}

@Test func moderateNestingStillParses() throws {
    let depth = 20
    let latex = String(repeating: "{", count: depth) + "x" + String(repeating: "}", count: depth)
    let list = try MathParser.parse(latex)
    #expect(!list.atoms.isEmpty)
}

@Test func cfracOptionalAlignment() throws {
    let left = try MathParser.parse(#"\cfrac[l]{a}{b+c+d}"#)
    let right = try MathParser.parse(#"\cfrac[r]{a}{b+c+d}"#)
    let center = try MathParser.parse(#"\cfrac{a}{b+c+d}"#)
    guard case .fraction(let lf) = left.atoms[0].payload else {
        Issue.record("expected fraction"); return
    }
    guard case .fraction(let rf) = right.atoms[0].payload else {
        Issue.record("expected fraction"); return
    }
    guard case .fraction(let cf) = center.atoms[0].payload else {
        Issue.record("expected fraction"); return
    }
    #expect(lf.numeratorAlignment == .left)
    #expect(rf.numeratorAlignment == .right)
    #expect(cf.numeratorAlignment == .center)
    #expect(lf.forcedStyle == .display)
}

@Test func cfracInvalidAlignmentFails() {
    expectParseError(#"\cfrac[x]{a}{b}"#, code: .invalidCommand)
}

@Test func textsfAndBfAliasesParse() throws {
    let sans = try MathParser.parse(#"\textsf{R}"#)
    let bold = try MathParser.parse(#"\bf{x}"#)
    #expect(sans.atoms.count == 1)
    #expect(bold.atoms.count == 1)
    guard case .styled(let s) = sans.atoms[0].payload else {
        Issue.record("expected styled"); return
    }
    guard case .styled(let b) = bold.atoms[0].payload else {
        Issue.record("expected styled"); return
    }
    #expect(s.variant == .sans)
    #expect(b.variant == .bold)
}

@Test func cfracLeftAlignsNumeratorNarrowerThanDenom() throws {
    let left = try MathRenderer().layout(latex: #"\cfrac[l]{a}{bbbb}"#)
    let right = try MathRenderer().layout(latex: #"\cfrac[r]{a}{bbbb}"#)
    func numeratorX(_ display: DisplayList) -> CGFloat? {
        for child in display.children {
            if case .fraction(let frac) = child {
                return frac.numerator.position.x
            }
        }
        return nil
    }
    let lx = try #require(numeratorX(left))
    let rx = try #require(numeratorX(right))
    #expect(lx < rx)
}

@Test func arrayAtInsertSuppressesDefaultGap() throws {
    let spaced = try MathRenderer().layout(latex: #"\begin{array}{cc} a & b \end{array}"#)
    let tight = try MathRenderer().layout(latex: #"\begin{array}{c@{}c} a & b \end{array}"#)
    #expect(tight.width < spaced.width)
}

@Test func arrayAtInsertParsesContent() throws {
    let spec = try TableEnvironment.parseColumnSpec(#"c@{\quad}c"#)
    #expect(spec.alignments.count == 2)
    #expect(spec.inserts.count == 3)
    #expect(spec.inserts[0] == nil)
    #expect(spec.inserts[1] != nil)
    #expect(spec.inserts[1]?.atoms.isEmpty == false)
    #expect(spec.inserts[2] == nil)
}

@Test func arrayEmptyAtInsertIsPresent() throws {
    let spec = try TableEnvironment.parseColumnSpec("c@{}c")
    #expect(spec.inserts[1] != nil)
    #expect(spec.inserts[1]?.atoms.isEmpty == true)
}

@Test func arrayAtQuadWiderThanEmptyAt() throws {
    let empty = try MathRenderer().layout(latex: #"\begin{array}{c@{}c} a & b \end{array}"#)
    let quad = try MathRenderer().layout(latex: #"\begin{array}{c@{\quad}c} a & b \end{array}"#)
    #expect(quad.width > empty.width)
}

// MARK: - Custom symbols + serialization

@Test func addLatexSymbolIsVisibleToParser() throws {
    AtomFactory.resetCustomSymbols()
    defer { AtomFactory.resetCustomSymbols() }
    AtomFactory.addLatexSymbol("lcm", atom: .largeOperator("lcm", limits: false))
    let list = try MathParser.parse(#"\lcm(a,b)"#)
    #expect(list.atoms[0].nucleus == "lcm")
    #expect(list.atoms[0].kind == .largeOperator)
}

@Test func customAliasResolves() throws {
    AtomFactory.resetCustomSymbols()
    defer { AtomFactory.resetCustomSymbols() }
    AtomFactory.addAlias("toarrow", target: "rightarrow")
    let atom = AtomFactory.atom(forCommand: "toarrow")
    #expect(atom?.nucleus == "\u{2192}")
}

@Test func remainingAMSSymbolsResolve() throws {
    #expect(AtomFactory.atom(forCommand: "nsubset")?.nucleus == "\u{2284}")
    #expect(AtomFactory.atom(forCommand: "triangleq")?.nucleus == "\u{225C}")
    #expect(AtomFactory.atom(forCommand: "spadesuit")?.nucleus == "\u{2660}")
    #expect(AtomFactory.atom(forCommand: "varsigma")?.nucleus == "\u{03C2}")
    #expect(AtomFactory.atom(forCommand: "nprecapprox")?.nucleus == "\u{2AB9}")
    #expect(AtomFactory.atom(forCommand: "Subset")?.nucleus == "\u{22D0}")
}

@Test func latexSerializerRoundTripsSimple() throws {
    let original = #"E=mc^2"#
    let list = try MathParser.parse(original)
    let latex = list.latexString
    let again = try MathParser.parse(latex)
    #expect(again.atoms.count == list.atoms.count)
    #expect(again.atoms.map(\.nucleus) == list.atoms.map(\.nucleus))
}

@Test func latexSerializerFractionAndScripts() throws {
    let list = try MathParser.parse(#"\frac{a}{b}+x^2"#)
    let latex = LatexSerializer.string(from: list)
    #expect(latex.contains("\\frac"))
    #expect(latex.contains("^{"))
    let again = try MathParser.parse(latex)
    #expect(again.atoms.count >= 2)
}

@Test func latexSerializerStyledAndRadical() throws {
    let list = try MathParser.parse(#"\mathrm{d}\sqrt{x}"#)
    let latex = list.latexString
    #expect(latex.contains("\\mathrm"))
    #expect(latex.contains("\\sqrt"))
}
