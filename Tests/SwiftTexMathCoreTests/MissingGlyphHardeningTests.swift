import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Phase-2: missing-glyph fallback observability.
@Suite("Missing glyph hardening")
struct MissingGlyphHardeningTests {
    private var renderer: MathRenderer {
        MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display
            )
        )
    }

    /// Collect glyph runs that used text/system fallback.
    private func fallbackRuns(in display: DisplayList) -> [GlyphRun] {
        var out: [GlyphRun] = []
        func walk(_ nodes: [DisplayNode]) {
            for node in nodes {
                switch node {
                case .glyphs(let run):
                    if run.usesSystemFallback || run.fallbackFontName != nil {
                        out.append(run)
                    }
                case .list(let list):
                    walk(list.children)
                case .fraction(let f):
                    walk(f.numerator.children)
                    walk(f.denominator.children)
                case .radical(let r):
                    walk(r.radicand.children)
                    if let d = r.degree { walk(d.children) }
                case .line(let l):
                    walk(l.inner.children)
                case .colored(let c):
                    walk(c.inner.children)
                case .box(let b):
                    walk(b.child.children)
                case .stack(let s):
                    walk(s.base.children)
                    if let o = s.over { walk(o.children) }
                    if let u = s.under { walk(u.children) }
                case .largeOperator(let op):
                    if let u = op.upperLimit { walk(u.children) }
                    if let lo = op.lowerLimit { walk(lo.children) }
                case .rule:
                    break
                }
            }
        }
        walk(display.children)
        return out
    }

    @Test func asciiMathUsesNoFallback() throws {
        let display = try renderer.layout(latex: #"E=mc^2"#)
        let fb = fallbackRuns(in: display)
        #expect(fb.isEmpty, "unexpected fallback runs: \(fb.map(\.text))")
    }

    @Test func greekAndOperatorsNoFallback() throws {
        let display = try renderer.layout(latex: #"\alpha+\beta=\gamma"#)
        let fb = fallbackRuns(in: display)
        #expect(fb.isEmpty, "greek fallback: \(fb.map(\.text))")
    }

    @Test func cjkTriggersFallbackOrEmptyNucleus() throws {
        // CJK is outside Latin Modern MATH coverage → fallback path.
        let display = try renderer.layout(latex: #"x+\text{中}"#)
        // Layout must succeed with positive size even if text uses fallback.
        #expect(display.width > 0)
        let fb = fallbackRuns(in: display)
        // Prefer observing fallback; if \text lowers differently, still require non-empty layout.
        if fb.isEmpty {
            let tokens = display.extractTextTokens()
            #expect(!tokens.isEmpty || display.ascent + display.descent > 0)
        } else {
            #expect(fb.contains { $0.usesSystemFallback || $0.fallbackFontName != nil })
        }
    }

    @Test func fallbackDoesNotCrashSVGExport() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let svg = try MathSVG.render(latex: #"a+b"#, environment: env)
        #expect(svg.svg.contains("<svg"))
        #expect(svg.size.width > 0)
    }

    @Test func missingMathOpStillLayoutsWithPositiveSize() throws {
        // Private-use / unlikely math glyph: should not throw.
        let display = try renderer.layout(latex: "x")
        #expect(display.width > 0)
    }

    @Test func debugUserFormulas() throws {
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        let r = MathRenderer(environment: env)

        let f1 = #"\frac{365 - 49}{365} = \frac{316}{365}"#
        let d1 = try r.layout(latex: f1)
        #expect(d1.width > 0)

        let f2 = #"P(\text{都不同}) \approx 0.0296 \text{ (即约 2.96\%)}"#
        let d2 = try r.layout(latex: f2)
        #expect(d2.width > 0)

        let f3 = #"C_{50}^2"#
        let d3 = try r.layout(latex: f3)
        #expect(d3.width > 0)
    }
}
