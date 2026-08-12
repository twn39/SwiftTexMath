import CoreGraphics
import Testing
@testable import SwiftTexMathCore

@Suite("PNG Image Raster Snapshots")
struct PNGSnapshotTests {

    static let renderOptions = MathImage.Options(
        scale: 2,
        padding: 2,
        foregroundColor: CGColor(gray: 0, alpha: 1),
        backgroundColor: CGColor(gray: 1, alpha: 1)
    )

    @Test("Simple Equals PNG Image Snapshot")
    func testPNGRenderSimpleEquals() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"E = mc^2"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "simple_equals_png")
    }

    @Test("Quadratic Formula PNG Image Snapshot")
    func testPNGRenderQuadraticFormula() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "quadratic_png")
    }

    @Test("Matrix PMatrix PNG Image Snapshot")
    func testPNGRenderMatrix() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "pmatrix_png")
    }

    @Test("Colorbox PNG Image Snapshot")
    func testPNGRenderColorbox() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 24), style: .display)
        let result = try MathImage.render(latex: #"\colorbox{#ffcc00}{x^2}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "colorbox_png")
    }

    @Test("Maxwell Equations PNG Image Snapshot")
    func testPNGRenderMaxwellEquations() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\nabla \times \mathbf{E} = -\frac{\partial \mathbf{B}}{\partial t}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "maxwell_png")
    }

    @Test("Cases Environment PNG Image Snapshot")
    func testPNGRenderCases() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"f(x) = \begin{cases} x^2 & x > 0 \\ 0 & x \le 0 \end{cases}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "cases_png")
    }

    @Test("Overbrace PNG Image Snapshot")
    func testPNGRenderOverbrace() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\overbrace{a + b + c}^{3}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "overbrace_png")
    }

    @Test("Primes and Derivatives PNG Image Snapshot")
    func testPNGRenderPrimesAndDerivatives() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"f'(x) + g''(x) + \vec{v}'_f"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "primes_derivatives_png")
    }

    @Test("Single Sided Delimiters PNG Image Snapshot")
    func testPNGRenderSingleSidedDelimiter() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\left. \frac{\partial f}{\partial x} \right|_{x=0}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "single_sided_delimiter_png")
    }

    @Test("Extensible Arrows PNG Image Snapshot")
    func testPNGRenderExtensibleArrows() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\overrightarrow{A + B + C} + \overleftarrow{D + E}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "extensible_arrows_png")
    }

    @Test("Matrix with Tall Fractions PNG Image Snapshot")
    func testPNGRenderMatrixWithFractions() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\begin{bmatrix} \frac{1}{2} & 0 \\ 0 & \frac{1}{3} \end{bmatrix}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "matrix_fractions_png")
    }

    @Test("Tower of Powers PNG Image Snapshot")
    func testPNGRenderTowerOfPowers() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"a^{b^{c^d}}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "tower_of_powers_png")
    }

    @Test("Nested Radicals PNG Image Snapshot")
    func testPNGRenderNestedRadicals() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\sqrt{1 + \sqrt{2 + \sqrt{x}}}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "nested_radicals_png")
    }

    @Test("Cancel and Color Strike PNG Image Snapshot")
    func testPNGRenderCancelAndColor() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\cancel{a+b} + \colorbox{#ffcc00}{x}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "cancel_color_png")
    }

    @Test("Multivariable Integrals PNG Image Snapshot")
    func testPNGRenderMultivariableIntegrals() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\iiint_V f(x,y,z)\,dV + \oint_C \mathbf{F}\cdot d\mathbf{r}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "iiint_png")
    }

    @Test("Greek MathBB and OperatorName PNG Image Snapshot")
    func testPNGRenderGreekMathBBAndOperators() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\alpha \beta \gamma \in \mathbb{R}^n \quad \operatorname{Ker}(A)"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "greek_mathbb_png")
    }

    @Test("Subscripts and Superscripts PNG Image Snapshot")
    func testPNGRenderSubscriptsSuperscripts() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"x_{i,j}^{k+1} + e^{-x^2}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "subscripts_superscripts_png")
    }

    @Test("Graded Sized Delimiters PNG Image Snapshot")
    func testPNGRenderGradedDelimiters() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\bigl( \Bigl( \biggl( \Biggl( x \Biggr) \biggr) \Bigr) \bigr)"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "graded_delimiters_png")
    }

    @Test("Limits vs Nolimits Override PNG Image Snapshot")
    func testPNGRenderLimitsVsNoLimits() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\sum\limits_{i=1}^n x_i + \int\nolimits_0^1 f(x)\,dx"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "limits_override_png")
    }

    @Test("Under Accents PNG Image Snapshot")
    func testPNGRenderUnderAccents() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\underbar{a+b} + \utilde{x}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "under_accents_png")
    }

    @Test("Prescripts and Empty Base PNG Image Snapshot")
    func testPNGRenderPrescriptsAndEmptyBase() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"{}_2F_1(a,b;c;z) + {}^2x"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "prescripts_png")
    }

    @Test("Math Spaces PNG Image Snapshot")
    func testPNGRenderMathSpaces() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"a \, b \: c \; d \quad e \qquad f \! g"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "math_spaces_png")
    }

    @Test("Phantom and VPhantom PNG Image Snapshot")
    func testPNGRenderPhantomAndVPhantom() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"a \phantom{+ b} + c + \sqrt{\vphantom{b} a}"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "phantoms_png")
    }

    @Test("Binomial Variants PNG Image Snapshot")
    func testPNGRenderBinomialVariants() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\left(\binom{n}{k}\right) + \left(\dbinom{n}{n-k}\right) + \left(\tbinom{n}{0}\right)"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "binomials_png")
    }

    @Test("Norms and Angle Brackets PNG Image Snapshot")
    func testPNGRenderNormsAndAngles() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let result = try MathImage.render(latex: #"\left\| \frac{x}{y} \right\| + \left\langle \frac{a}{b} \right\rangle"#, environment: env, options: Self.renderOptions)
        assertSnapshot(matching: result.image, as: .pngData, named: "norms_angles_png")
    }
}
