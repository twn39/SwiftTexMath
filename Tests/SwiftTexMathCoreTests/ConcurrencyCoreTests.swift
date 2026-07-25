import Foundation
import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Concurrent font / layout / image stress (SwiftMath `ConcurrencyThreadsafeTests`, iosMath `MTConcurrencyTest`).
@Suite("Concurrency")
struct ConcurrencyCoreTests {
    @Test func concurrentFontRegistryAccess() async {
        let fonts = MathFont.Name.allBundled
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    let name = fonts.randomElement()!
                    let metrics = FontRegistry.shared.metrics(for: MathFont(name: name, size: 20))
                    return metrics?.axisHeight ?? 0 > 0
                }
            }
            for await ok in group {
                #expect(ok)
            }
        }
    }

    @Test func concurrentLayout() async throws {
        let samples = [
            #"E=mc^2"#, #"\frac{a}{b}"#, #"\sum_{i=1}^{n} x_i"#,
            #"\sqrt{2}"#, #"\left(\frac{1}{2}\right)"#, #"\lim_{x\to 0} x"#
        ]
        let renderer = MathRenderer(
            environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20))
        )
        try await withThrowingTaskGroup(of: CGFloat.self) { group in
            for _ in 0..<24 {
                let latex = samples.randomElement()!
                group.addTask {
                    let display = try renderer.layout(latex: latex)
                    return display.width
                }
            }
            for try await width in group {
                #expect(width > 0)
            }
        }
    }

    @Test func concurrentMathImageRender() async throws {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            for i in 0..<64 {
                group.addTask {
                    let result = try MathImage.render(
                        latex: "x_{\(i)}^2",
                        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 18))
                    )
                    return result.image.width > 0 && result.size.width > 0
                }
            }
            for try await ok in group {
                #expect(ok)
            }
        }
    }
}
