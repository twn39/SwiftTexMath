import CoreGraphics
import Testing
@testable import SwiftTexMathCore

// MARK: - Command family parsing

@Test func fractionCommandsProduceFractionPayload() throws {
    let list = try MathParser.parse(#"\frac{1}{2}"#)
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0].kind == .fraction)
    if case .fraction(let frac) = list.atoms[0].payload {
        #expect(frac.hasRule)
        #expect(frac.forcedStyle == nil)
    } else {
        Issue.record("Expected fraction payload")
    }
}

@Test func binomCommandsForceParentheses() throws {
    let list = try MathParser.parse(#"\binom{n}{k}"#)
    #expect(list.atoms.count == 1)
    if case .fraction(let frac) = list.atoms[0].payload {
        #expect(!frac.hasRule)
        #expect(frac.leftDelimiter == "(")
        #expect(frac.rightDelimiter == ")")
    } else {
        Issue.record("Expected binom fraction payload")
    }
}

@Test func delimiterCommandsBuildInnerFence() throws {
    let list = try MathParser.parse(#"\left( a \middle| b \right)"#)
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0].kind == .inner)
    if case .inner(let inner) = list.atoms[0].payload {
        #expect(!inner.leftBoundary.isEmpty)
        #expect(!inner.rightBoundary.isEmpty)
        #expect(inner.contents.atoms.contains { $0.kind == .boundary })
    } else {
        Issue.record("Expected inner fence payload")
    }
}

@Test func styleCommandsApplyVariant() throws {
    let list = try MathParser.parse(#"\mathrm{abc}"#)
    #expect(list.atoms.count == 1)
    if case .styled(let styled) = list.atoms[0].payload {
        #expect(styled.variant == .upright)
    } else {
        Issue.record("Expected styled payload")
    }
}

@Test func stackCommandsBuildOverset() throws {
    let list = try MathParser.parse(#"\overset{a}{=}"#)
    #expect(list.atoms.count == 1)
    if case .stack(let stack) = list.atoms[0].payload {
        #expect(stack.over != nil)
        #expect(stack.under == nil)
    } else {
        Issue.record("Expected stack payload")
    }
}

@Test func boxCommandsBuildPhantom() throws {
    let list = try MathParser.parse(#"\phantom{x}"#)
    #expect(list.atoms.count == 1)
    if case .box(let box) = list.atoms[0].payload {
        #expect(box.keepWidth)
        #expect(!box.drawChild)
    } else {
        Issue.record("Expected box payload")
    }
}

@Test func environmentCommandsParseArray() throws {
    let list = try MathParser.parse(#"\begin{array}{cc} 1 & 2 \end{array}"#)
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0].kind == .table)
}

@Test func infixOverProducesInfixFractionResultPath() throws {
    let list = try MathParser.parse(#"{a \over b}"#)
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0].kind == .fraction)
}

// MARK: - Wrap break heuristics

@Test func wrapBreaksBeforeRelations() {
    let rel = MathAtom.relation("=")
    let letter = MathAtom.variable("a")
    #expect(WrapLayout.canBreakBefore(rel, previous: letter))
    #expect(!WrapLayout.canBreakBefore(MathAtom.punctuation(","), previous: letter))
    #expect(!WrapLayout.canBreakBefore(letter, previous: MathAtom.open("(")))
}

@Test func wrapDoesNotSplitTextLetters() {
    let a = MathAtom.ordinary("a")
    let b = MathAtom.ordinary("b")
    #expect(!WrapLayout.canBreakBefore(b, previous: a))
    #expect(WrapLayout.canBreakBefore(b, previous: a, allowMidWord: true))
    let space = MathAtom.space(mu: 3)
    #expect(WrapLayout.canBreakBefore(b, previous: space))
}

@Test func wrapLayoutProducesMultipleLines() throws {
    let latex = #"a = b = c = d = e = f = g = h"#
    let narrow = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20), maxWidth: 60)
    ).layout(latex: latex)
    let lineCount = narrow.children.filter {
        if case .list = $0 { return true }
        return false
    }.count
    #expect(lineCount >= 2)
    #expect(narrow.width <= 60 + 1)
}

@Test func wrapBreaksLongTextWordAsLastResort() throws {
    // No spaces — preferred soft breaks unavailable; mid-word rescue must kick in.
    let latex = #"\text{abcdefghijklmnopqrstuvwxyz}"#
    let wide = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20), maxWidth: 0)
    ).layout(latex: latex)
    let narrow = try MathRenderer(
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20), maxWidth: 40)
    ).layout(latex: latex)
    #expect(narrow.width <= 40 + 1)
    #expect(narrow.ascent + narrow.descent > wide.ascent + wide.descent + 1)
}

