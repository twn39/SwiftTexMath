import CoreGraphics
import Testing
@testable import SwiftTexMathCore

// MARK: - \newcommand / \def

@Test func newcommandZeroArgExpands() throws {
    let list = try MathParser.parse(#"\newcommand{\foo}{x+y}\foo"#)
    #expect(list.atoms.count >= 3)
    #expect(list.atoms.contains { $0.kind == .binaryOperator && $0.nucleus == "+" })
}

@Test func newcommandWithParameters() throws {
    let list = try MathParser.parse(#"\newcommand{\swap}[2]{#2+#1}\swap{a}{b}"#)
    #expect(list.atoms.count >= 3)
    // b + a
    #expect(list.atoms[0].nucleus == "b" || list.atoms[0].kind == .variable)
    #expect(list.atoms.contains { $0.nucleus == "a" })
}

@Test func newcommandDuplicateFails() throws {
    #expect(throws: ParseError.self) {
        _ = try MathParser.parse(#"\newcommand{\foo}{a}\newcommand{\foo}{b}"#)
    }
}

@Test func renewcommandOverwrites() throws {
    let list = try MathParser.parse(
        #"\newcommand{\foo}{a}\renewcommand{\foo}{b}\foo"#
    )
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0].nucleus == "b")
}

@Test func providecommandSkipsIfDefined() throws {
    let list = try MathParser.parse(
        #"\newcommand{\foo}{a}\providecommand{\foo}{b}\foo"#
    )
    #expect(list.atoms[0].nucleus == "a")
}

@Test func defWithParameters() throws {
    let list = try MathParser.parse(#"\def\add#1#2{#1+#2}\add{1}{2}"#)
    #expect(list.atoms.contains { $0.nucleus == "1" })
    #expect(list.atoms.contains { $0.nucleus == "2" })
    #expect(list.atoms.contains { $0.kind == .binaryOperator })
}

@Test func macroHashEscape() throws {
    // `##` → literal `#` in the expansion stream; then `1` as ordinary digit.
    let list = try MathParser.parse(#"\newcommand{\hash}{##1}\hash"#)
    #expect(list.atoms.contains { $0.nucleus == "#" || $0.nucleus.contains("#") || $0.nucleus == "1" })
}

@Test func macroExpansionLayouts() throws {
    let display = try MathRenderer().layout(
        latex: #"\newcommand{\qq}[1]{#1^2}\qq{x}"#
    )
    #expect(display.width > 0)
    #expect(display.ascent > 0)
}

// MARK: - \intertext

@Test func intertextInAlignedParses() throws {
    let list = try MathParser.parse(
        #"\begin{aligned} a &= b \\ \intertext{note} c &= d \end{aligned}"#
    )
    #expect(list.atoms.count == 1)
    guard case .table(let table) = list.atoms[0].payload else {
        Issue.record("expected table")
        return
    }
    #expect(table.rows.count == 3)
    #expect(table.fullWidthRows.contains(1))
}

@Test func intertextLayoutsPositiveSize() throws {
    let display = try MathRenderer().layout(
        latex: #"\begin{aligned} a &= b \\ \intertext{and} c &= d \end{aligned}"#
    )
    #expect(display.width > 0)
    #expect(display.ascent + display.descent > 0)
}

@Test func intertextOutsideAlignFailsAtTableBoundary() throws {
    // `\intertext` as a free command is not registered — unknown command.
    #expect(throws: ParseError.self) {
        _ = try MathParser.parse(#"a \intertext{x} b"#)
    }
}
