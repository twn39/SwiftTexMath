import Testing
@testable import SwiftTexMathCore

@Suite("DisplayList Node Tree Snapshots")
struct DisplayListSnapshotTests {

    @Test("Simple Equation DisplayList Tree Snapshot")
    func testDisplayListSimpleEquation() throws {
        let display = try MathRenderer().layout(latex: #"a + b = c"#)
        assertSnapshot(matching: display, as: .displayTree, named: "simple_equation_tree")
    }

    @Test("Fraction DisplayList Tree Snapshot")
    func testDisplayListFractionTree() throws {
        let display = try MathRenderer().layout(latex: #"\frac{a+1}{b+2}"#)
        assertSnapshot(matching: display, as: .displayTree, named: "fraction_tree")
    }

    @Test("Radical DisplayList Tree Snapshot")
    func testDisplayListRadicalTree() throws {
        let display = try MathRenderer().layout(latex: #"\sqrt{x^2+y^2}"#)
        assertSnapshot(matching: display, as: .displayTree, named: "radical_tree")
    }

    @Test("Aligned DisplayList Tree Snapshot")
    func testDisplayListAlignedTree() throws {
        let display = try MathRenderer().layout(latex: #"\begin{aligned} a &= b \\ c &= d \end{aligned}"#)
        assertSnapshot(matching: display, as: .displayTree, named: "aligned_tree")
    }

    @Test("Large Operator DisplayList Tree Snapshot")
    func testDisplayListLargeOperatorTree() throws {
        let display = try MathRenderer().layout(latex: #"\sum_{i=1}^{n} i"#)
        assertSnapshot(matching: display, as: .displayTree, named: "sum_tree")
    }

    @Test("Colorbox DisplayList Tree Snapshot")
    func testDisplayListColorboxTree() throws {
        let display = try MathRenderer().layout(latex: #"\colorbox{#ff0000}{x}"#)
        assertSnapshot(matching: display, as: .displayTree, named: "colorbox_tree")
    }

    @Test("Multivariable Integral DisplayList Tree Snapshot")
    func testDisplayListMultivariableIntegralTree() throws {
        let display = try MathRenderer().layout(latex: #"\iiint_V f(x,y,z)\,dV"#)
        assertSnapshot(matching: display, as: .displayTree, named: "iiint_tree")
    }

    @Test("Partial Derivative DisplayList Tree Snapshot")
    func testDisplayListPartialDerivativeTree() throws {
        let display = try MathRenderer().layout(latex: #"\frac{\partial^2 u}{\partial x^2} + \frac{\partial^2 u}{\partial y^2} = 0"#)
        assertSnapshot(matching: display, as: .displayTree, named: "partial_derivative_tree")
    }

    @Test("Continued Fraction DisplayList Tree Snapshot")
    func testDisplayListContinuedFractionTree() throws {
        let display = try MathRenderer().layout(latex: #"\cfrac{1}{1 + \cfrac{1}{x}}"#)
        assertSnapshot(matching: display, as: .displayTree, named: "cfrac_tree")
    }

    @Test("Overbrace DisplayList Tree Snapshot")
    func testDisplayListOverbraceTree() throws {
        let display = try MathRenderer().layout(latex: #"\overbrace{a + b}^{2}"#)
        assertSnapshot(matching: display, as: .displayTree, named: "overbrace_tree")
    }

    @Test("BMatrix DisplayList Tree Snapshot")
    func testDisplayListBMatrixTree() throws {
        let display = try MathRenderer().layout(latex: #"\begin{bmatrix} a & b \\ c & d \end{bmatrix}"#)
        assertSnapshot(matching: display, as: .displayTree, named: "bmatrix_tree")
    }
}