// MARK: - FontProviding injection

private struct EmptyFontProvider: FontProviding {
    func metrics(for font: MathFont) -> FontMetrics? { nil }
}

@Test func fontProvidingInjectionUsesSharedRegistry() throws {
    let renderer = MathRenderer(fonts: FontRegistry.shared)
    let display = try renderer.layout(latex: #"x^2"#)
    #expect(display.width > 0)
}

@Test func fontProvidingNilMetricsYieldsEmptyDisplay() throws {
    let renderer = MathRenderer(fonts: EmptyFontProvider())
    let display = try renderer.layout(latex: #"x^2"#)
    #expect(display.width == 0)
    #expect(display.children.isEmpty)
}

// MARK: - Normalize boundaries

@Test func normalizeDropsBareBoundary() {
    let list = MathList(atoms: [
        MathAtom.ordinary("a"),
        MathAtom.boundary("|"),
        MathAtom.ordinary("b")
    ])
    let normalized = MathNormalizer.normalize(list)
    #expect(normalized.atoms.count == 2)
    #expect(normalized.atoms.allSatisfy { $0.kind != .boundary })
}

@Test func normalizeKeepsMiddleInsideLeftRight() throws {
    let list = try MathParser.parse(#"\left( a \middle| b \right)"#)
    let normalized = MathNormalizer.normalize(list)
    #expect(normalized.atoms.count == 1)
    if case .inner(let inner) = normalized.atoms[0].payload {
        #expect(inner.contents.atoms.contains { $0.kind == .boundary })
    } else {
        Issue.record("Expected inner fence with preserved middle")
    }
}

// MARK: - Variant mapper

@Test func variantMapperItalicizesLetters() {
    let mapped = MathVariantMapper.mapNucleus("x", variant: .italic, kind: .variable)
    #expect(mapped != "x")
    let upright = MathVariantMapper.mapNucleus("x", variant: .upright, kind: .variable)
    #expect(upright == "x")
}

// MARK: - colorbox / macros / hline / delimiters

@Test func colorboxProducesBackgroundColoredPayload() throws {
    let list = try MathParser.parse(#"\colorbox{red}{x}"#)
    #expect(list.atoms.count == 1)
    if case .colored(let colored) = list.atoms[0].payload {
        #expect(colored.fillsBackground)
        #expect(colored.color == "red")
    } else {
        Issue.record("Expected colorbox payload")
    }
}

@Test func operatornameBuildsLargeOperator() throws {
    let list = try MathParser.parse(#"\operatorname{Hom}"#)
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0].kind == .largeOperator)
    #expect(list.atoms[0].nucleus == "Hom")
    #expect(!list.atoms[0].limits)

    let starred = try MathParser.parse(#"\operatorname*{argmax}"#)
    #expect(starred.atoms[0].limits)
    #expect(starred.atoms[0].nucleus == "argmax")
}

@Test func pmodBuildsInnerFence() throws {
    let list = try MathParser.parse(#"\pmod{n}"#)
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0].kind == .inner)
}

@Test func podAndBmodMacros() throws {
    let pod = try MathParser.parse(#"\pod{n}"#)
    #expect(pod.atoms.count == 2)
    #expect(pod.atoms[0].kind == .space)
    #expect(pod.atoms[1].kind == .inner)

    let bmod = try MathParser.parse(#"a \bmod b"#)
    #expect(bmod.atoms.contains { $0.kind == .binaryOperator && $0.nucleus == "mod" })
}

@Test func mathClassMacrosRewriteAtomKind() throws {
    let bin = try MathParser.parse(#"\mathbin{+}"#)
    #expect(bin.atoms[0].kind == .binaryOperator)

    let rel = try MathParser.parse(#"\mathrel{=}"#)
    #expect(rel.atoms[0].kind == .relation)

    let op = try MathParser.parse(#"\mathop{Q}"#)
    #expect(op.atoms[0].kind == .largeOperator)
    #expect(op.atoms[0].limits)

    let ord = try MathParser.parse(#"\mathord{+}"#)
    #expect(ord.atoms[0].kind == .ordinary)
}

@Test func tagMacroEmitsTagPayload() throws {
    let list = try MathParser.parse(#"x \tag{1}"#)
    #expect(list.atoms.contains { atom in
        if case .tag(let tag) = atom.payload {
            return tag.parenthesize
        }
        return false
    })
}

@Test func tagStarOmitsParenthesesFlag() throws {
    let list = try MathParser.parse(#"x \tag*{1}"#)
    #expect(list.atoms.contains { atom in
        if case .tag(let tag) = atom.payload {
            return !tag.parenthesize
        }
        return false
    })
}

@Test func tagFlushesRightWhenMaxWidthSet() throws {
    let env = MathEnvironment(
        font: MathFont(name: .latinModern, size: 20),
        style: .display,
        maxWidth: 200
    )
    let display = try MathRenderer(environment: env).layout(latex: #"E=mc^2 \tag{1}"#)
    #expect(abs(display.width - 200) <= 0.5)
    // Last child should be the tag near the right edge.
    let last = try #require(display.children.last)
    #expect(last.position.x + last.width >= 200 - 1)
}

@Test func tagSerializesRoundTripShape() throws {
    let list = try MathParser.parse(#"a \tag{n}"#)
    let latex = LatexSerializer.string(from: list)
    #expect(latex.contains(#"\tag{"#))
    let again = try MathParser.parse(latex)
    #expect(again.atoms.contains { if case .tag = $0.payload { return true }; return false })
}

@Test func pdfExportProducesNonEmptyData() throws {
    let data = try MathPDF.render(latex: #"a^2+b^2=c^2"#)
    #expect(data.count > 100)
    #expect(String(data: data.prefix(5), encoding: .ascii) == "%PDF-")
}

@Test func braKetBraketBuildInners() throws {
    let bra = try MathParser.parse(#"\bra{\psi}"#)
    #expect(bra.atoms[0].kind == .inner)
    let ket = try MathParser.parse(#"\ket{\psi}"#)
    #expect(ket.atoms[0].kind == .inner)
    let braket = try MathParser.parse(#"\braket{\phi}{\psi}"#)
    #expect(braket.atoms[0].kind == .inner)
}

@Test func arrayHLineRecordsBoundaries() throws {
    let list = try MathParser.parse(
        #"\begin{array}{c} \hline a \\ \hline b \\ \hline \end{array}"#
    )
    #expect(list.atoms.count == 1)
    if case .table(let table) = list.atoms[0].payload {
        #expect(table.hlines == [1, 1, 1])
        #expect(table.rows.count == 2)
    } else {
        Issue.record("Expected array table")
    }
}

@Test func hlineOutsideArrayFails() {
    #expect(throws: ParseError.self) {
        _ = try MathParser.parse(#"\begin{matrix} \hline a \end{matrix}"#)
    }
}

@Test func delimiterStripInjectsStyleAtom() throws {
    let display = try MathParser.parse(#"$$x$$"#)
    #expect(display.atoms.first?.kind == .style)
    if case .style(let style) = display.atoms.first?.payload {
        #expect(style == .display)
    }

    let text = try MathParser.parse(#"$x$"#)
    if case .style(let style) = text.atoms.first?.payload {
        #expect(style == .text)
    }
}

@Test func bigMultiplierUsesSwiftMathCurve() {
    #expect(DelimiterCommands.sizeMultipliers["Big"] == 1.4)
}

@Test func wrapPrefersBreakBeforeRelation() {
    let rel = MathAtom.relation("=")
    let letter = MathAtom.variable("a")
    #expect(WrapLayout.canBreakBefore(rel, previous: letter))
    #expect(WrapLayout.canBreakBefore(MathAtom(kind: .fraction), previous: letter))
}

@Test func colorboxLayoutProducesBackgroundDisplay() throws {
    let display = try MathRenderer().layout(latex: #"\colorbox{#ff0000}{x}"#)
    let hasBackground = display.children.contains { node in
        if case .colored(let c) = node { return c.fillsBackground }
        return false
    }
    #expect(hasBackground)
}

@Test func fallbackGlyphUsesSystemFontForMissingChar() {
    let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20))
    // Private-use / emoji — guaranteed missing from Latin Modern Math.
    let list = MathList(atoms: [MathAtom.ordinary("😀")])
    let display = Typesetter.createDisplay(for: list, environment: env)
    #expect(display.width > 0)

    func usesFallback(_ node: DisplayNode) -> Bool {
        switch node {
        case .glyphs(let run):
            return run.usesSystemFallback || run.fallbackFontName != nil
        case .list(let list):
            return list.children.contains(where: usesFallback)
        default:
            return false
        }
    }
    #expect(display.children.contains(where: usesFallback))
}
