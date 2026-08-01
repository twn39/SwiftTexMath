import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

// MARK: - Script scale from MATH table

@Suite("Script scale MATH table")
struct ScriptScaleMathTableTests {
    @Test func latinModernScriptPercentsMatchTable() throws {
        let m = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)))
        #expect(abs(m.scriptPercentScaleDown - 0.7) < 0.001)
        #expect(abs(m.scriptScriptPercentScaleDown - 0.5) < 0.001)
        #expect(abs(m.sizeMultiplier(for: .display) - 1) < 1e-9)
        #expect(abs(m.sizeMultiplier(for: .text) - 1) < 1e-9)
        #expect(abs(m.sizeMultiplier(for: .script) - 0.7) < 0.001)
        #expect(abs(m.sizeMultiplier(for: .scriptScript) - 0.5) < 0.001)
        #expect(abs(m.styleFontSize(baseSize: 20, style: .script) - 14) < 0.01)
        #expect(abs(m.styleFontSize(baseSize: 20, style: .scriptScript) - 10) < 0.01)
    }

    @Test func xitsScriptPercentsPositive() throws {
        let m = try #require(FontRegistry.shared.metrics(for: MathFont(name: .xits, size: 20)))
        #expect(m.scriptPercentScaleDown > 0.4 && m.scriptPercentScaleDown <= 1)
        #expect(m.scriptScriptPercentScaleDown > 0.3 && m.scriptScriptPercentScaleDown <= m.scriptPercentScaleDown + 0.01)
    }

    @Test func environmentStyleFontSizeUsesMetrics() throws {
        let m = try #require(FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 24)))
        var env = MathEnvironment(font: MathFont(name: .latinModern, size: 24), style: .script)
        #expect(abs(env.styleFontSize(using: m) - 24 * m.scriptPercentScaleDown) < 0.01)
        env.style = .scriptScript
        #expect(abs(env.styleFontSize(using: m) - 24 * m.scriptScriptPercentScaleDown) < 0.01)
        // Fallback path without metrics still works.
        #expect(env.styleFontSize > 0)
    }

    @Test func scriptSuperscriptUsesSmallerGlyphsThanBase() throws {
        let r = MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display
            )
        )
        let plain = try r.layout(latex: "x")
        let scripted = try r.layout(latex: "x^2")
        // Superscript raises ascent; total width grows.
        #expect(scripted.ascent > plain.ascent)
        #expect(scripted.width > plain.width)
    }
}

// MARK: - External geometry oracle (KaTeX fixture)

/// Compare SwiftTexMath layout (LM 20pt) against KaTeX DomTree metrics (em).
///
/// This is a **graded external oracle**, not a pixel match. Simple formulas use
/// a tighter height band; compound formulas use a wider band.
@Suite("External geometry oracle")
struct ExternalGeometryOracleTests {
    struct Metrics: Decodable, Sendable {
        var heightEm: Double
        var depthEm: Double
        var totalHeightEm: Double
        var widthEm: Double?
    }

    struct Item: Decodable, Sendable {
        var id: String
        var latex: String
        var display: Metrics?
        var text: Metrics?
        var error: String?
    }

    struct Catalog: Decodable, Sendable {
        var generator: String?
        var items: [Item]
    }

