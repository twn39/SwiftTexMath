import Testing
import Foundation
@testable import SwiftTexMathCore

@Suite("SVG Exporter Detail Tests")
struct SVGExporterDetailTests {
    @Test("SVG export with custom CSS and precision options")
    func testCustomSVGOptions() throws {
        let renderer = MathRenderer()
        let result = try renderer.layoutDetailed(latex: #"x^2 + 2x + 1"#)

        let options = MathSVG.Options(
            padding: 10,
            foregroundCSS: "#123456",
            backgroundCSS: "#FEDCBA",
            includeXMLDeclaration: false,
            precision: 2,
            reuseGlyphPaths: false
        )
        let svgResult = MathSVG.render(display: result.display, options: options)

        #expect(!svgResult.svg.contains("<?xml"))
        #expect(svgResult.svg.contains("fill=\"#FEDCBA\""))
        #expect(svgResult.svg.contains("fill=\"#123456\""))
    }

    @Test("SVG dark mode preset options")
    func testDarkModeOptions() throws {
        let renderer = MathRenderer()
        let display = try renderer.layout(latex: #"a + b = c"#)

        let svgResult = MathSVG.render(display: display, options: .darkMode)
        #expect(svgResult.svg.contains("#FFFFFF"))
        #expect(svgResult.svg.contains("#000000"))
    }

    @Test("SVG render empty display list fallback")
    func testEmptyDisplayListRender() {
        let emptyDisplay = DisplayList()
        let svgResult = MathSVG.render(display: emptyDisplay, options: .transparent)

        #expect(svgResult.svg.contains("<svg"))
        #expect(svgResult.size.width >= 0)
        #expect(svgResult.size.height >= 0)
    }
}
