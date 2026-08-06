import Testing
import Foundation
@testable import SwiftTexMathCore

@Suite("Stress & Recursion Budget Tests")
struct StressAndRecursionTests {
    @Test("Parser nesting limit triggers nestingTooDeep error")
    func testParserDeepNestingLimit() {
        // Build 70 levels of nested braces: {{{...}}}
        let deepBraces = String(repeating: "{", count: 70) + "a" + String(repeating: "}", count: 70)
        do {
            _ = try MathParser.parse(deepBraces)
            #expect(Bool(false), "Expected nestingTooDeep error")
        } catch let err as ParseError {
            #expect(err.code == .nestingTooDeep)
        } catch {
            #expect(Bool(false), "Expected ParseError")
        }
    }

    @Test("Deeply nested fractions recursion safety")
    func testDeepFractionsRecursionSafety() throws {
        // Build 10 levels of nested fractions: \frac{1}{\frac{1}{\frac{1}{...}}}
        var latex = "1"
        for _ in 0..<10 {
            latex = "\\frac{1}{\(latex)}"
        }
        let list = try MathParser.parse(latex)
        let renderer = MathRenderer()
        let display = renderer.layout(list)

        #expect(display.width > 0)
        #expect(display.ascent > 0)
    }

    @Test("Deeply nested radicals recursion safety")
    func testDeepRadicalsRecursionSafety() throws {
        // Build 10 levels of nested sqrt: \sqrt{\sqrt{...}}
        var latex = "x"
        for _ in 0..<10 {
            latex = "\\sqrt{\(latex)}"
        }
        let list = try MathParser.parse(latex)
        let renderer = MathRenderer()
        let display = renderer.layout(list)

        #expect(display.width > 0)
        #expect(display.ascent > 0)
    }
}
