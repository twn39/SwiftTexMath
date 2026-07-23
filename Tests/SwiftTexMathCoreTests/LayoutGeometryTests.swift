import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Numeric layout goldens at Latin Modern 20pt (display style).
/// Values measured from the current typesetter; tolerance ±0.02 mirrors
/// swiftui-math / iosMath TypesetterTests (±0.01) with a small platform cushion.
@Suite("Layout geometry")
struct LayoutGeometryTests {
    private let tolerance: CGFloat = 0.02

    private var renderer: MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display
            )
        )
    }

    private func expectSize(
        _ latex: String,
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let display = try renderer.layout(latex: latex)
        #expect(abs(display.ascent - ascent) <= tolerance, "ascent for \(latex)", sourceLocation: sourceLocation)
        #expect(abs(display.descent - descent) <= tolerance, "descent for \(latex)", sourceLocation: sourceLocation)
        #expect(abs(display.width - width) <= tolerance, "width for \(latex)", sourceLocation: sourceLocation)
    }

    @Test func simpleVariable() throws {
        try expectSize("x", ascent: 8.84, descent: 0.22, width: 11.44)
    }

    @Test func multipleVariables() throws {
        try expectSize("xyzw", ascent: 8.84, descent: 4.10, width: 44.86)
    }

    @Test func variablesAndNumber() throws {
        // xy2w — digit raises ascent vs plain letters
        try expectSize("xy2w", ascent: 13.32, descent: 4.10, width: 45.56)
    }

    @Test func fraction() throws {
        try expectSize(#"\frac{1}{2}"#, ascent: 26.86, descent: 13.72, width: 10.0)
    }

    @Test func radical() throws {
        try expectSize(#"\sqrt{2}"#, ascent: 17.88, descent: 19.20, width: 26.66)
    }

    @Test func radicalWithDegree() throws {
        try expectSize(#"\sqrt[3]{x}"#, ascent: 13.40, descent: 19.20, width: 27.54)
    }

    @Test func accent() throws {
        try expectSize(#"\hat{x}"#, ascent: 14.68, descent: 0.22, width: 11.86)
    }

    @Test func equationWithOperators() throws {
        try expectSize("x+y", ascent: 11.66, descent: 4.10, width: 45.68888888888888)
    }

    @Test func relationSpacingWidth() throws {
        try expectSize("a=b", ascent: 13.88, descent: 0.22, width: 45.83111111111111)
    }

    @Test func scriptsRaiseAscent() throws {
        try expectSize("x^2", ascent: 16.584, descent: 0.22, width: 19.56)
    }

    @Test func sumWithLimits() throws {
        try expectSize(#"\sum_{i=1}^{n}"#, ascent: 29.342, descent: 30.478, width: 28.88)
    }

    @Test func limWithSubscript() throws {
        try expectSize(#"\lim_{x\to\infty}"#, ascent: 13.88, descent: 19.294, width: 36.008)
    }

    @Test func displayIntegralTallerThanTextstyle() throws {
        let display = try renderer.layout(latex: #"\displaystyle\int_0^1"#)
        let text = try MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .text
            )
        ).layout(latex: #"\int_0^1"#)
        #expect(display.ascent + display.descent > text.ascent + text.descent)
        #expect(display.width > text.width)
        try expectSize(#"\displaystyle\int_0^1"#, ascent: 34.384, descent: 24.408, width: 39.92)
    }

    @Test func leftRightFraction() throws {
        try expectSize(#"\left(\frac{a}{b}\right)"#, ascent: 22.92, descent: 13.94, width: 38.904444444444444)
    }
}
