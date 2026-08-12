import Testing
@testable import SwiftTexMathCore

@Suite("OperatorName & Script Detail Tests")
struct OperatorNameAndScriptDetailTests {
    @Test("OperatorName limits in display vs text style")
    func testOperatorNameLimitsStyles() throws {
        let displayList = try MathParser.parse(#"\displaystyle \operatorname*{max}_{x \to 0} f(x)"#)
        let textList = try MathParser.parse(#"\textstyle \operatorname*{max}_{x \to 0} f(x)"#)

        let renderer = MathRenderer()
        let displayNode = renderer.layout(displayList)
        let textNode = renderer.layout(textList)

        #expect(displayNode.ascent > 0)
        #expect(textNode.ascent > 0)
    }

    @Test("Complex scripts with commas and multiple indices")
    func testComplexScripts() throws {
        let scriptList = try MathParser.parse(#"A_{i,j}^{k,l} + B_{123}^{456}"#)
        let renderer = MathRenderer()
        let display = renderer.layout(scriptList)

        #expect(display.width > 30)
        #expect(!display.children.isEmpty)
    }

    @Test("Empty base with superscript and subscript")
    func testEmptyBaseScripts() throws {
        let emptyBaseList = try MathParser.parse(#"{}_{1}^{2} X"#)
        let renderer = MathRenderer()
        let display = renderer.layout(emptyBaseList)

        #expect(display.width > 10)
    }

    @Test("Array environment with mixed alignments lcr and hline")
    func testArrayMixedAlignmentAndHline() throws {
        let arrayList = try MathParser.parse(#"\begin{array}{lcr} a & b & c \\ \hline d & e & f \end{array}"#)
        let renderer = MathRenderer()
        let display = renderer.layout(arrayList)

        #expect(display.width > 20)
        #expect(display.ascent > 10)
    }
}