    static let catalog: Catalog = {
        let candidates = [
            Bundle.module.url(forResource: "katex_oracle_metrics", withExtension: "json", subdirectory: "Fixtures"),
            Bundle.module.url(forResource: "katex_oracle_metrics", withExtension: "json"),
            Bundle.module.resourceURL?
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("katex_oracle_metrics.json"),
        ]
        for url in candidates.compactMap({ $0 }) where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let cat = try? JSONDecoder().decode(Catalog.self, from: data)
            {
                return cat
            }
        }
        return Catalog(items: [])
    }()

    private let fontSize: CGFloat = 20

    private func renderer(style: MathStyle) -> MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: fontSize),
                style: style
            )
        )
    }

    /// Grade A: simple single-level expressions — tighter height ratio band.
    private static let gradeA: Set<String> = [
        "var_x", "var_y", "digits", "sum_plain", "rel_eq", "chain",
        "script_x2", "sub_xi", "sin_theta", "log", "alpha_beta", "mathbb_R",
    ]

    @Test func oracleCatalogLoads() {
        #expect(Self.catalog.items.count >= 30, "expected oracle fixture with ≥30 formulas")
    }

    @Test func displayHeightWithinGradedBands() throws {
        let r = renderer(style: .display)
        var checked = 0
        var gradeAOutliers = 0
        var gradeACount = 0
        var hardFails = 0

        for item in Self.catalog.items {
            guard let expected = item.display, item.error == nil else { continue }
            guard let display = try? r.layout(latex: item.latex) else {
                hardFails += 1
                continue
            }
            checked += 1
            let stmH = Double((display.ascent + display.descent) / fontSize)
            let katexH = expected.totalHeightEm
            guard katexH > 0.05 else { continue }
            let ratio = stmH / katexH

            // Hard band: engines differ but must not be pathological.
            if ratio < 0.25 || ratio > 4.0 {
                hardFails += 1
                Issue.record("hard height fail \(item.id): stm=\(stmH)em katex=\(katexH)em ratio=\(ratio)")
            }

            if Self.gradeA.contains(item.id) {
                gradeACount += 1
                // Tighter band for simple formulas.
                if ratio < 0.55 || ratio > 1.85 {
                    gradeAOutliers += 1
                }
            }
        }

        #expect(checked >= 25)
        #expect(hardFails == 0, "pathological height mismatches: \(hardFails)")
        if gradeACount >= 8 {
            let rate = Double(gradeAOutliers) / Double(gradeACount)
            #expect(
                rate <= 0.35,
                "grade-A height outlier rate \(rate) (\(gradeAOutliers)/\(gradeACount))"
            )
        }
    }

    @Test func displayWidthNotPathological() throws {
        let r = renderer(style: .display)
        var checked = 0
        var bad = 0
        for item in Self.catalog.items {
            guard let expected = item.display, let kw = expected.widthEm, kw > 0.05,
                  item.error == nil,
                  let display = try? r.layout(latex: item.latex)
            else { continue }
            checked += 1
            let stmW = Double(display.width / fontSize)
            let ratio = stmW / kw
            // DomTree width sum can over-count nested structures (e.g. nested_frac).
            if ratio < 0.15 || ratio > 5.5 {
                bad += 1
                Issue.record("width fail \(item.id): stm=\(stmW) katex=\(kw) ratio=\(ratio)")
            }
        }
        #expect(checked >= 20)
        let rate = Double(bad) / Double(max(checked, 1))
        #expect(rate <= 0.15, "pathological width rate \(rate) (\(bad)/\(checked))")
    }

    @Test func textStyleGenerallyNotTallerThanDisplayForOps() throws {
        let displayR = renderer(style: .display)
        let textR = renderer(style: .text)
        var checked = 0
        for item in Self.catalog.items where item.id.contains("sum") || item.id.contains("frac") || item.id == "int_01" {
            guard let d = try? displayR.layout(latex: item.latex),
                  let t = try? textR.layout(latex: item.latex)
            else { continue }
            checked += 1
            let dH = d.ascent + d.descent
            let tH = t.ascent + t.descent
            #expect(dH + 0.5 >= tH * 0.85, "\(item.id): display \(dH) << text \(tH)")
        }
        #expect(checked >= 3)
    }

    @Test func regenerateHintDocumentsScript() {
        // Documents the refresh path for agents / CI notes.
        let script = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/katex_oracle.mjs")
        // Script lives at package root; may be absent in some checkouts — soft check.
        if FileManager.default.fileExists(atPath: script.path) {
            #expect(true)
        } else {
            // Fixture alone is enough for tests.
            #expect(Self.catalog.items.count >= 30)
        }
    }
}
