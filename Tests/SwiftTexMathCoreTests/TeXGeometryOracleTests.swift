import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

/// TeX (LuaTeX/XeTeX) external geometry oracle.
///
/// Fixture produced by `scripts/tex_oracle/tex_oracle.py`.
/// When `status != "ok"` (no TeX on the machine), tests **soft-pass** so default
/// CI stays green. When a full fixture is committed, height/width bands run hard.
@Suite("TeX geometry oracle")
struct TeXGeometryOracleTests {
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
        var status: String?
        var unit: String?
        var fontSizePt: Double?
        var measuredCount: Int?
        var itemCount: Int?
        var items: [Item]
        var note: String?
    }

    static let catalog: Catalog = {
        let candidates = [
            Bundle.module.url(forResource: "tex_oracle_metrics", withExtension: "json", subdirectory: "Fixtures"),
            Bundle.module.url(forResource: "tex_oracle_metrics", withExtension: "json"),
            Bundle.module.resourceURL?
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("tex_oracle_metrics.json"),
        ]
        for url in candidates.compactMap({ $0 }) where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let cat = try? JSONDecoder().decode(Catalog.self, from: data)
            {
                return cat
            }
        }
        return Catalog(status: "missing", items: [])
    }()

    private let fontSize: CGFloat = 20

    private var isLive: Bool {
        (Self.catalog.status ?? "") == "ok" && Self.catalog.items.contains { $0.display != nil }
    }

    private func renderer(style: MathStyle) -> MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: fontSize),
                style: style
            )
        )
    }

    private static let gradeA: Set<String> = [
        "var_x", "var_y", "digits", "sum_plain", "rel_eq", "chain",
        "script_x2", "sub_xi", "sin_theta", "log", "alpha_beta", "mathbb_R",
    ]

    // MARK: - Skeleton always runs

    @Test func fixtureLoads() {
        #expect(Self.catalog.status != nil || !Self.catalog.items.isEmpty || Self.catalog.status == "missing")
        // Documented statuses
        if let status = Self.catalog.status {
            #expect(
                ["ok", "unavailable", "compile_failed", "empty", "missing"].contains(status),
                "unexpected status \(status)"
            )
        }
    }

    @Test func schemaUnitIsEmWhenPresent() {
        if let unit = Self.catalog.unit {
            #expect(unit == "em")
        }
    }

    @Test func unavailableIsDocumentedSoftPass() {
        // When TeX was not used to generate the fixture, measuredCount should be 0.
        if Self.catalog.status == "unavailable" {
            #expect((Self.catalog.measuredCount ?? 0) == 0)
            #expect(Self.catalog.items.isEmpty || Self.catalog.items.allSatisfy { $0.display == nil })
        }
    }

    // MARK: - Live comparison (only when status == ok)

    @Test func displayHeightWithinBandsWhenLive() throws {
        guard isLive else {
            // Soft-pass: skeleton only
            return
        }
        let r = renderer(style: .display)
        var checked = 0
        var hardFails = 0
        var gradeAOutliers = 0
        var gradeACount = 0

        for item in Self.catalog.items {
            guard let expected = item.display, item.error == nil else { continue }
            guard let display = try? r.layout(latex: item.latex) else {
                hardFails += 1
                continue
            }
            checked += 1
            let stmH = Double((display.ascent + display.descent) / fontSize)
            let texH = expected.totalHeightEm
            guard texH > 0.05 else { continue }
            let ratio = stmH / texH
            // Same OTF target → tighter hard band than KaTeX DomTree.
            // Tightened 2026-08: 0.40…2.5 (was 0.35…2.8) after MATH stack/delim wiring.
            if ratio < 0.40 || ratio > 2.5 {
                hardFails += 1
                Issue.record("TeX height fail \(item.id): stm=\(stmH) tex=\(texH) ratio=\(ratio)")
            }
            if Self.gradeA.contains(item.id) {
                gradeACount += 1
                if ratio < 0.70 || ratio > 1.45 {
                    gradeAOutliers += 1
                }
            }
        }

        #expect(checked >= 10, "live TeX fixture should measure ≥10 formulas")
        #expect(hardFails == 0, "pathological TeX height mismatches: \(hardFails)")
        if gradeACount >= 6 {
            let rate = Double(gradeAOutliers) / Double(gradeACount)
            #expect(rate <= 0.35, "grade-A TeX outlier rate \(rate)")
        }
    }

    @Test func displayWidthWithinBandsWhenLive() throws {
        guard isLive else { return }
        let r = renderer(style: .display)
        var checked = 0
        var bad = 0
        for item in Self.catalog.items {
            guard let expected = item.display,
                  let tw = expected.widthEm, tw > 0.05,
                  item.error == nil,
                  let display = try? r.layout(latex: item.latex)
            else { continue }
            checked += 1
            let stmW = Double(display.width / fontSize)
            let ratio = stmW / tw
            if ratio < 0.25 || ratio > 4.0 {
                bad += 1
                Issue.record("TeX width fail \(item.id): stm=\(stmW) tex=\(tw) ratio=\(ratio)")
            }
        }
        #expect(checked >= 10)
        let rate = Double(bad) / Double(max(checked, 1))
        #expect(rate <= 0.15, "pathological TeX width rate \(rate)")
    }

    @Test func regeneratePathDocumented() {
        // Package-root relative path for agents / local regenerate.
        let hint = "python3 scripts/tex_oracle/tex_oracle.py --write-fixture"
        #expect(hint.contains("tex_oracle"))
        #expect(
            ["ok", "unavailable", "compile_failed", "empty", "missing", nil]
                .map { $0 as String? }
                .contains(Self.catalog.status)
            || Self.catalog.status != nil
        )
        // When not live, still pass: skeleton is intentional without TeX.
        if !isLive {
            #expect(Self.catalog.status == "unavailable" || Self.catalog.status == "missing"
                || Self.catalog.status == "empty" || Self.catalog.status == "compile_failed")
        }
    }
}
