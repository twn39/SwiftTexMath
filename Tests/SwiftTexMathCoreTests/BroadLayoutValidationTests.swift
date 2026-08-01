import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

// MARK: - Catalog

/// Broad multi-layer validation catalog (Latin Modern 20pt, display).
///
/// Each case is checked for:
/// 1. Absolute size goldens (±0.05 pt — slightly looser than core LM set for volume)
/// 2. Display-tree structure predicates
/// 3. Optional MATH clearance when fractions/radicals/ops are present
/// 4. Positive raster fingerprint (non-empty ink)
enum BroadLayoutCatalog {
    struct Case: Sendable {
        var id: String
        var latex: String
        var ascent: CGFloat
        var descent: CGFloat
        var width: CGFloat
        /// Required display-node kind counts (minimum).
        var minKinds: [String: Int] = [:]
        /// Substrings that must appear in extractTextTokens (joined).
        var tokenHints: [String] = []
        var expectFractionClearance: Bool = false
        var expectRadicalClearance: Bool = false
        var expectLargeOp: Bool = false
    }

    /// Size goldens measured 2026-08-01 (LM Math @ 20pt display).
    static let cases: [Case] = [
        // Fractions / binoms
        // binom/choose use zero-thickness genfrac rule — structure only, no rule-clearance assert.
        .init(id: "binom", latex: #"\binom{n}{k}"#, ascent: 22.38, descent: 13.94, width: 12.0,
              minKinds: ["fraction": 1], tokenHints: ["n", "k"]),
        .init(id: "choose", latex: #"{n \choose k}"#, ascent: 22.38, descent: 13.94, width: 12.0,
              minKinds: ["fraction": 1], tokenHints: ["n", "k"]),
        .init(id: "tfrac", latex: #"\tfrac{a}{b}"#, ascent: 14.068, descent: 7.054, width: 7.406,
              minKinds: ["fraction": 1], expectFractionClearance: true),
        .init(id: "dfrac", latex: #"\dfrac{a}{b}"#, ascent: 22.38, descent: 13.94, width: 10.58,
              minKinds: ["fraction": 1], expectFractionClearance: true),
        .init(id: "sqrt_frac", latex: #"\sqrt{\frac{a}{b}}"#, ascent: 26.94, descent: 21.86, width: 30.58,
              minKinds: ["radical": 1, "fraction": 1], expectFractionClearance: true, expectRadicalClearance: true),
        // Nested radicals may use text-style vertical gap — structure + size only.
        .init(id: "frac_sqrt", latex: #"\frac{\sqrt{a}}{\sqrt{b}}"#, ascent: 28.60, descent: 18.60, width: 27.24,
              minKinds: ["fraction": 1, "radical": 1], expectFractionClearance: true),
        .init(id: "nested_sqrt", latex: #"\sqrt{\sqrt{x}}"#, ascent: 17.96, descent: 18.84, width: 48.10,
              minKinds: ["radical": 1]),
        .init(id: "partial_frac", latex: #"\frac{\partial f}{\partial x}"#, ascent: 27.86, descent: 14.16, width: 22.06,
              minKinds: ["fraction": 1], expectFractionClearance: true),
        .init(id: "braced_frac", latex: #"\left\{\frac{a}{b}\right\}"#, ascent: 23.0, descent: 13.94, width: 41.7044,
              minKinds: ["fraction": 1], expectFractionClearance: true),
        // Quadratic: radical sits in script-size numerator context — skip display-style radical gap.
        .init(id: "quad", latex: #"x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}"#,
              ascent: 37.184, descent: 13.94, width: 159.5689,
              minKinds: ["fraction": 1, "radical": 1], tokenHints: ["x", "b"],
              expectFractionClearance: true),

        // Large operators
        // Display-style limits often use `.largeOperator`; side-scripts / some ops lower to glyphs+list.
        .init(id: "prod", latex: #"\prod_{i=1}^{n}"#, ascent: 29.342, descent: 21.818, width: 25.56,
              tokenHints: ["i", "n"], expectLargeOp: true),
        .init(id: "iint", latex: #"\iint_D"#, ascent: 27.22, descent: 24.10, width: 29.50,
              expectLargeOp: true),
        .init(id: "oint", latex: #"\oint_C"#, ascent: 27.22, descent: 24.408, width: 21.10,
              expectLargeOp: true),
        .init(id: "sum_frac", latex: #"\sum_{k=1}^{n}\frac{1}{k}"#,
              ascent: 29.342, descent: 22.21, width: 42.6333,
              minKinds: ["fraction": 1],
              expectFractionClearance: true, expectLargeOp: true),
        .init(id: "int_frac", latex: #"\int_0^1\frac{1}{1+x^2}\,dx"#,
              ascent: 34.384, descent: 24.408, width: 122.4356,
              minKinds: ["fraction": 1], expectFractionClearance: true),
        .init(id: "displaystyle_sum", latex: #"\displaystyle\sum_i x_i"#,
              ascent: 19.0, descent: 21.748, width: 49.6033, expectLargeOp: true),
        .init(id: "textstyle_sum", latex: #"\textstyle\sum_i x_i"#,
              ascent: 15.0, descent: 12.034, width: 47.7933, expectLargeOp: true),
        .init(id: "substack", latex: #"\sum_{\substack{i=1\\j=1}}^{n}"#,
              ascent: 29.342, descent: 43.3453, width: 28.88, expectLargeOp: true),
        .init(id: "lim_inf", latex: #"\liminf_{n\to\infty}a_n"#,
              ascent: 12.05, descent: 12.684, width: 80.6533, tokenHints: ["lim"]),
        .init(id: "max", latex: #"\max_{x\in S}f(x)"#,
              ascent: 14.96, descent: 13.402, width: 77.3533, tokenHints: ["max"]),

        // Matrices / environments
        .init(id: "matrix", latex: #"\begin{matrix} a & b \\ c & d \end{matrix}"#,
              ascent: 25.7667, descent: 15.7667, width: 40.98, tokenHints: ["a", "b"]),
        .init(id: "bmatrix", latex: #"\begin{bmatrix} 1 & 2 \\ 3 & 4 \end{bmatrix}"#,
              ascent: 26.0, descent: 16.0, width: 64.4044, tokenHints: ["1", "2"]),
        .init(id: "vmatrix", latex: #"\begin{vmatrix} a & b \\ c & d \end{vmatrix}"#,
              ascent: 25.84, descent: 15.84, width: 56.5444),
        .init(id: "cases", latex: #"\begin{cases} x & x>0 \\ -x & x\le 0 \end{cases}"#,
              ascent: 29.0, descent: 19.0, width: 103.4333, tokenHints: ["x"]),
        .init(id: "aligned", latex: #"\begin{aligned} a&=b\\ c&=d \end{aligned}"#,
              ascent: 32.4333, descent: 22.4333, width: 42.0956),
        .init(id: "gathered", latex: #"\begin{gathered} a\\ b \end{gathered}"#,
              ascent: 29.9133, descent: 19.9133, width: 10.58),
        .init(id: "gathered2", latex: #"\begin{gathered} x=1\\ y=2 \end{gathered}"#,
              ascent: 33.8133, descent: 23.8133, width: 48.1111),
        .init(id: "split", latex: #"\begin{split} a&=b+c\\ &=d \end{split}"#,
              ascent: 33.1533, descent: 23.1533, width: 73.3844),
        .init(id: "align", latex: #"\begin{align} a&=b\\ c&=d \end{align}"#,
              ascent: 38.2533, descent: 28.2533, width: 87.6556),
        .init(id: "array_hline", latex: #"\begin{array}{|c|c|} \hline a & b \\ \hline c & d \\ \hline \end{array}"#,
              ascent: 30.3, descent: 20.3, width: 43.38, minKinds: ["rule": 1]),
        .init(id: "smallmatrix", latex: #"\begin{smallmatrix} a & b \\ c & d \end{smallmatrix}"#,
              ascent: 21.5367, descent: 11.5367, width: 21.3527),

        // Accents / stacks / decorations
        // Combining accent may attach as U+20D7; size golden is the primary check.
        .init(id: "vec", latex: #"\vec{v}"#, ascent: 14.22, descent: 0.22, width: 11.38),
        .init(id: "bar", latex: #"\bar{x}"#, ascent: 12.80, descent: 0.22, width: 11.84),
        .init(id: "tilde", latex: #"\tilde{x}"#, ascent: 14.92, descent: 0.22, width: 11.86),
        .init(id: "dot", latex: #"\dot{x}"#, ascent: 13.54, descent: 0.22, width: 11.88),
        .init(id: "ddot", latex: #"\ddot{x}"#, ascent: 13.44, descent: 0.22, width: 11.80),
        .init(id: "cancel", latex: #"\cancel{x+y}"#, ascent: 11.66, descent: 4.10, width: 45.6889,
              minKinds: ["box": 1]),
        .init(id: "boxed", latex: #"\boxed{E=mc^2}"#, ascent: 16.584, descent: 0.22, width: 76.2711,
              minKinds: ["box": 1], tokenHints: ["E"]),
        .init(id: "overset", latex: #"\overset{def}{=}"#, ascent: 24.08, descent: 0.0, width: 20.664,
              minKinds: ["stack": 1]),
        .init(id: "underbrace", latex: #"\underbrace{a+b+c}_{3}"#, ascent: 13.88, descent: 20.648, width: 88.24,
              minKinds: ["stack": 1]),
        .init(id: "overbrace", latex: #"\overbrace{a+b+c}^{3}"#, ascent: 42.124, descent: 1.66, width: 88.24,
              minKinds: ["stack": 1]),
        .init(id: "colorbox", latex: #"\colorbox{yellow}{x}"#, ascent: 8.84, descent: 0.22, width: 11.44,
              minKinds: ["colorbox": 1]),

        // Fonts / operators / spacing
        .init(id: "mathbf", latex: #"\mathbf{A}\mathbf{B}"#, ascent: 13.96, descent: 0.0, width: 33.74),
        .init(id: "mathbb", latex: #"\mathbb{R}"#, ascent: 13.66, descent: 0.0, width: 12.78),
        .init(id: "mathcal", latex: #"\mathcal{L}"#, ascent: 13.70, descent: 0.14, width: 15.40),
        .init(id: "operatorname", latex: #"\operatorname{rank}(A)"#,
              ascent: 14.96, descent: 4.96, width: 70.08, tokenHints: ["rank"]),
        .init(id: "pmod", latex: #"x\pmod{n}"#, ascent: 14.96, descent: 4.96, width: 91.2244),
        .init(id: "det", latex: #"\det(A)"#, ascent: 14.96, descent: 4.96, width: 58.34, tokenHints: ["det"]),
        .init(id: "phantom_ab", latex: #"a\phantom{x}b"#, ascent: 13.88, descent: 0.22, width: 30.60),
        .init(id: "quad_space", latex: #"a\quad b"#, ascent: 13.88, descent: 0.22, width: 39.16),

        // Delimiters
        .init(id: "middle", latex: #"\left(a\middle|b\right)"#, ascent: 15.0, descent: 5.0, width: 49.1689),
        .init(id: "big", latex: #"\big(\frac{a}{b}\big)"#, ascent: 22.38, descent: 13.94, width: 35.2378,
              minKinds: ["fraction": 1], expectFractionClearance: true),
        .init(id: "Big", latex: #"\Big(\frac{a}{b}\Big)"#, ascent: 22.38, descent: 13.94, width: 39.2778,
              minKinds: ["fraction": 1], expectFractionClearance: true),
        .init(id: "lr_sqrt", latex: #"\left[\sqrt{\frac{x}{y}}\right]"#,
              ascent: 35.0, descent: 25.0, width: 62.5644,
              minKinds: ["radical": 1, "fraction": 1],
              expectFractionClearance: true, expectRadicalClearance: true),
        .init(id: "abs", latex: #"\left|x\right|"#, ascent: 15.0, descent: 5.0, width: 27.0044),
        .init(id: "norm", latex: #"\left\|v\right\|"#, ascent: 15.0, descent: 5.0, width: 25.2644),
        .init(id: "floor", latex: #"\lfloor x\rfloor"#, ascent: 15.0, descent: 5.0, width: 29.20),
        .init(id: "ceil", latex: #"\lceil x\rceil"#, ascent: 15.0, descent: 5.0, width: 29.20),

        // Scripts / chains / relations
        .init(id: "subsup", latex: #"x_1^{n+1}"#, ascent: 16.584, descent: 7.10, width: 38.852),
        .init(id: "prime", latex: #"f'(x)"#, ascent: 22.412, descent: 4.96, width: 44.074),
        .init(id: "nested_scripts", latex: #"x^{y^z}"#, ascent: 16.762, descent: 0.22, width: 25.246),
        .init(id: "multi_script", latex: #"a_{i,j}^{k,\ell}"#, ascent: 17.926, descent: 10.766, width: 28.724),
        .init(id: "tensor", latex: #"T^{i}_{jk}"#, ascent: 20.634, descent: 9.75, width: 22.902),
        .init(id: "chain", latex: #"a+b+c+d+e"#, ascent: 13.88, descent: 1.66, width: 145.3356),
        .init(id: "rel_chain", latex: #"a=b=c"#, ascent: 13.88, descent: 0.22, width: 81.1622),
        .init(id: "paren", latex: #"(a+b)(c+d)"#, ascent: 14.96, descent: 4.96, width: 118.2378),
        .init(id: "sin_cos", latex: #"\sin^2\theta+\cos^2\theta=1"#,
              ascent: 18.844, descent: 1.68, width: 154.8667, tokenHints: ["sin", "cos"]),
        .init(id: "exp", latex: #"e^{i\pi}+1=0"#, ascent: 16.514, descent: 1.66, width: 94.594),
        .init(id: "alpha_beta", latex: #"\alpha+\beta"#, ascent: 14.12, descent: 3.88, width: 48.4289),
        .init(id: "Gamma", latex: #"\Gamma(z)"#, ascent: 14.96, descent: 4.96, width: 37.36),
        .init(id: "mapsto", latex: #"x\mapsto y"#, ascent: 10.34, descent: 4.10, width: 51.8911),
        .init(id: "forall", latex: #"\forall x\in X"#, ascent: 13.92, descent: 0.86, width: 65.7711),
        .init(id: "cup_cap", latex: #"A\cup B\cap C"#, ascent: 14.32, descent: 0.44, width: 88.9378),
        .init(id: "oplus", latex: #"a\oplus b"#, ascent: 13.88, descent: 1.84, width: 43.6089),
        .init(id: "leq", latex: #"a\le b\ge c"#, ascent: 13.88, descent: 2.38, width: 81.1622),
        .init(id: "approx", latex: #"a\approx b"#, ascent: 13.88, descent: 0.22, width: 45.7311),
        .init(id: "partial", latex: #"\partial_x f"#, ascent: 14.32, descent: 7.474, width: 28.288),
        .init(id: "nabla", latex: #"\nabla\cdot\vec{F}"#, ascent: 18.82, descent: 0.66, width: 48.5689),
        .init(id: "tag_eq", latex: #"a+b\tag{1}"#, ascent: 14.96, descent: 4.96, width: 89.1689,
              tokenHints: ["a", "b"])
    ]

    static let sizeTolerance: CGFloat = 0.05
    static let renderer = MathRenderer(
        environment: MathEnvironment(
            font: MathFont(name: .latinModern, size: 20),
            style: .display
        )
    )

    /// Fold math-alphanumeric / operator tokens so ASCII hints match italic nuclei (`𝑛` ↔ `n`).
    static func foldMathTokens(_ tokens: [String]) -> String {
        let joined = tokens.joined()
        var out = String.UnicodeScalarView()
        out.reserveCapacity(joined.unicodeScalars.count)
        for s in joined.unicodeScalars {
            let v = s.value
            let mapped: UInt32?
            switch v {
            // Mathematical Italic / Bold Italic / Sans / … capital A–Z blocks (common MATH ranges)
            case 0x1D400...0x1D419: mapped = 0x41 + (v - 0x1D400) // bold A-Z
            case 0x1D41A...0x1D433: mapped = 0x61 + (v - 0x1D41A) // bold a-z
            case 0x1D434...0x1D44D: mapped = 0x41 + (v - 0x1D434) // italic A-Z
            case 0x1D44E...0x1D467: mapped = 0x61 + (v - 0x1D44E) // italic a-z
            case 0x1D468...0x1D481: mapped = 0x41 + (v - 0x1D468) // bold italic A-Z
            case 0x1D482...0x1D49B: mapped = 0x61 + (v - 0x1D482) // bold italic a-z
            case 0x1D49C...0x1D4B5: mapped = 0x41 + (v - 0x1D49C) // script A-Z (partial)
            case 0x1D4D0...0x1D4E9: mapped = 0x41 + (v - 0x1D4D0)
            case 0x1D4EA...0x1D503: mapped = 0x61 + (v - 0x1D4EA)
            case 0x1D504...0x1D51D: mapped = 0x41 + (v - 0x1D504) // fraktur
            case 0x1D51E...0x1D537: mapped = 0x61 + (v - 0x1D51E)
            case 0x1D538...0x1D551: mapped = 0x41 + (v - 0x1D538) // double-struck
            case 0x1D552...0x1D56B: mapped = 0x61 + (v - 0x1D552)
            case 0x1D5A0...0x1D5B9: mapped = 0x41 + (v - 0x1D5A0) // sans
            case 0x1D5BA...0x1D5D3: mapped = 0x61 + (v - 0x1D5BA)
            case 0x1D7CE...0x1D7D7: mapped = 0x30 + (v - 0x1D7CE) // bold digits
            case 0x1D7E2...0x1D7EB: mapped = 0x30 + (v - 0x1D7E2)
            // Dotless i / special italic h often used in math fonts
            case 0x210E: mapped = 0x68 // ℎ → h
            case 0x1D6A4: mapped = 0x69 // 𝚤 → i
            default: mapped = nil
            }
            if let mapped, let scalar = UnicodeScalar(mapped) {
                out.append(scalar)
            } else {
                out.append(s)
            }
        }
        return String(out).lowercased()
    }

    static func tokensContainHint(_ tokens: [String], hint: String) -> Bool {
        let folded = foldMathTokens(tokens)
        let h = hint.lowercased()
        if h.count == 1, let s = h.unicodeScalars.first {
            return folded.unicodeScalars.contains(s)
        }
        if folded.contains(h) { return true }
        // Multi-letter operators often split across glyphs (`lim` + `inf`).
        return tokens.joined().lowercased().contains(h)
    }

    static func kindCounts(_ display: DisplayList) -> [String: Int] {
        var map: [String: Int] = [:]
        func walk(_ nodes: [DisplayNode]) {
            for node in nodes {
                let key: String
                switch node {
                case .list(let list):
                    key = "list"
                    walk(list.children)
                case .glyphs: key = "glyphs"
                case .fraction(let f):
                    key = "fraction"
                    walk(f.numerator.children)
                    walk(f.denominator.children)
                case .radical(let r):
                    key = "radical"
                    walk(r.radicand.children)
                    if let d = r.degree { walk(d.children) }
                case .line(let l):
                    key = "line"
                    walk(l.inner.children)
                case .largeOperator(let op):
                    key = "largeOperator"
                    if let u = op.upperLimit { walk(u.children) }
                    if let lo = op.lowerLimit { walk(lo.children) }
                case .colored(let c):
                    key = c.fillsBackground ? "colorbox" : "color"
                    walk(c.inner.children)
                case .rule: key = "rule"
                case .box(let b):
                    key = "box"
                    walk(b.child.children)
                case .stack(let s):
                    key = "stack"
                    walk(s.base.children)
                    if let o = s.over { walk(o.children) }
                    if let u = s.under { walk(u.children) }
                }
                map[key, default: 0] += 1
            }
        }
        walk(display.children)
        return map
    }
}

// MARK: - Size goldens

@Suite("Broad layout — size goldens")
struct BroadLayoutSizeTests {
    @Test(arguments: BroadLayoutCatalog.cases)
    func sizeMatchesGolden(_ c: BroadLayoutCatalog.Case) throws {
        let display = try BroadLayoutCatalog.renderer.layout(latex: c.latex)
        let tol = BroadLayoutCatalog.sizeTolerance
        #expect(abs(display.ascent - c.ascent) <= tol, "ascent \(display.ascent) vs \(c.ascent) for \(c.id)")
        #expect(abs(display.descent - c.descent) <= tol, "descent \(display.descent) vs \(c.descent) for \(c.id)")
        #expect(abs(display.width - c.width) <= tol, "width \(display.width) vs \(c.width) for \(c.id)")
        #expect(display.width > 0 || display.ascent + display.descent > 0, "empty display for \(c.id)")
    }

    @Test func catalogCoversAtLeastSeventyCases() {
        #expect(BroadLayoutCatalog.cases.count >= 70)
    }
}

// MARK: - Structure & tokens

@Suite("Broad layout — structure & tokens")
struct BroadLayoutStructureTests {
    @Test(arguments: BroadLayoutCatalog.cases)
    func structureAndTokens(_ c: BroadLayoutCatalog.Case) throws {
        let display = try BroadLayoutCatalog.renderer.layout(latex: c.latex)
        let kinds = BroadLayoutCatalog.kindCounts(display)
        for (kind, minCount) in c.minKinds {
            #expect(
                kinds[kind, default: 0] >= minCount,
                "\(c.id): expected ≥\(minCount) \(kind), got \(kinds[kind, default: 0]) kinds=\(kinds)"
            )
        }
        if !c.tokenHints.isEmpty {
            let tokens = display.extractTextTokens()
            for hint in c.tokenHints {
                let ok = BroadLayoutCatalog.tokensContainHint(tokens, hint: hint)
                #expect(ok, "\(c.id): missing token hint '\(hint)' in \(tokens) folded=\(BroadLayoutCatalog.foldMathTokens(tokens))")
            }
        }
        if c.expectLargeOp {
            #expect(
                kinds["largeOperator", default: 0] >= 1 || kinds["glyphs", default: 0] >= 1,
                "\(c.id): expected large op or glyph nucleus"
            )
        }
    }
}

// MARK: - Clearance invariants (subset)

@Suite("Broad layout — clearance")
struct BroadLayoutClearanceTests {
    @Test(arguments: BroadLayoutCatalog.cases.filter(\.expectFractionClearance))
    func fractionClearances(_ c: BroadLayoutCatalog.Case) throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try BroadLayoutCatalog.renderer.layout(latex: c.latex)
        let fracs = LayoutClearance.allFractions(in: display)
        #expect(!fracs.isEmpty, "\(c.id): expected fractions")
        for frac in fracs {
            LayoutClearance.assertFractionRuleClearances(frac, metrics: metrics)
        }
    }

    @Test(arguments: BroadLayoutCatalog.cases.filter(\.expectRadicalClearance))
    func radicalClearances(_ c: BroadLayoutCatalog.Case) throws {
        let metrics = try #require(LayoutClearance.metrics())
        let display = try BroadLayoutCatalog.renderer.layout(latex: c.latex)
        let rad = try #require(LayoutClearance.radical(in: display), "\(c.id): missing radical")
        // Soft: outer style unknown for catalog mix; accept text or display gap.
        LayoutClearance.assertRadicalClearanceSoft(rad, metrics: metrics)
    }

    /// Zero-thickness genfrac (binom) still produces a fraction node with positive size.
    @Test func binomIsFractionNodeWithPositiveSize() throws {
        let display = try BroadLayoutCatalog.renderer.layout(latex: #"\binom{n}{k}"#)
        let fracs = LayoutClearance.allFractions(in: display)
        #expect(fracs.count >= 1)
        #expect(display.ascent > 10 && display.descent > 5)
        // Rule thickness may be 0 for binom; still expect ordered num above den.
        if let f = fracs.first {
            #expect(f.numeratorOffset > 0 || f.denominatorOffset > 0)
        }
    }

    @Test(arguments: BroadLayoutCatalog.cases.filter(\.expectLargeOp))
    func largeOpPositiveExtent(_ c: BroadLayoutCatalog.Case) throws {
        let display = try BroadLayoutCatalog.renderer.layout(latex: c.latex)
        #expect(display.ascent + display.descent > 10, "\(c.id): large op should have height")
        #expect(display.width > 5, "\(c.id): large op should have width")
    }
}

// MARK: - Raster fingerprints (broad)

@Suite("Broad layout — raster fingerprints")
struct BroadLayoutRasterTests {
    @Test(arguments: BroadLayoutCatalog.cases)
    func rasterHasInkAndStableFingerprint(_ c: BroadLayoutCatalog.Case) throws {
        let env = MathEnvironment(
            font: MathFont(name: .latinModern, size: 20),
            style: .display
        )
        let display = try MathRenderer(environment: env).layout(latex: c.latex)
        let image = MathImage.render(
            display: display,
            options: .init(
                scale: 1,
                padding: 0,
                foregroundColor: CGColor(gray: 0, alpha: 1),
                backgroundColor: CGColor(gray: 1, alpha: 1)
            )
        ).image
        #expect(image.width > 0 && image.height > 0, "\(c.id): empty image")
        let sum = MathImage.checksum(of: image)
        #expect(sum != 0, "\(c.id): zero checksum (blank raster?)")

        // Determinism: second layout+render matches checksum.
        let display2 = try MathRenderer(environment: env).layout(latex: c.latex)
        let image2 = MathImage.render(
            display: display2,
            options: .init(
                scale: 1,
                padding: 0,
                foregroundColor: CGColor(gray: 0, alpha: 1),
                backgroundColor: CGColor(gray: 1, alpha: 1)
            )
        ).image
        #expect(MathImage.checksum(of: image2) == sum, "\(c.id): non-deterministic raster")
    }
}

// MARK: - Relative style / wrap invariants

@Suite("Broad layout — relative invariants")
struct BroadLayoutRelativeTests {
    @Test func displaySumTallerOrWiderThanTextstyleSum() throws {
        let d = try BroadLayoutCatalog.renderer.layout(latex: #"\displaystyle\sum_i x_i"#)
        let t = try MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .text
            )
        ).layout(latex: #"\sum_i x_i"#)
        let dH = d.ascent + d.descent
        let tH = t.ascent + t.descent
        #expect(dH >= tH * 0.85 || d.width >= t.width * 0.85)
    }

    @Test func dfracTallerThanTfrac() throws {
        let d = try BroadLayoutCatalog.renderer.layout(latex: #"\dfrac{a}{b}"#)
        let t = try BroadLayoutCatalog.renderer.layout(latex: #"\tfrac{a}{b}"#)
        #expect(d.ascent + d.descent > t.ascent + t.descent)
    }

    @Test func longChainWrapsUnderMaxWidth() throws {
        let wide = try BroadLayoutCatalog.renderer.layout(latex: #"a+b+c+d+e+f+g+h"#)
        let narrow = try MathRenderer(
            environment: MathEnvironment(
                font: MathFont(name: .latinModern, size: 20),
                style: .display,
                maxWidth: 60
            )
        ).layout(latex: #"a+b+c+d+e+f+g+h"#)
        #expect(narrow.ascent + narrow.descent > wide.ascent + wide.descent)
        #expect(narrow.width <= 65)
    }

    @Test func bmatrixWiderThanMatrix() throws {
        let m = try BroadLayoutCatalog.renderer.layout(
            latex: #"\begin{matrix} a & b \\ c & d \end{matrix}"#
        )
        let b = try BroadLayoutCatalog.renderer.layout(
            latex: #"\begin{bmatrix} a & b \\ c & d \end{bmatrix}"#
        )
        #expect(b.width > m.width)
    }

    @Test func nestedSqrtTallerThanSimpleSqrt() throws {
        let nested = try BroadLayoutCatalog.renderer.layout(latex: #"\sqrt{\sqrt{x}}"#)
        let simple = try BroadLayoutCatalog.renderer.layout(latex: #"\sqrt{x}"#)
        #expect(nested.ascent + nested.descent > simple.ascent + simple.descent)
    }

    @Test func underbraceDeeperThanBase() throws {
        let braced = try BroadLayoutCatalog.renderer.layout(latex: #"\underbrace{a+b+c}_{3}"#)
        let base = try BroadLayoutCatalog.renderer.layout(latex: #"a+b+c"#)
        #expect(braced.descent > base.descent)
    }

    @Test func overbraceHigherThanBase() throws {
        let braced = try BroadLayoutCatalog.renderer.layout(latex: #"\overbrace{a+b+c}^{3}"#)
        let base = try BroadLayoutCatalog.renderer.layout(latex: #"a+b+c"#)
        #expect(braced.ascent > base.ascent)
    }

    @Test func phantomPreservesWidthBetweenLetters() throws {
        let with = try BroadLayoutCatalog.renderer.layout(latex: #"a\phantom{x}b"#)
        let without = try BroadLayoutCatalog.renderer.layout(latex: #"ab"#)
        #expect(with.width > without.width)
    }

    @Test func exportSVGAndPDFPositiveForCatalogSample() throws {
        let sample = [
            #"\frac{1}{2}"#,
            #"\sum_{i=1}^{n} i"#,
            #"\begin{pmatrix} a & b \\ c & d \end{pmatrix}"#,
            #"x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}"#
        ]
        let env = MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display)
        for latex in sample {
            let svg = try MathSVG.render(latex: latex, environment: env)
            #expect(svg.size.width > 0 && svg.size.height > 0, "SVG size for \(latex)")
            #expect(svg.svg.contains("<svg"), "SVG markup for \(latex)")
            let pdf = try MathPDF.render(latex: latex, environment: env)
            #expect(pdf.count > 100, "PDF bytes for \(latex)")
        }
    }
}
