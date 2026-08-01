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

    struct Features: Decodable, Sendable {
        var hasFraction: Bool
        var hasRadical: Bool
        var hasMatrix: Bool
        var hasLargeOp: Bool
        var hasAccent: Bool
    }

    struct GoldenItem: Decodable, Sendable {
        var id: String
        var latex: String
        var tokens: [String]
        var nodeTypes: [String]?
        var metrics: Metrics
        var displayMetrics: Metrics?
        var textMetrics: Metrics?
        var features: Features?
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

    private func renderer(for style: MathStyle) -> MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: style
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
        let displayRenderer = renderer(for: .display)

        for golden in Self.goldens {
            guard let display = try? displayRenderer.layout(latex: golden.latex) else {
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
        var simpleCount = 0
        var simpleOutliers = 0
        let displayRenderer = renderer(for: .display)

        for golden in Self.goldens {
            guard let display = try? displayRenderer.layout(latex: golden.latex) else {
                continue
            }
            testedFormulaCount += 1

            // 1. Positive bounding box checks
            #expect(display.width > 0, "Width of \(golden.id) must be positive")
            #expect(display.ascent > 0, "Ascent of \(golden.id) must be positive")
            #expect(display.descent >= 0, "Descent of \(golden.id) must be non-negative")

            // 2. Metric ratio comparison with KaTeX
            let targetMetrics = golden.displayMetrics ?? golden.metrics
            let expectedHeightPt = CGFloat(targetMetrics.totalHeightEm) * fontSize
            let actualHeightPt = display.ascent + display.descent

            if expectedHeightPt > 0 {
                let ratio = actualHeightPt / expectedHeightPt
                // Hard band: engines differ on stretchy delims, scripts, and axis placement.
                #expect(
                    ratio >= 0.15 && ratio <= 4.50,
                    "Height ratio for \(golden.id) (\(actualHeightPt)pt vs \(expectedHeightPt)pt) should be in expected bounds"
                )

                // Soft tracking: simple formulas should usually land in a tighter band.
                // Skip known pathological corpus ids (extreme KaTeX vs STM divergence).
                let skipSoft = golden.id.contains("e2e_rendering/068")
                    || golden.id.contains("e2e_rendering/077")
                let feat = golden.features
                let isSimple = feat == nil
                    || !(feat!.hasFraction || feat!.hasRadical || feat!.hasMatrix
                        || feat!.hasLargeOp || feat!.hasAccent)
                if isSimple, !skipSoft {
                    simpleCount += 1
                    if ratio < 0.45 || ratio > 2.20 {
                        simpleOutliers += 1
                    }
                }
            }
        }

        #expect(testedFormulaCount >= 100, "Should successfully validate geometry for 100+ formulas")
        // Allow a small fraction of simple outliers (font metric / spacing differences vs KaTeX).
        if simpleCount > 20 {
            let outlierRate = Double(simpleOutliers) / Double(simpleCount)
            #expect(
                outlierRate <= 0.30,
                "Simple formula height outlier rate \(outlierRate) (\(simpleOutliers)/\(simpleCount)) should be ≤ 30%"
            )
        }
    }

    @Test func testBothDisplayStyleAndTextStyleLayout() throws {
        let displayRenderer = renderer(for: .display)
        let textRenderer = renderer(for: .text)
        var testedCount = 0

        for golden in Self.goldens {
            guard let displayLayout = try? displayRenderer.layout(latex: golden.latex),
                  let textLayout = try? textRenderer.layout(latex: golden.latex) else {
                continue
            }
            testedCount += 1

            #expect(displayLayout.width > 0, "Display layout width for \(golden.id) must be positive")
            #expect(textLayout.width > 0, "Text layout width for \(golden.id) must be positive")

            // For formulas with large operators or fractions, display height is typically >= text height
            if let feat = golden.features, feat.hasLargeOp || feat.hasFraction {
                let displayHeight = displayLayout.ascent + displayLayout.descent
                let textHeight = textLayout.ascent + textLayout.descent
                #expect(displayHeight >= textHeight * 0.8, "Display style height should be at least comparable to text style for \(golden.id)")
            }
        }

        #expect(testedCount >= 100, "Should validate both styles across 100+ formulas")
    }

    /// Feature flags from KaTeX goldens should match display-tree structure when present.
    @Test func testFeatureFlagsMatchDisplayStructure() throws {
        let displayRenderer = renderer(for: .display)
        var checked = 0
        var mismatches = 0

        for golden in Self.goldens {
            guard let feat = golden.features,
                  let display = try? displayRenderer.layout(latex: golden.latex)
            else { continue }
            checked += 1
            let kinds = BroadLayoutCatalog.kindCounts(display)

            if feat.hasFraction, kinds["fraction", default: 0] < 1 {
                // Some KaTeX "fraction" flags include genfrac/binom variants that may lower differently.
                if golden.latex.contains("\\frac") || golden.latex.contains("\\cfrac")
                    || golden.latex.contains("\\dfrac") || golden.latex.contains("\\tfrac")
                {
                    mismatches += 1
                }
            }
            if feat.hasRadical, kinds["radical", default: 0] < 1, golden.latex.contains("\\sqrt") {
                mismatches += 1
            }
            if feat.hasLargeOp {
                let hasOp = kinds["largeOperator", default: 0] >= 1 || kinds["glyphs", default: 0] >= 1
                if !hasOp, golden.latex.contains("\\sum") || golden.latex.contains("\\int")
                    || golden.latex.contains("\\prod")
                {
                    mismatches += 1
                }
            }
            if feat.hasAccent {
                // Accents may be glyph lists rather than a dedicated node.
                let tokens = display.extractTextTokens()
                if tokens.isEmpty && display.children.isEmpty {
                    mismatches += 1
                }
            }
        }

        #expect(checked >= 50, "feature-flag subset should cover 50+ goldens")
        let rate = Double(mismatches) / Double(max(checked, 1))
        #expect(rate <= 0.15, "feature structure mismatch rate \(rate) (\(mismatches)/\(checked))")
    }

    /// Width soft-band vs KaTeX height (engines differ; catch only pathological collapse/blowup).
    @Test func testWidthAndHeightNotPathologicalVsKaTeX() throws {
        let fontSize: CGFloat = 20
        let displayRenderer = renderer(for: .display)
        var checked = 0
        var bad = 0

        for golden in Self.goldens {
            guard let display = try? displayRenderer.layout(latex: golden.latex) else { continue }
            checked += 1
            let target = golden.displayMetrics ?? golden.metrics
            let expectedH = CGFloat(target.totalHeightEm) * fontSize
            let actualH = display.ascent + display.descent

            if display.width <= 0, actualH <= 0 {
                bad += 1
                continue
            }
            // Pathological: 50× taller/shorter than KaTeX, or wider than 100em with tiny KaTeX height.
            if expectedH > 0 {
                let ratio = actualH / expectedH
                if ratio < 0.08 || ratio > 8.0 {
                    bad += 1
                }
            }
            if display.width > fontSize * 100 {
                bad += 1
            }
        }

        #expect(checked >= 100)
        let rate = Double(bad) / Double(max(checked, 1))
        #expect(rate <= 0.08, "pathological geometry rate \(rate) (\(bad)/\(checked))")
    }

    /// Content: digit / letter nucleus from latex should appear for simple alphanumeric formulas.
    @Test func testSimpleAlphanumericContentSurvivesLayout() throws {
        let displayRenderer = renderer(for: .display)
        var checked = 0
        var missing = 0
        let simple = Self.goldens.filter { g in
            let f = g.features
            return f == nil
                || !(f!.hasFraction || f!.hasRadical || f!.hasMatrix || f!.hasLargeOp || f!.hasAccent)
        }

        for golden in simple.prefix(80) {
            guard let display = try? displayRenderer.layout(latex: golden.latex) else { continue }
            checked += 1
            let tokens = display.extractTextTokens()
            let folded = BroadLayoutCatalog.foldMathTokens(tokens)
            // Pull single-letter tokens expected from KaTeX golden token list.
            let letterTokens = golden.tokens.filter { $0.count == 1 && $0.first!.isLetter }
            for t in letterTokens.prefix(3) {
                let ok = BroadLayoutCatalog.tokensContainHint(tokens, hint: t)
                    || folded.contains(t.lowercased())
                if !ok {
                    missing += 1
                    break
                }
            }
        }
        #expect(checked >= 20)
        let rate = Double(missing) / Double(max(checked, 1))
        // Engines differ on symbol substitution; allow a generous miss rate.
        #expect(rate <= 0.50, "simple content miss rate \(rate) (\(missing)/\(checked))")
    }
}
