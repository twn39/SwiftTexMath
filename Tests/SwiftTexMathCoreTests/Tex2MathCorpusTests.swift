import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

/// Corpus imported from tex2math (`tests/fixtures` + embedded `let mut input` formulas).
///
/// Validation: parse + layout must succeed with positive size unless `expectError` is set
/// (intentionally invalid inputs from tex2math `error_recovery.rs`). Entries listed in
/// `unsupportedIDs` are skipped until Core gains the corresponding feature.
@Suite("tex2math corpus")
struct Tex2MathCorpusTests {
    struct Entry: Decodable, Sendable {
        var id: String
        var source: String
        var latex: String
        var expectError: Bool
    }

    /// Features not yet in SwiftTexMath (or syntax that diverges from tex2math).
    /// Prefer shrinking this set over growing it.
    static let unsupportedIDs: Set<String> = []

    static let catalog: [Entry] = {
        let candidates = [
            Bundle.module.url(forResource: "catalog", withExtension: "json", subdirectory: "Tex2MathCorpus"),
            Bundle.module.url(forResource: "catalog", withExtension: "json"),
            Bundle.module.resourceURL?
                .appendingPathComponent("Tex2MathCorpus")
                .appendingPathComponent("catalog.json")
        ]
        guard let url = candidates.compactMap({ $0 }).first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            fatalError("Tex2MathCorpus/catalog.json missing from test bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            fatalError("Failed to load Tex2MathCorpus catalog: \(error)")
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

    @Test func catalogLoadsNonEmpty() {
        #expect(Self.catalog.count >= 100)
        #expect(Self.catalog.contains { $0.source == "fixture" })
        #expect(Self.catalog.contains { $0.expectError })
    }

    @Test func unsupportedIDsAreInCatalog() {
        let ids = Set(Self.catalog.map(\.id))
        for id in Self.unsupportedIDs {
            #expect(ids.contains(id), "stale unsupported id: \(id)")
        }
    }

    @Test func allCorpusFormulasParseAndLayout() throws {
        var failures: [String] = []
        var skipped = 0
        var passed = 0

        for entry in Self.catalog {
            if Self.unsupportedIDs.contains(entry.id) {
                skipped += 1
                continue
            }

            if entry.expectError {
                // tex2math error-recovery cases: prefer ParseError, but a successful
                // parse is acceptable (we may be stricter or more lenient).
                do {
                    _ = try MathParser.parse(entry.latex)
                    passed += 1
                } catch is ParseError {
                    passed += 1
                } catch {
                    failures.append("unexpected error type for \(entry.id): \(error)")
                }
                continue
            }

            do {
                let display = try renderer.layout(latex: entry.latex)
                if display.width <= 0 && display.ascent + display.descent <= 0 {
                    failures.append("empty display: \(entry.id) :: \(entry.latex.prefix(100))")
                } else {
                    passed += 1
                }
            } catch {
                failures.append("\(entry.id): \(error) :: \(entry.latex.prefix(100))")
            }
        }

        if !failures.isEmpty {
            let sample = failures.prefix(40).joined(separator: "\n")
            Issue.record(
                Comment(
                    rawValue: """
                    tex2math corpus failures: \(failures.count) (passed \(passed), skipped \(skipped))
                    \(sample)
                    """
                )
            )
        }
        #expect(
            failures.isEmpty,
            "corpus failures=\(failures.count) passed=\(passed) skipped=\(skipped)"
        )
        #expect(passed >= 130)
    }

    /// Deeper corpus check: structure hints + non-empty tokens + raster ink for fixture entries.
    @Test func fixtureEntriesHaveStructureTokensAndInk() throws {
        let fixtures = Self.catalog.filter { $0.source == "fixture" && !$0.expectError }
        #expect(fixtures.count >= 40, "expected ≥40 fixture formulas")

        var failures: [String] = []
        var checked = 0
        for entry in fixtures {
            if Self.unsupportedIDs.contains(entry.id) { continue }
            do {
                let display = try renderer.layout(latex: entry.latex)
                checked += 1
                let height = display.ascent + display.descent
                if display.width <= 0 && height <= 0 {
                    failures.append("empty geometry: \(entry.id)")
                    continue
                }
                // Most fixtures should produce at least one glyph or compound node.
                if display.children.isEmpty {
                    failures.append("no children: \(entry.id)")
                }
                let tokens = display.extractTextTokens()
                let latexLower = entry.latex.lowercased()
                // Skip pure-structure / phantom-only edge cases for token emptiness.
                let allowEmptyTokens =
                    latexLower.contains("phantom")
                    || latexLower.contains("hspace")
                    || latexLower.contains("kern")
                    || latexLower.contains("hskip")
                    || latexLower.contains("mkern")
                if !allowEmptyTokens && tokens.isEmpty {
                    failures.append("empty tokens: \(entry.id)")
                }
                // Structure cross-checks from latex surface.
                let kinds = BroadLayoutCatalog.kindCounts(display)
                if latexLower.contains("\\frac") || latexLower.contains("\\dfrac")
                    || latexLower.contains("\\tfrac") || latexLower.contains("\\cfrac")
                    || latexLower.contains("\\binom") || latexLower.contains("\\choose")
                {
                    if kinds["fraction", default: 0] < 1 {
                        failures.append("missing fraction node: \(entry.id)")
                    }
                }
                if latexLower.contains("\\sqrt") {
                    if kinds["radical", default: 0] < 1 {
                        failures.append("missing radical node: \(entry.id)")
                    }
                }
                if latexLower.contains("\\sum") || latexLower.contains("\\prod")
                    || latexLower.contains("\\int")
                {
                    if kinds["largeOperator", default: 0] < 1 && kinds["glyphs", default: 0] < 1 {
                        failures.append("missing large op: \(entry.id)")
                    }
                }

                let image = MathImage.render(
                    display: display,
                    options: .init(
                        scale: 1,
                        padding: 0,
                        foregroundColor: CGColor(gray: 0, alpha: 1),
                        backgroundColor: CGColor(gray: 1, alpha: 1)
                    )
                ).image
                if MathImage.checksum(of: image) == 0 {
                    // Phantom-only or pure space can be blank; only flag when latex has letters/digits.
                    let hasInkExpect = entry.latex.unicodeScalars.contains {
                        CharacterSet.alphanumerics.contains($0)
                    } && !allowEmptyTokens
                    if hasInkExpect {
                        failures.append("blank raster: \(entry.id)")
                    }
                }
            } catch {
                failures.append("\(entry.id): \(error)")
            }
        }

        if !failures.isEmpty {
            Issue.record(
                Comment(rawValue: failures.prefix(30).joined(separator: "\n"))
            )
        }
        #expect(failures.isEmpty, "fixture deep-check failures=\(failures.count)/\(checked)")
        #expect(checked >= 40)
    }

    /// Catalog-wide soft height band vs font size (sanity, not KaTeX parity).
    @Test func catalogPositiveEntriesWithinSoftSizeBand() throws {
        var outliers = 0
        var checked = 0
        let fontSize: CGFloat = 20
        for entry in Self.catalog where !entry.expectError && !Self.unsupportedIDs.contains(entry.id) {
            guard let display = try? renderer.layout(latex: entry.latex) else {
                outliers += 1
                continue
            }
            checked += 1
            let h = display.ascent + display.descent
            // Soft: total height between 0.05em and 40em (pathological nesting aside).
            if h < fontSize * 0.05 || h > fontSize * 40 {
                outliers += 1
            }
            if display.width < 0 || display.width > fontSize * 80 {
                outliers += 1
            }
        }
        #expect(checked >= 100)
        let rate = Double(outliers) / Double(max(checked, 1))
        #expect(rate <= 0.05, "soft size outlier rate \(rate) (\(outliers)/\(checked))")
    }
}
