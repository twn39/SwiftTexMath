import XCTest
@testable import SwiftTexMathCore

final class ExportExtensionTests: XCTestCase {

    // MARK: - MathImage Extension Tests

    func testMathImagePresetsAndBaselineOffset() throws {
        let latex = "\\frac{a}{b}"
        let darkResult = try MathImage.render(latex: latex, options: .darkMode)
        let transparentResult = try MathImage.render(latex: latex, options: .transparent)

        XCTAssertGreaterThan(darkResult.baselineOffset, 0, "Image result should report positive baseline offset")
        XCTAssertGreaterThan(transparentResult.baselineOffset, 0)
        XCTAssertEqual(darkResult.size.width, transparentResult.size.width)
    }

    // MARK: - MathPDF Extension Tests

    func testMathPDFResultAndPresets() throws {
        let latex = "\\sqrt{x^2 + 1}"
        let pdfResult = try MathPDF.renderResult(latex: latex, options: .darkMode)

        XCTAssertFalse(pdfResult.data.isEmpty, "PDF Result data should not be empty")
        XCTAssertGreaterThan(pdfResult.size.width, 0)
        XCTAssertGreaterThan(pdfResult.size.height, 0)
        XCTAssertGreaterThan(pdfResult.baselineOffset, 0, "PDF Result should include positive baselineOffset")
    }

    // MARK: - MathSVG Extension Tests

    func testMathSVGPresetsAndBaselineOffset() throws {
        let latex = "x^2 + y^2 = z^2"
        let darkResult = try MathSVG.render(latex: latex, options: .darkMode)
        let transparentResult = try MathSVG.render(latex: latex, options: .transparent)

        XCTAssertTrue(darkResult.svg.contains("<rect width="), "Dark mode SVG should include background rect")
        XCTAssertFalse(transparentResult.svg.contains("<rect width="), "Transparent SVG should omit background rect")
        XCTAssertGreaterThan(darkResult.baselineOffset, 0, "SVG Result should report positive baseline offset")
    }

    func testMathSVGReuseGlyphPathsOption() throws {
        let latex = "1 + 1 + 1"
        let options = MathSVG.Options(reuseGlyphPaths: true)
        let result = try MathSVG.render(latex: latex, options: options)

        XCTAssertFalse(result.svg.isEmpty)
        XCTAssertGreaterThan(result.size.width, 0)
    }

    // MARK: - FontMetrics Helper Tests

    func testFontMetricsEstimatedAxisHeight() {
        let font = MathFont(name: .latinModern, size: 20)
        guard let metrics = FontRegistry.shared.metrics(for: font) else {
            XCTFail("Failed to load Latin Modern metrics")
            return
        }
        XCTAssertGreaterThan(metrics.estimatedAxisHeight, 0)
    }
}
