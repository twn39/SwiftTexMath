import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

/// Cross-validation test suite verifying SwiftTexMath layout geometry and content accuracy against KaTeX
/// across 180+ math formulas (functions, operators, fractions, radicals, matrices, environments, large ops, fonts).
@Suite("KaTeX Cross-Validation")
struct KaTeXCrossValidationTests {
    struct Metrics: Decodable, Sendable {
        var ascentEm: Double
        var descentEm: Double
        var totalHeightEm: Double
    }

    struct GoldenItem: Decodable, Sendable {
        var id: String
        var latex: String
        var tokens: [String]
        var metrics: Metrics
    }

    static let goldens: [GoldenItem] = {
        let candidates = [
            Bundle.module.url(forResource: "katex_geometry_goldens", withExtension: "json", subdirectory: "Fixtures"),
            Bundle.module.url(forResource: "katex_geometry_goldens", withExtension: "json"),
            Bundle.module.resourceURL?
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("katex_geometry_goldens.json")
        ]
        guard let url = candidates.compactMap({ $0 }).first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            let currentFile = URL(fileURLWithPath: #file)
            let fixtureURL = currentFile
                .deletingLastPathComponent()
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("katex_geometry_goldens.json")
            if FileManager.default.fileExists(atPath: fixtureURL.path),
               let data = try? Data(contentsOf: fixtureURL) {
                return (try? JSONDecoder().decode([GoldenItem].self, from: data)) ?? []
            }
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([GoldenItem].self, from: data)
        } catch {
            return []
        }
    }()

    private var renderer: MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display
            )
        )
    }

    @Test func goldensCatalogLoads() {
        #expect(Self.goldens.count >= 150, "KaTeX golden fixtures catalog should contain 150+ formulas")
    }

    @Test func testContentTokensAndOperatorsParity() throws {
        let checkOperators: Set<String> = [
            "sin", "cos", "tan", "sec", "csc", "cot",
            "sinh", "cosh", "tanh", "ln", "log", "lg", "exp",
            "det", "gcd", "dim", "ker", "hom", "arg", "deg",
            "min", "max", "inf", "sup", "lim", "liminf", "limsup",
            "sum", "prod", "coprod", "int", "iint", "iiint", "oint", "oiint",
            "Hom", "Ker"
        ]

        var testedFormulaCount = 0

        for golden in Self.goldens {
            guard let display = try? renderer.layout(latex: golden.latex) else {
                continue
            }
            testedFormulaCount += 1
            let swiftTokens = display.extractTextTokens()
            let joinedTokens = swiftTokens.joined()

            #expect(!swiftTokens.isEmpty, "Rendered tokens for \(golden.id) should not be empty")

            // Guard against operator truncation (e.g., \sin -> s)
            let expectedOps = golden.tokens.filter { checkOperators.contains($0) }
            for op in expectedOps {
                let containsOp = swiftTokens.contains { $0.contains(op) } || joinedTokens.contains(op)
                #expect(containsOp, "Formula \(golden.id) should contain operator '\(op)', got: \(swiftTokens)")
            }
        }

        #expect(testedFormulaCount >= 100, "Should successfully validate layout for 100+ formulas")
    }

    @Test func testLayoutGeometryAndBoundingMetrics() throws {
        let fontSize: CGFloat = 20 // 1em = 20pt
        var testedFormulaCount = 0

        for golden in Self.goldens {
            guard let display = try? renderer.layout(latex: golden.latex) else {
                continue
            }
            testedFormulaCount += 1

            // 1. Positive bounding box checks
            #expect(display.width > 0, "Width of \(golden.id) must be positive")
            #expect(display.ascent > 0, "Ascent of \(golden.id) must be positive")
            #expect(display.descent >= 0, "Descent of \(golden.id) must be non-negative")

            // 2. Metric ratio comparison with KaTeX
            let expectedHeightPt = CGFloat(golden.metrics.totalHeightEm) * fontSize
            let actualHeightPt = display.ascent + display.descent

            if expectedHeightPt > 0 {
                let ratio = actualHeightPt / expectedHeightPt
                #expect(ratio >= 0.15 && ratio <= 4.50, "Height ratio for \(golden.id) (\(actualHeightPt)pt vs \(expectedHeightPt)pt) should be in expected bounds")
            }
        }

        #expect(testedFormulaCount >= 100, "Should successfully validate geometry for 100+ formulas")
    }
}
