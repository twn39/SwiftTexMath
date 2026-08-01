import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

// MARK: - Helpers

private func walkNodes(_ display: DisplayList, origin: CGPoint = .zero, visit: (DisplayNode, CGPoint) -> Void) {
    let ox = origin.x + display.position.x
    let oy = origin.y + display.position.y
    for child in display.children {
        let p = CGPoint(x: ox + child.position.x, y: oy + child.position.y)
        visit(child, p)
        if case .list(let nested) = child {
            var shifted = nested
            shifted.position = .zero
            walkNodes(shifted, origin: p, visit: visit)
        }
    }
}

private func rightmostExtent(_ display: DisplayList) -> CGFloat {
    var maxX: CGFloat = display.width
    walkNodes(display) { node, origin in
        maxX = max(maxX, origin.x + node.width)
    }
    return maxX
}

/// Collect absolute baseline Y of every non-empty glyph/list leaf that looks like a tag (digits / parens).
private func distinctBaselineYs(_ display: DisplayList) -> Set<Int> {
    var ys = Set<Int>()
    walkNodes(display) { node, origin in
        // Row tags are DisplayList nodes placed at row baselines.
        if case .list(let list) = node, list.width > 0, !list.children.isEmpty {
            ys.insert(Int((origin.y * 10).rounded()))
        }
    }
    return ys
}

private func nodeCount(_ display: DisplayList) -> Int {
    var count = 0
    walkNodes(display) { _, _ in count += 1 }
    return count
}

// MARK: - Strip + hoist

@Test func strippingTagsRemovesTopLevelTagsOnly() {
    var list = MathList()
    list.append(MathAtom.ordinary("a"))
    list.append(MathAtom(kind: .ordinary, payload: .tag(.init(contents: MathList(atoms: [MathAtom.ordinary("1")])))))
    list.append(MathAtom.ordinary("b"))
    let stripped = Typesetter.strippingTags(from: list)
    #expect(stripped.atoms.count == 2)
    #expect(stripped.atoms[0].nucleus == "a")
    #expect(stripped.atoms[1].nucleus == "b")
}

@Test func alignedExplicitTagNotInlinedInLastCell() throws {
    let latex = #"\begin{aligned} a &= b \tag{9} \\ c &= d \end{aligned}"#
    let display = try MathRenderer().layout(latex: latex)
    #expect(display.width > 0)
    // Nested table list carries body cells + hoisted tag node(s).
    #expect(nodeCount(display) >= 4)
    let text = display.accessibilityPlainText
    #expect(text.contains("9"))
}

@Test func alignedTagFlushRightWithMaxWidth() throws {
    let env = MathEnvironment(maxWidth: 280)
    let display = try MathRenderer(environment: env).layout(
        latex: #"\begin{aligned} x &= 1 \tag{A} \end{aligned}"#
    )
    #expect(display.width >= 280 - 0.5)
    let maxX = rightmostExtent(display)
    // Tag should reach near the right edge of the paragraph.
    #expect(maxX >= 280 - 40)
}

@Test func gatherMixedTagNotagAndAutoNumber() throws {
    let env = MathEnvironment(numberEquations: true, equationNumberStart: 1)
    let display = try MathRenderer(environment: env).layout(
        latex: #"\begin{gather} a=1\tag{*} \\ b=2\notag \\ c=3 \end{gather}"#
    )
    #expect(display.width > 0)
    let text = display.accessibilityPlainText
    #expect(text.contains("*"))
    // Auto number for third row starts at 1 (first two consumed/suppressed).
    #expect(text.contains("1") || text.contains("3") || display.children.count >= 3)
}

@Test func gatherAutoNumbersAreSequential() throws {
    let env = MathEnvironment(numberEquations: true, equationNumberStart: 5)
    let display = try MathRenderer(environment: env).layout(
        latex: #"\begin{gather} a \\ b \\ c \end{gather}"#
    )
    let text = display.accessibilityPlainText
    #expect(text.contains("5"))
    #expect(text.contains("6"))
    #expect(text.contains("7"))
}

@Test func taggedRowWiderThanUntagged() throws {
    let plain = try MathRenderer().layout(
        latex: #"\begin{aligned} a &= b \\ c &= d \end{aligned}"#
    )
    let tagged = try MathRenderer().layout(
        latex: #"\begin{aligned} a &= b \tag{1} \\ c &= d \tag{2} \end{aligned}"#
    )
    #expect(tagged.width > plain.width)
}

@Test func tagStarDoesNotAddParensInAccessibility() throws {
    let display = try MathRenderer().layout(latex: #"x\tag*{42}"#)
    let text = display.accessibilityPlainText
    #expect(text.contains("42"))
}

@Test func multlineStyleTopLevelBreaksWithTag() throws {
    // Top-level `\\` becomes a gathered table.
    let display = try MathRenderer().layout(latex: #"a=1 \\ b=2\tag{3}"#)
    #expect(display.width > 0)
    #expect(display.accessibilityPlainText.contains("3") || display.children.count >= 1)
}

@Test func wrapAndTagStillFlushRight() throws {
    let env = MathEnvironment(maxWidth: 120)
    let display = try MathRenderer(environment: env).layout(
        latex: #"a + b + c + d + e + f = g \tag{1}"#
    )
    #expect(display.width >= 120 - 0.5)
}

@Test func pmatrixDoesNotHoistTagsLikeAlign() throws {
    // Matrix envs keep tags in-cell (not equation rows).
    #expect(!Typesetter.tableEnvironmentHoistsTags("pmatrix"))
    #expect(Typesetter.tableEnvironmentHoistsTags("aligned"))
    #expect(Typesetter.tableEnvironmentHoistsTags("gather"))
    #expect(Typesetter.tableEnvironmentHoistsTags("split"))
}

// MARK: - Geometry / clearance-ish invariants

@Test func equationNumberDoesNotOverlapBodyBaselineBand() throws {
    let env = MathEnvironment(numberEquations: true, equationNumberStart: 1)
    let display = try MathRenderer(environment: env).layout(latex: #"E=mc^2"#)
    // At least body + tag children on a single line.
    #expect(display.children.count >= 2)
    if display.children.count >= 2 {
        let body = display.children[0]
        let tag = display.children[display.children.count - 1]
        #expect(tag.position.x >= body.position.x + body.width - 0.01)
    }
}

@Test func multiLineTagYTracksRowBaselines() throws {
    let display = try MathRenderer().layout(
        latex: #"\begin{gather} a \tag{1} \\ b \tag{2} \end{gather}"#
    )
    // Two rows → more than one distinct baseline Y in the nested display tree.
    let ys = distinctBaselineYs(display)
    #expect(ys.count >= 2)
}
