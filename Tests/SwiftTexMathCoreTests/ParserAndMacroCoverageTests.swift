import Testing
@testable import SwiftTexMathCore

@Suite("Parser & Macro Edge Cases Coverage")
struct ParserAndMacroCoverageTests {
    @Test("OperatorName edge cases")
    func testOperatorNameAndDeclare() throws {
        let op = try MathParser.parse(#"\operatorname{Foo}"#)
        #expect(!op.atoms.isEmpty)

        let opStar = try MathParser.parse(#"\operatorname*{Bar}"#)
        #expect(!opStar.atoms.isEmpty)
    }

    @Test("Script positioning and limits edge cases")
    func testScriptLimits() throws {
        let limitsOnOp = try MathParser.parse(#"\sum\limits_{i=1}^n x"#)
        #expect(!limitsOnOp.atoms.isEmpty)

        let nolimitsOnOp = try MathParser.parse(#"\sum\nolimits_{i=1}^n x"#)
        #expect(!nolimitsOnOp.atoms.isEmpty)

        #expect(throws: Error.self) {
            _ = try MathParser.parse(#"a\limits_1^2"#)
        }
    }

    @Test("BraKet and macro edge cases")
    func testBraKetAndMacros() throws {
        let bra = try MathParser.parse(#"\bra{\psi}"#)
        #expect(!bra.atoms.isEmpty)

        let ket = try MathParser.parse(#"\ket{\phi}"#)
        #expect(!ket.atoms.isEmpty)

        let braket = try MathParser.parse(#"\braket{\psi}{\phi}"#)
        #expect(!braket.atoms.isEmpty)
    }

    @Test("Mod, pmod, pod, bmod edge cases")
    func testModCommands() throws {
        let bmod = try MathParser.parse(#"a \bmod b"#)
        #expect(!bmod.atoms.isEmpty)

        let pmod = try MathParser.parse(#"a \pmod{b}"#)
        #expect(!pmod.atoms.isEmpty)

        let pod = try MathParser.parse(#"a \pod{b}"#)
        #expect(!pod.atoms.isEmpty)

        let mod = try MathParser.parse(#"a \mod{b}"#)
        #expect(!mod.atoms.isEmpty)
    }

    @Test("Nested macro evaluation and macro removal")
    func testUserMacroManagement() throws {
        var renderer = MathRenderer()
        renderer.defineMacro("foo", replacement: "bar")
        #expect(renderer.userMacros["foo"] != nil)

        let result = try renderer.layout(latex: #"\foo"#)
        #expect(!result.children.isEmpty)

        renderer.removeMacro("foo")
        #expect(renderer.userMacros["foo"] == nil)
    }
}
