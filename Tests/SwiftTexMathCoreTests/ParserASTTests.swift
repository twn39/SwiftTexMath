import Testing
@testable import SwiftTexMathCore

/// Table-driven parse → atom-kind (+ optional script kinds) → serialize → reparse.
/// Pattern adapted from swiftui-math `ParserTests` / iosMath `MTMathListBuilderTest`,
/// with expectations matching SwiftTexMath's AtomKind / LatexSerializer behavior.
@Suite("Parser AST")
struct ParserASTTests {
    struct Record: Sendable {
        let latex: String
        let kinds: [AtomKind]
        /// Kinds of the first atom's superscript list (empty = none / empty list).
        let superscriptKinds: [AtomKind]
        /// Kinds of the first atom's subscript list.
        let subscriptKinds: [AtomKind]
        /// Nested script on first superscript atom (e.g. `x^{2^{3}}`).
        let nestedSuperscriptKinds: [AtomKind]

        init(
            _ latex: String,
            _ kinds: [AtomKind],
            superscript: [AtomKind] = [],
            `subscript`: [AtomKind] = [],
            nestedSuperscript: [AtomKind] = []
        ) {
            self.latex = latex
            self.kinds = kinds
            self.superscriptKinds = superscript
            self.subscriptKinds = `subscript`
            self.nestedSuperscriptKinds = nestedSuperscript
        }
    }

    @Test(arguments: [
        Record("x", [.variable]),
        Record("1", [.number]),
        Record("*", [.binaryOperator]),
        Record("+", [.binaryOperator]),
        Record(".", [.punctuation]),
        Record("(", [.open]),
        Record(")", [.close]),
        Record(",", [.punctuation]),
        Record("!", [.punctuation]),
        Record("=", [.relation]),
        Record("x+2", [.variable, .binaryOperator, .number]),
        Record("(2.3 * 8)", [.open, .number, .punctuation, .number, .binaryOperator, .number, .close]),
        Record("5{3+4}", [.number, .inner]),
        Record(#"\pi+\theta\geq 3"#, [.variable, .binaryOperator, .variable, .relation, .number]),
        Record(#"\pi\ne 5 \land 3"#, [.variable, .relation, .number, .binaryOperator, .number]),
        Record("x\\quad y", [.variable, .space, .variable]),
        Record("x\\;y", [.variable, .space, .variable]),
        Record("x\\!y", [.variable, .space, .variable]),
        Record(#"\frac{1}{2}"#, [.fraction]),
        Record(#"\sqrt{x}"#, [.radical]),
        Record(#"\sqrt[3]{x}"#, [.radical]),
        Record(#"\left(a\right)"#, [.inner]),
        Record(#"\sum_{i}"#, [.largeOperator], subscript: [.variable]),
        Record(#"\int_0^1"#, [.largeOperator], superscript: [.number], subscript: [.number])
    ])
    func plainAndCommands(record: Record) throws {
        try assertRecord(record)
    }

    @Test(arguments: [
        Record("x^2", [.variable], superscript: [.number]),
        Record("x^23", [.variable, .number], superscript: [.number]),
        Record("x^{23}", [.variable], superscript: [.number, .number]),
        Record("x^{2^3}", [.variable], superscript: [.number], nestedSuperscript: [.number]),
        Record("{}^2", [.inner], superscript: [.number]),
        Record("5{x}^2", [.number, .variable], superscript: [])
    ])
    func superscripts(record: Record) throws {
        try assertRecord(record)
        if record.latex == "5{x}^2" {
            let list = try MathParser.parse(record.latex)
            #expect(list.atoms[1].superscript?.atoms.map(\.kind) == [.number])
        }
    }

    @Test(arguments: [
        Record("x_2", [.variable], subscript: [.number]),
        Record("x_23", [.variable, .number], subscript: [.number]),
        Record("x_{23}", [.variable], subscript: [.number, .number]),
        Record("x_{2_3}", [.variable], subscript: [.number]),
        Record("x^2_i", [.variable], superscript: [.number], subscript: [.variable]),
        Record("x_i^2", [.variable], superscript: [.number], subscript: [.variable])
    ])
    func subscripts(record: Record) throws {
        try assertRecord(record)
    }

    @Test func doubleScriptWithoutEmptyBaseFails() {
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse("x^2^3")
        }
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse("x_2_3")
        }
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse("^2")
        }
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse("_2")
        }
    }

    @Test func serializeRoundTripPreservesKinds() throws {
        let samples = [
            "x+2", #"\frac{a}{b}"#, #"\sqrt{x^2}"#, #"\left(\frac{1}{2}\right)"#,
            #"E=mc^2"#, #"\sum_{i=1}^{n}"#, #"\mathrm{d}x"#
        ]
        for latex in samples {
            let list = try MathParser.parse(latex)
            let again = try MathParser.parse(LatexSerializer.string(from: list))
            #expect(again.atoms.map(\.kind) == list.atoms.map(\.kind), "round-trip kinds for \(latex)")
        }
    }

    @Test func radicalDegreePayload() throws {
        let list = try MathParser.parse(#"\sqrt[3]{x}"#)
        guard case .radical(let rad) = list.atoms.first?.payload else {
            Issue.record("expected radical")
            return
        }
        #expect(rad.degree?.atoms.map(\.kind) == [.number])
        #expect(rad.radicand.atoms.map(\.kind) == [.variable])
    }

    private func assertRecord(_ record: Record) throws {
        let list = try MathParser.parse(record.latex)
        #expect(list.atoms.map(\.kind) == record.kinds, "kinds for \(record.latex)")

        if let first = list.atoms.first {
            if record.superscriptKinds.isEmpty {
                #expect(first.superscript == nil || first.superscript?.isEmpty == true, "no superscript for \(record.latex)")
            } else {
                #expect(first.superscript?.atoms.map(\.kind) == record.superscriptKinds, "superscript for \(record.latex)")
                if !record.nestedSuperscriptKinds.isEmpty {
                    #expect(
                        first.superscript?.atoms.first?.superscript?.atoms.map(\.kind)
                            == record.nestedSuperscriptKinds,
                        "nested superscript for \(record.latex)"
                    )
                }
            }
            if record.subscriptKinds.isEmpty {
                #expect(first.subscript == nil || first.subscript?.isEmpty == true, "no subscript for \(record.latex)")
            } else {
                #expect(first.subscript?.atoms.map(\.kind) == record.subscriptKinds, "subscript for \(record.latex)")
            }
        }

        let serialized = LatexSerializer.string(from: list)
        let again = try MathParser.parse(serialized)
        #expect(again.atoms.map(\.kind) == list.atoms.map(\.kind), "reparse kinds for \(record.latex) → \(serialized)")
    }
}
