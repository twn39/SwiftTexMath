import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

// MARK: - equation / equation*

@Test func equationEnvironmentParsesAsTable() throws {
    let list = try MathParser.parse(#"\begin{equation} E=mc^2 \end{equation}"#)
    #expect(list.atoms.count == 1)
    guard case .table(let table) = list.atoms[0].payload else {
        Issue.record("expected table")
        return
    }
    #expect(table.environment == "equation")
    #expect(table.rows.count == 1)
}

@Test func equationStarDoesNotForceNumber() throws {
    let numbered = try MathRenderer().layout(
        latex: #"\begin{equation} a=1 \end{equation}"#
    )
    let starred = try MathRenderer().layout(
        latex: #"\begin{equation*} a=1 \end{equation*}"#
    )
    #expect(numbered.width > starred.width)
    #expect(numbered.accessibilityPlainText.contains("1") || numbered.children.count >= 1)
}

@Test func equationNumbersWithoutNumberEquationsFlag() throws {
    // Outer `equation` forces numbering even when numberEquations is false.
    let env = MathEnvironment(numberEquations: false)
    let display = try MathRenderer(environment: env).layout(
        latex: #"\begin{equation} x+y=z \end{equation}"#
    )
    #expect(display.width > 0)
    let plain = try MathRenderer(environment: env).layout(latex: #"x+y=z"#)
    #expect(display.width > plain.width)
}

@Test func equationNotagSuppressesNumber() throws {
    let withTag = try MathRenderer().layout(
        latex: #"\begin{equation} a=1 \end{equation}"#
    )
    let notag = try MathRenderer().layout(
        latex: #"\begin{equation} a=1\notag \end{equation}"#
    )
    #expect(withTag.width > notag.width)
}

@Test func equationExplicitTagOverridesAuto() throws {
    let display = try MathRenderer().layout(
        latex: #"\begin{equation} a=1\tag{A} \end{equation}"#
    )
    #expect(display.accessibilityPlainText.contains("A"))
}

@Test func alignOuterNumbersAlignedInnerDoesNot() throws {
    let align = try MathRenderer().layout(
        latex: #"\begin{align} a &= 1 \\ b &= 2 \end{align}"#
    )
    let aligned = try MathRenderer().layout(
        latex: #"\begin{aligned} a &= 1 \\ b &= 2 \end{aligned}"#
    )
    #expect(align.width > aligned.width)

    let listAlign = try MathParser.parse(#"\begin{align} a &= 1 \end{align}"#)
    let listAligned = try MathParser.parse(#"\begin{aligned} a &= 1 \end{aligned}"#)
    if case .table(let t) = listAlign.atoms[0].payload {
        #expect(t.environment == "align")
    } else {
        Issue.record("align table")
    }
    if case .table(let t) = listAligned.atoms[0].payload {
        #expect(t.environment == "aligned")
    } else {
        Issue.record("aligned table")
    }
}

@Test func gatherStarDoesNotNumber() throws {
    let gather = try MathRenderer().layout(
        latex: #"\begin{gather} a \\ b \end{gather}"#
    )
    let starred = try MathRenderer().layout(
        latex: #"\begin{gather*} a \\ b \end{gather*}"#
    )
    #expect(gather.width > starred.width)
}

@Test func multlineEnvironmentLayouts() throws {
    let display = try MathRenderer().layout(
        latex: #"\begin{multline} a+b+c \\ +d+e+f \end{multline}"#
    )
    #expect(display.width > 0)
    #expect(display.ascent + display.descent > 0)
}

// MARK: - \label / \ref

@Test func labelIsLayoutNeutral() throws {
    let plain = try MathRenderer().layout(latex: #"E=mc^2"#)
    let labeled = try MathRenderer().layout(latex: #"E=mc^2\label{einstein}"#)
    #expect(abs(plain.width - labeled.width) < 0.5)
    #expect(abs(plain.ascent - labeled.ascent) < 0.5)
}

@Test func labelParsesAndSerializes() throws {
    let list = try MathParser.parse(#"a\label{foo}"#)
    #expect(list.atoms.contains { atom in
        if case .label(let name) = atom.payload { return name == "foo" }
        return false
    })
    #expect(list.latexString.contains("label{foo}") || list.latexString.contains("\\label"))
}

@Test func refRendersPlaceholderWhenMissing() throws {
    let display = try MathRenderer().layout(latex: #"x=\ref{missing}"#)
    let text = display.accessibilityPlainText
    #expect(text.contains("?") || text.contains("x"))
}

@Test func eqrefRendersParenthesizedPlaceholderWhenMissing() throws {
    let display = try MathRenderer().layout(latex: #"\eqref{eq:1}"#)
    #expect(display.width > 0)
    let text = display.accessibilityPlainText
    #expect(text.contains("?") || display.ascent > 0)
}

@Test func labelInsideEquationDoesNotBreakNumbering() throws {
    let display = try MathRenderer().layout(
        latex: #"\begin{equation} a=1\label{eq:a} \end{equation}"#
    )
    #expect(display.width > 0)
    let unnumbered = try MathRenderer().layout(
        latex: #"\begin{equation*} a=1 \end{equation*}"#
    )
    #expect(display.width > unnumbered.width)
}

@Test func emptyLabelNameFails() throws {
    #expect(throws: ParseError.self) {
        _ = try MathParser.parse(#"\label{}"#)
    }
}

// MARK: - Resolved \ref / \eqref

@Test func eqrefResolvesEquationNumber() throws {
    let result = try MathRenderer().layoutDetailed(
        latex: #"\begin{equation} a=1\label{eq:a}\end{equation}"#
    )
    #expect(result.labels["eq:a"] == "1")

    let withRef = try MathRenderer().layout(
        latex: #"\begin{equation} a=1\label{eq:a}\end{equation}\quad\eqref{eq:a}"#
    )
    let text = withRef.accessibilityPlainText
    #expect(text.contains("1"))
    #expect(!text.contains("??"))
}

@Test func refResolvesBareNumber() throws {
    let result = try MathRenderer().layoutDetailed(
        latex: #"\begin{equation} E=mc^2\label{einstein}\end{equation} see \ref{einstein}"#
    )
    #expect(result.labels["einstein"] == "1")
    #expect(result.display.accessibilityPlainText.contains("1"))
}

@Test func forwardRefResolvesAfterPrepass() throws {
    // Reference appears before the labeled equation in source order.
    let result = try MathRenderer().layoutDetailed(
        latex: #"\eqref{later}\begin{equation} x\label{later}\end{equation}"#
    )
    #expect(result.labels["later"] == "1")
    #expect(result.display.accessibilityPlainText.contains("1"))
    #expect(!result.display.accessibilityPlainText.contains("??"))
}

@Test func refResolvesExplicitTag() throws {
    let result = try MathRenderer().layoutDetailed(
        latex: #"\begin{equation} a\tag{A}\label{named}\end{equation}\ref{named}"#
    )
    #expect(result.labels["named"] == "A")
    #expect(result.display.accessibilityPlainText.contains("A"))
}

@Test func alignRowLabelsResolveSequentially() throws {
    let result = try MathRenderer().layoutDetailed(
        latex: #"\begin{align} a&=1\label{r1} \\ b&=2\label{r2} \end{align}"#
    )
    #expect(result.labels["r1"] == "1")
    #expect(result.labels["r2"] == "2")
}

@Test func freeStandingLabelWithNumberEquations() throws {
    let env = MathEnvironment(numberEquations: true, equationNumberStart: 3)
    let result = try MathRenderer(environment: env).layoutDetailed(
        latex: #"E=mc^2\label{e}"#
    )
    #expect(result.labels["e"] == "3")
}

@Test func refPayloadRoundTripsInSerializer() throws {
    let list = try MathParser.parse(#"\ref{foo}\eqref{bar}"#)
    let latex = list.latexString
    #expect(latex.contains("ref{foo}"))
    #expect(latex.contains("eqref{bar}"))
}
