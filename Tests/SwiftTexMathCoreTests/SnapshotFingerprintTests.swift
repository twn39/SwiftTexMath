import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

// MARK: - MathImage rasterization

@Test func mathImageRendersQuadratic() throws {
    let result = try MathImage.render(
        latex: #"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#,
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 20), style: .display),
        options: .init(scale: 2, padding: 2)
    )
    #expect(result.image.width > 100)
    #expect(result.image.height > 40)
    #expect(result.size.width > 80)
    #expect(result.display.width > 80)
}

@Test func mathImageColorboxHasNonEmptyPixels() throws {
    let result = try MathImage.render(
        latex: #"\colorbox{#ff0000}{A}"#,
        environment: MathEnvironment(font: MathFont(name: .latinModern, size: 24)),
        options: .init(
            scale: 2,
            padding: 1,
            foregroundColor: CGColor(gray: 0, alpha: 1),
            backgroundColor: CGColor(gray: 1, alpha: 1)
        )
    )
    #expect(result.image.width > 10)
    #expect(MathImage.checksum(of: result.image) != 0)
}

// MARK: - Layout fingerprints (golden)

struct LayoutFingerprint: Equatable {
    var widthCenti: Int
    var heightCenti: Int
    var ascentCenti: Int
    var descentCenti: Int
    var childCount: Int
    var kindCounts: [String: Int]
    var imageChecksum: UInt64

    static func capture(
        latex: String,
        style: MathStyle = .display,
        fontSize: CGFloat = 20,
        maxWidth: CGFloat = 0
    ) throws -> LayoutFingerprint {
        let env = MathEnvironment(
            font: MathFont(name: .latinModern, size: fontSize),
            style: style,
            maxWidth: maxWidth
        )
        let display = try MathRenderer(environment: env).layout(latex: latex)
        let image = MathImage.render(
            display: display,
            options: .init(scale: 1, padding: 0, backgroundColor: CGColor(gray: 1, alpha: 1))
        ).image

        func countKinds(_ nodes: [DisplayNode], into map: inout [String: Int]) {
            for node in nodes {
                let key: String
                switch node {
                case .list(let list):
                    key = "list"
                    countKinds(list.children, into: &map)
                case .glyphs: key = "glyphs"
                case .fraction: key = "fraction"
                case .radical: key = "radical"
                case .line: key = "line"
                case .largeOperator: key = "largeOperator"
                case .colored(let c): key = c.fillsBackground ? "colorbox" : "color"
                case .rule: key = "rule"
                case .box: key = "box"
                case .stack: key = "stack"
                }
                map[key, default: 0] += 1
            }
        }

        var kinds: [String: Int] = [:]
        countKinds(display.children, into: &kinds)
        let height = display.ascent + display.descent
        return LayoutFingerprint(
            widthCenti: Int((display.width * 100).rounded()),
            heightCenti: Int((height * 100).rounded()),
            ascentCenti: Int((display.ascent * 100).rounded()),
            descentCenti: Int((display.descent * 100).rounded()),
            childCount: display.children.count,
            kindCounts: kinds,
            imageChecksum: MathImage.checksum(of: image)
        )
    }
}

@Test func fingerprintSimpleEqualsStable() throws {
    let a = try LayoutFingerprint.capture(latex: #"E = mc^2"#)
    let b = try LayoutFingerprint.capture(latex: #"E = mc^2"#)
    #expect(a == b)
    #expect(a.widthCenti > 4000 && a.widthCenti < 9000)
    #expect(a.kindCounts["glyphs", default: 0] >= 1)
}

@Test func fingerprintFractionHasFractionNode() throws {
    let fp = try LayoutFingerprint.capture(latex: #"\frac{1}{2}"#)
    #expect(fp.kindCounts["fraction", default: 0] == 1)
    #expect(fp.heightCenti > 2000)
}

@Test func fingerprintColorboxMarked() throws {
    let fp = try LayoutFingerprint.capture(latex: #"\colorbox{red}{x}"#)
    #expect(fp.kindCounts["colorbox", default: 0] == 1)
}

@Test func fingerprintArrayHasRules() throws {
    let fp = try LayoutFingerprint.capture(
        latex: #"\begin{array}{|c|c|} \hline a & b \\ \hline \end{array}"#
    )
    #expect(fp.kindCounts["rule", default: 0] >= 2)
}

@Test func fingerprintWrapChangesHeight() throws {
    let latex = #"a = b = c = d = e = f = g = h"#
    let wide = try LayoutFingerprint.capture(latex: latex, maxWidth: 0)
    let narrow = try LayoutFingerprint.capture(latex: latex, maxWidth: 50)
    #expect(narrow.heightCenti > wide.heightCenti)
    #expect(narrow.widthCenti <= 5100)
}

@Test func fingerprintOperatornameAndPmod() throws {
    let op = try LayoutFingerprint.capture(latex: #"\operatorname{Hom}(A,B)"#)
    #expect(op.widthCenti > 2000)
    let pmod = try LayoutFingerprint.capture(latex: #"x \pmod{n}"#)
    #expect(pmod.widthCenti > 2000)
}

@Test func fingerprintBraKet() throws {
    let fp = try LayoutFingerprint.capture(latex: #"\braket{\phi}{\psi}"#)
    #expect(fp.widthCenti > 1500)
    #expect(fp.childCount >= 1)
}

/// Guard rails: if metrics drift a lot, fail loudly with expected band.
@Test func fingerprintGoldenBandsLatinModern20() throws {
    let cases: [(String, ClosedRange<Int>, ClosedRange<Int>)] = [
        (#"a+b"#, 2000...6000, 800...2500),
        (#"\sqrt{2}"#, 1500...5000, 1500...4000),
        (#"\sum_{i=1}^{n} i"#, 3000...9000, 2500...7000),
        (#"\left( \frac{a}{b} \middle| c \right)"#, 4000...12000, 2500...7000)
    ]
    for (latex, widthBand, heightBand) in cases {
        let fp = try LayoutFingerprint.capture(latex: latex)
        #expect(widthBand.contains(fp.widthCenti), "width \(fp.widthCenti) for \(latex)")
        #expect(heightBand.contains(fp.heightCenti), "height \(fp.heightCenti) for \(latex)")
        #expect(fp.imageChecksum != 0)
    }
}
