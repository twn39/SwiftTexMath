import Testing
@testable import SwiftTexMathCore

@Suite("SVG Vector Export Snapshots")
struct SVGSnapshotTests {

    @Test("Algebraic Equation SVG Snapshot")
    func testSVGAlgebraicEquation() throws {
        let result = try MathSVG.render(latex: #"E = mc^2"#)
        assertSnapshot(matching: result, as: .svg, named: "algebraic_equation")
    }

    @Test("Quadratic Formula SVG Snapshot")
    func testSVGFractionAndRadical() throws {
        let result = try MathSVG.render(latex: #"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#)
        assertSnapshot(matching: result, as: .svg, named: "quadratic_formula")
    }

    @Test("Matrix PMatrix SVG Snapshot")
    func testSVGMatrixPMatrix() throws {
        let result = try MathSVG.render(latex: #"\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}"#)
        assertSnapshot(matching: result, as: .svg, named: "identity_matrix")
    }

    @Test("Colorbox and Accents SVG Snapshot")
    func testSVGColorboxAndAccents() throws {
        let result = try MathSVG.render(latex: #"\colorbox{#ffcc00}{x^2} + \hat{xyz}"#)
        assertSnapshot(matching: result, as: .svg, named: "colorbox_accent")
    }

    @Test("Sum and Integral SVG Snapshot")
    func testSVGSumAndIntegral() throws {
        let result = try MathSVG.render(latex: #"\sum_{i=1}^{n} i + \int_0^1 x\,dx"#)
        assertSnapshot(matching: result, as: .svg, named: "sum_integral")
    }

    @Test("Underbrace and Vector SVG Snapshot")
    func testSVGUnderbraceAndVector() throws {
        let result = try MathSVG.render(latex: #"\underbrace{a+b+c}_{3} + \overrightarrow{AB}"#)
        assertSnapshot(matching: result, as: .svg, named: "underbrace_vector")
    }

    @Test("Custom Options SVG Snapshot")
    func testSVGCustomOptions() throws {
        let display = try MathRenderer().layout(latex: #"\frac{1}{2}"#)
        let options = MathSVG.Options(
            padding: 4,
            foregroundCSS: "#0000ff",
            backgroundCSS: "#f0f0f0",
            includeXMLDeclaration: true,
            precision: 3
        )
        let result = MathSVG.render(display: display, options: options)
        assertSnapshot(matching: result, as: .svg, named: "custom_svg_options")
    }

    @Test("Multivariable Calculus Integrals SVG Snapshot")
    func testSVGMultivariableCalculus() throws {
        let result = try MathSVG.render(latex: #"\iiint_V f(x,y,z)\,dV + \oint_C \mathbf{F}\cdot d\mathbf{r}"#)
        assertSnapshot(matching: result, as: .svg, named: "multivariable_calculus")
    }

    @Test("Maxwell Equations & Partial Derivatives SVG Snapshot")
    func testSVGMaxwellEquations() throws {
        let result = try MathSVG.render(latex: #"\nabla \times \mathbf{E} = -\frac{\partial \mathbf{B}}{\partial t}"#)
        assertSnapshot(matching: result, as: .svg, named: "maxwell_equations")
    }

    @Test("Continued Fraction SVG Snapshot")
    func testSVGContinuedFraction() throws {
        let result = try MathSVG.render(latex: #"\cfrac{1}{1 + \cfrac{1}{2 + \cfrac{1}{3 + x}}}"#)
        assertSnapshot(matching: result, as: .svg, named: "continued_fraction")
    }

    @Test("Nested Roots & N-th Root SVG Snapshot")
    func testSVGNestedRoots() throws {
        let result = try MathSVG.render(latex: #"\sqrt[3]{1 + \sqrt{2 + \sqrt{x}}}"#)
        assertSnapshot(matching: result, as: .svg, named: "nested_roots")
    }

    @Test("BMatrix and Cases Environment SVG Snapshot")
    func testSVGComplexMatrixAndCases() throws {
        let result = try MathSVG.render(latex: #"\begin{bmatrix} a & b \\ c & d \end{bmatrix} + \begin{cases} x^2 & x > 0 \\ 0 & x \le 0 \end{cases}"#)
        assertSnapshot(matching: result, as: .svg, named: "bmatrix_and_cases")
    }

    @Test("Greek, MathBB, MathCal & OperatorName SVG Snapshot")
    func testSVGGreekAndFontVariants() throws {
        let result = try MathSVG.render(latex: #"\alpha \beta \gamma \in \mathbb{R}^n \quad \mathcal{L}(f) \quad \operatorname{Hom}(V, W)"#)
        assertSnapshot(matching: result, as: .svg, named: "greek_and_fonts")
    }

    @Test("Overbrace & Stretchy Delimiters SVG Snapshot")
    func testSVGOverbraceAndStretchyDelims() throws {
        let result = try MathSVG.render(latex: #"\overbrace{x_1 + \dots + x_n}^{n} = \left\langle \frac{a}{b}, \frac{c}{d} \right\rangle"#)
        assertSnapshot(matching: result, as: .svg, named: "overbrace_stretchy_delims")
    }
}
