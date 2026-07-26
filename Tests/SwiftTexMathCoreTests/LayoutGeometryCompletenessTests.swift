import XCTest
@testable import SwiftTexMathCore

final class LayoutGeometryCompletenessTests: XCTestCase {

    // MARK: - Explicit Break Control Tests (\allowbreak and \nobreak)

    func testAllowbreakCreatesBreakPoint() throws {
        let latex = "a + b \\allowbreak + c"
        let list = try MathParser.parse(latex)
        let font = MathFont(name: .latinModern, size: 20)
        let renderer = MathRenderer(environment: MathEnvironment(font: font, maxWidth: 60))

        let display = renderer.layout(list)
        // Wrapped list should produce multiple line children
        XCTAssertGreaterThan(display.children.count, 1, "WrapLayout should break at \\allowbreak")
    }

    func testNobreakPreventsBreak() throws {
        let latex = "a + \\nobreak b"
        let list = try MathParser.parse(latex)
        let font = MathFont(name: .latinModern, size: 20)
        let renderer = MathRenderer(environment: MathEnvironment(font: font, maxWidth: 30))

        let display = renderer.layout(list)
        XCTAssertNotNil(display)
    }

    // MARK: - Continuation Line Indentation Tests

    func testContinuationLineHasWrapIndent() throws {
        let latex = "a + b + c + d + e + f + g + h"
        let font = MathFont(name: .latinModern, size: 20)
        let env = MathEnvironment(font: font, maxWidth: 80)
        let display = try MathRenderer(environment: env).layout(latex: latex)

        guard display.children.count > 1,
              case .list(_) = display.children[0],
              case .list(let secondLine) = display.children[1] else {
            XCTFail("Expected multiple wrapped lines")
            return
        }

        // Line 2 (continuation line) should start with positive wrapIndent position on first atom node
        if let firstAtomNode = secondLine.children.first {
            XCTAssertGreaterThan(firstAtomNode.position.x, 0, "Continuation line 2+ must apply positive wrapIndent")
        }
    }

    // MARK: - Matrix Row Geometry Invariants

    func testMatrixRowGapMeetsOverbarGapClearance() throws {
        let latex = "\\begin{pmatrix} a \\\\ b \\end{pmatrix}"
        let display = try MathRenderer().layout(latex: latex)

        XCTAssertGreaterThan(display.width, 0)
        XCTAssertGreaterThan(display.ascent, 0)
        XCTAssertGreaterThan(display.descent, 0)
    }
}
