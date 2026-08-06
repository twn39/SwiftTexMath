import Testing
@testable import SwiftTexMathCore

@Suite("Parser Error & Boundary Recovery Tests")
struct ParserErrorAndBoundaryTests {
    @Test("Double subscript/superscript error handling")
    func testDoubleScriptErrors() {
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"x^1^2"#)
        }

        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"x_1_2"#)
        }
    }

    @Test("Invalid limits placement error")
    func testInvalidLimits() {
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"a\limits_1^2"#)
        }
    }

    @Test("Mismatched braces and missing argument errors")
    func testMismatchedBracesAndMissingArgs() {
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"\frac{1}"#)
        }

        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"\sqrt{"#)
        }
    }

    @Test("Missing left and right delimiter errors")
    func testMissingDelimiters() {
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"\left( x"#)
        }

        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"x \right)"#)
        }
    }

    @Test("Environment mismatched begin and end errors")
    func testEnvironmentErrors() {
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"\begin{pmatrix} a \end{bmatrix}"#)
        }

        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"\begin{nonexistentEnv} a \end{nonexistentEnv}"#)
        }

        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"\end{pmatrix}"#)
        }
    }

    @Test("Unknown command error description")
    func testUnknownCommandError() {
        do {
            _ = try MathParser.parse(#"\unknownCommandX"#)
            #expect(Bool(false), "Expected ParseError")
        } catch let err as ParseError {
            #expect(err.code == .invalidCommand)
            #expect(!err.description.isEmpty)
        } catch {
            #expect(Bool(false), "Expected ParseError")
        }
    }
}
