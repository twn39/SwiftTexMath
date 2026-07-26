import XCTest
@testable import SwiftTexMathCore

final class ArchitectureOptimizationTests: XCTestCase {

    // MARK: - Display Visitor Pattern Tests

    private struct NodeCountingVisitor: DisplayNodeVisitor {
        typealias Result = Int
        var count = 0

        mutating func visit(list: DisplayList) -> Int {
            count += 1
            for child in list.children {
                _ = child.accept(&self)
            }
            return count
        }

        mutating func visit(glyphs: GlyphRun) -> Int {
            count += 1
            return count
        }

        mutating func visit(fraction: FractionDisplay) -> Int {
            count += 1
            _ = fraction.numerator.accept(&self)
            _ = fraction.denominator.accept(&self)
            return count
        }

        mutating func visit(radical: RadicalDisplay) -> Int {
            count += 1
            _ = radical.radicand.accept(&self)
            if let degree = radical.degree {
                _ = degree.accept(&self)
            }
            return count
        }

        mutating func visit(line: LineDisplay) -> Int {
            count += 1
            _ = line.inner.accept(&self)
            return count
        }

        mutating func visit(largeOperator: LargeOperatorDisplay) -> Int {
            count += 1
            if let upper = largeOperator.upperLimit { _ = upper.accept(&self) }
            if let lower = largeOperator.lowerLimit { _ = lower.accept(&self) }
            return count
        }

        mutating func visit(colored: ColoredDisplay) -> Int {
            count += 1
            _ = colored.inner.accept(&self)
            return count
        }

        mutating func visit(rule: RuleDisplay) -> Int {
            count += 1
            return count
        }

        mutating func visit(box: BoxDisplay) -> Int {
            count += 1
            if box.drawChild {
                _ = box.child.accept(&self)
            }
            return count
        }

        mutating func visit(stack: StackDisplay) -> Int {
            count += 1
            _ = stack.base.accept(&self)
            if let over = stack.over { _ = over.accept(&self) }
            if let under = stack.under { _ = under.accept(&self) }
            return count
        }
    }

    func testDisplayVisitorTraversesNodes() throws {
        let renderer = MathRenderer()
        let display = try renderer.layout(latex: "\\frac{1}{2} + \\sqrt{x}")

        var visitor = NodeCountingVisitor()
        let visitedCount = display.accept(&visitor)

        XCTAssertGreaterThan(visitedCount, 0, "Visitor should traverse all display list nodes")
    }

    // MARK: - Recursion Safety Tests

    func testParserThrowsOnExceededRecursionDepth() {
        // Generate a deeply nested expression exceeding default maxRecursionDepth (64)
        let deepLatex = String(repeating: "{", count: 70) + "x" + String(repeating: "}", count: 70)

        XCTAssertThrowsError(try MathParser.parse(deepLatex)) { error in
            guard let parseError = error as? ParseError else {
                XCTFail("Expected ParseError but got \(error)")
                return
            }
            XCTAssertEqual(parseError.code, .nestingTooDeep)
        }
    }

    func testTypesetterGuardsMaxRecursionDepth() throws {
        let list = try MathParser.parse("\\frac{1}{2}")
        let cappedEnv = MathEnvironment(maxRecursionDepth: 0)

        let display = MathRenderer(environment: cappedEnv).layout(list)
        // With maxRecursionDepth = 0, inner child layout (numerator/denominator) returns empty DisplayList
        if let fracNode = display.children.first, case .fraction(let frac) = fracNode {
            XCTAssertEqual(frac.numerator.children.count, 0)
            XCTAssertEqual(frac.denominator.children.count, 0)
        } else {
            XCTFail("Expected top-level fraction display node")
        }
    }

    // MARK: - AST Normalization & Sugar Lowering Tests

    func testNormalizerLowersSugarAtoms() throws {
        // Verify that MathNormalizer produces clean canonical AST
        let rawList = try MathParser.parse("a + b")
        let normalized = MathNormalizer.normalize(rawList)

        XCTAssertFalse(normalized.atoms.isEmpty)
        for atom in normalized.atoms {
            XCTAssertNotEqual(atom.kind, .boundary, "Normalizer must strip boundary pseudo-atoms")
        }
    }
}
