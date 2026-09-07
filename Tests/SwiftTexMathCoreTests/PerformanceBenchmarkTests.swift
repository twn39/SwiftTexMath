import Foundation
import Testing
@testable import SwiftTexMathCore

// MARK: - Performance & Memory Footprint Tests

@Suite("Performance & Memory Footprint")
struct PerformanceBenchmarkTests {

    @Test func displayNodeMemoryLayoutIsCompact() {
        let size = MemoryLayout<DisplayNode>.size
        let stride = MemoryLayout<DisplayNode>.stride
        // Previously > 330 bytes before selective indirect case optimization.
        // With selective indirect case on heavy compound nodes, size drops to 137 bytes (stride 144).
        #expect(size <= 144, "DisplayNode size should be <= 144 bytes, got \(size)")
        #expect(stride <= 152, "DisplayNode stride should be <= 152 bytes, got \(stride)")
    }

    @Test func parseThroughputMicroBenchmark() throws {
        let latex = #"\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#
        let clock = ContinuousClock()
        let iterations = 1000

        let elapsed = try clock.measure {
            for _ in 0..<iterations {
                _ = try MathParser.parse(latex)
            }
        }
        // Ensure 1000 parses execute within reasonable bounds
        #expect(elapsed < .seconds(5))
    }

    @Test func typesetThroughputMicroBenchmark() throws {
        let latex = #"\sum_{i=1}^{n} i = \frac{n(n+1)}{2}"#
        let list = try MathParser.parse(latex)
        let env = MathEnvironment()
        let clock = ContinuousClock()
        let iterations = 1000

        let elapsed = clock.measure {
            for _ in 0..<iterations {
                _ = Typesetter.createDisplay(for: list, environment: env)
            }
        }
        #expect(elapsed < .seconds(5))
    }

    @Test func fontMetricsCachedInRegistry() {
        let font = MathFont(name: .latinModern, size: 20)
        let m1 = FontRegistry.shared.metrics(for: font)
        let m2 = FontRegistry.shared.metrics(for: font)
        #expect(m1 != nil)
        #expect(m2 != nil)
        // Verify same underlying CTFont pointer
        #expect(m1?.ctFont === m2?.ctFont)
    }

    @Test func singleGlyphMeasureFastPath() {
        guard let metrics = FontRegistry.shared.metrics(for: MathFont(name: .latinModern, size: 20)) else {
            Issue.record("Missing metrics")
            return
        }
        let glyph = metrics.glyph(for: "x")
        #expect(glyph != 0)
        let single = metrics.measure(glyph: glyph)
        let multi = metrics.measure(glyphs: [glyph])
        #expect(abs(single.width - multi.width) < 0.001)
        #expect(abs(single.ascent - multi.ascent) < 0.001)
        #expect(abs(single.descent - multi.descent) < 0.001)
    }
}
