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
}
