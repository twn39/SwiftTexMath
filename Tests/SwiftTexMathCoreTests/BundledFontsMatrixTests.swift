import Testing
import CoreGraphics
import Foundation
@testable import SwiftTexMathCore

@Suite("Bundled 12 OpenType MATH Fonts Matrix Verification")
struct BundledFontsMatrixTests {
    @Test("All 12 bundled fonts load and report positive math constants", arguments: MathFont.Name.allBundled)
    func testAllBundledFontsConstants(fontName: MathFont.Name) {
        let font = MathFont(name: fontName, size: 20)
        let metrics = FontRegistry.shared.metrics(for: font)

        #expect(metrics != nil)
        if let m = metrics {
            #expect(m.axisHeight > 0)
            #expect(m.fractionRuleThickness > 0)
        }
    }

    @Test("All 12 bundled fonts stretch tall delimiters in fractions", arguments: MathFont.Name.allBundled)
    func testAllBundledFontsDelimiterStretch(fontName: MathFont.Name) throws {
        let font = MathFont(name: fontName, size: 20)
        let list = try MathParser.parse(#"\left( \frac{a}{b} \right)"#)
        let env = MathEnvironment(font: font)

        let renderer = MathRenderer(environment: env)
        let display = renderer.layout(list)

        #expect(display.ascent > 10)
        #expect(display.descent > 5)
        #expect(display.width > 20)
    }

    @Test("All 12 bundled fonts attach accents properly", arguments: MathFont.Name.allBundled)
    func testAllBundledFontsAccentAttachment(fontName: MathFont.Name) throws {
        let font = MathFont(name: fontName, size: 20)
        let list = try MathParser.parse(#"\hat{x} + \widehat{abc}"#)
        let env = MathEnvironment(font: font)

        let renderer = MathRenderer(environment: env)
        let display = renderer.layout(list)

        #expect(display.ascent > 10)
        #expect(display.width > 15)
    }
}
