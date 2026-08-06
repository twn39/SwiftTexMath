import Testing
import Foundation
@testable import SwiftTexMathCore

@Suite("Exporter & Display Coverage")
struct MathSVGAndExporterCoverageTests {
    @Test("MathSVG export options and CSS custom styling")
    func testMathSVGExportOptions() throws {
        let renderer = MathRenderer()
        let result = try renderer.layoutDetailed(latex: #"\frac{1}{2} + x^2"#)

        let optionsDefault = MathSVG.Options()
        let svgResult1 = MathSVG.render(display: result.display, options: optionsDefault)
        #expect(svgResult1.svg.contains("<svg"))

        let optionsWithCSS = MathSVG.Options(
            padding: 8,
            foregroundCSS: "#ff0000",
            backgroundCSS: "#ffffff",
            includeXMLDeclaration: true,
            precision: 4,
            reuseGlyphPaths: true
        )
        let svgResult2 = MathSVG.render(display: result.display, options: optionsWithCSS)
        #expect(svgResult2.svg.contains("<?xml"))
        #expect(svgResult2.svg.contains("#ff0000"))
    }

    @Test("MathPDF export generation")
    func testMathPDFExport() throws {
        let renderer = MathRenderer()
        let display = try renderer.layout(latex: #"e^{i\pi} + 1 = 0"#)
        let pdfData = MathPDF.render(display: display)
        #expect(!pdfData.isEmpty)
    }

    @Test("MathRenderer error handling and layout detailed")
    func testMathRendererErrorHandling() {
        let renderer = MathRenderer()
        #expect(throws: Error.self) {
            _ = try renderer.layoutDetailed(latex: #"\invalidCommandWhichDoesNotExist"#)
        }
    }
}
