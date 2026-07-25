import Foundation
import Testing
@testable import SwiftTexMathCore
@testable import SwiftTexMath

@Suite("Architecture & Core Abstractions Optimization")
struct ArchitectureOptimizationTests {

    @Test func atomFactoryTablesIntegrity() {
        // Verify default aliases map to non-empty targets
        #expect(!AtomFactory.aliases.isEmpty)
        for (alias, target) in AtomFactory.aliases {
            #expect(!alias.isEmpty)
            #expect(!target.isEmpty)
        }

        // Verify delimiters table
        #expect(!AtomFactory.delimiters.isEmpty)
        #expect(AtomFactory.delimiters["("] == "(")
        #expect(AtomFactory.delimiters["\\"] == "\\")

        // Verify accents table
        #expect(!AtomFactory.accents.isEmpty)
        #expect(AtomFactory.accents["hat"] == "\u{0302}")

        // Verify symbols built-in table
        #expect(!AtomFactory.symbols.isEmpty)
        #expect(AtomFactory.symbols["alpha"]?.nucleus == "\u{03B1}")
        #expect(AtomFactory.symbols["sum"]?.kind == .largeOperator)
        #expect(AtomFactory.symbols["infty"]?.nucleus == "\u{221E}")
    }

    @Test func customSymbolRegistrationAndReset() {
        AtomFactory.resetCustomSymbols()
        
        let customAtom = MathAtom.ordinary("\u{2605}") // Star symbol
        AtomFactory.addLatexSymbol("mycustomstar", atom: customAtom)

        #expect(AtomFactory.atom(forCommand: "mycustomstar")?.nucleus == "\u{2605}")

        AtomFactory.addAlias("staralias", target: "mycustomstar")
        #expect(AtomFactory.atom(forCommand: "staralias")?.nucleus == "\u{2605}")

        AtomFactory.resetCustomSymbols()
        #expect(AtomFactory.atom(forCommand: "mycustomstar") == nil)
    }

    @Test func displayProviderCachingForStructFontProviders() throws {
        let latex = #"E=mc^2"#
        let font = MathFont(name: .latinModern, size: 18)

        struct MockStructProvider: FontProviding, Hashable {
            let id = UUID()
            func metrics(for font: MathFont) -> FontMetrics? {
                FontRegistry.shared.metrics(for: font)
            }
        }

        let provider1 = MockStructProvider()
        let provider2 = MockStructProvider()

        let res1 = DisplayProvider.display(for: latex, font: font, style: .display, proposedWidth: 0, fonts: provider1)
        let res2 = DisplayProvider.display(for: latex, font: font, style: .display, proposedWidth: 0, fonts: provider1)
        let res3 = DisplayProvider.display(for: latex, font: font, style: .display, proposedWidth: 0, fonts: provider2)

        guard case .success(let d1) = res1, case .success(let d2) = res2, case .success(let d3) = res3 else {
            Issue.record("Expected successful DisplayList calculation")
            return
        }

        #expect(d1.width == d2.width)
        #expect(d1.width == d3.width)
    }

    @Test func latexSerializerRoundTripFidelity() throws {
        let testLatexStrings = [
            #"a+b=c"#,
            #"\frac{1}{2}"#,
            #"\sqrt{x}"#,
            #"\hat{x}"#,
            #"\overline{abc}"#,
            #"\sum_{i=1}^{n} x_i"#,
            #"\binom{n}{k}"#
        ]

        for latex in testLatexStrings {
            let parsed = try MathParser.parse(latex)
            let serialized = parsed.latexString
            let reParsed = try MathParser.parse(serialized)
            #expect(!serialized.isEmpty)
            #expect(parsed.atoms.count == reParsed.atoms.count)
        }
    }
}
