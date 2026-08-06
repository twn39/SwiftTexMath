import Testing
import Foundation
@testable import SwiftTexMathCore

@Suite("Concurrency & Cache Hardening Tests")
struct ConcurrencyCacheHardeningTests {
    @Test("Concurrent layout tasks across multiple threads")
    func testConcurrentMultiThreadedLayout() async throws {
        let latexSamples = [
            #"\frac{a+b}{c+d}"#,
            #"\sqrt{x^2 + y^2}"#,
            #"\int_{0}^{1} x dx"#,
            #"\lim_{n \to \infty} (1 + \frac{1}{n})^n"#,
            #"\begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix}"#
        ]

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                let latex = latexSamples[i % latexSamples.count]
                let fontName = MathFont.Name.allBundled[i % MathFont.Name.allBundled.count]
                group.addTask {
                    let renderer = MathRenderer(environment: MathEnvironment(font: MathFont(name: fontName, size: 18)))
                    let display = try renderer.layout(latex: latex)
                    #expect(display.width > 0)
                }
            }
            try await group.waitForAll()
        }
    }
}
