import Foundation
import Testing
@testable import SwiftTexMathCore

@Test func svgExportContainsRootAndPaths() throws {
    let result = try MathSVG.render(latex: #"a^2+b^2=c^2"#)
    #expect(result.svg.contains("<svg"))
    #expect(result.svg.contains("</svg>"))
    #expect(result.svg.contains("xmlns=\"http://www.w3.org/2000/svg\""))
    // Glyph outlines or at least some geometry.
    #expect(result.svg.contains("<path") || result.svg.contains("<line"))
    #expect(result.size.width > 1)
    #expect(result.size.height > 1)
    #expect(result.data.count > 50)
}

@Test func svgExportFractionHasRuleLine() throws {
    let result = try MathSVG.render(latex: #"\frac{1}{2}"#)
    #expect(result.svg.contains("<line"))
    #expect(result.svg.contains("stroke-width"))
}

@Test func svgExportColorboxHasRect() throws {
    let result = try MathSVG.render(latex: #"\colorbox{#ffcc00}{x}"#)
    #expect(result.svg.contains("<rect"))
}

@Test func svgExportCancelHasStrike() throws {
    let result = try MathSVG.render(latex: #"\cancel{x}"#)
    #expect(result.svg.contains("<line"))
}

@Test func svgBackgroundOptional() throws {
    let withBG = try MathSVG.render(
        latex: "x",
        options: MathSVG.Options(backgroundCSS: "#ffffff")
    )
    #expect(withBG.svg.contains("fill=\"#ffffff\""))

    let noBG = try MathSVG.render(latex: "x", options: MathSVG.Options(backgroundCSS: nil))
    // Root may still have path fills of #000000, but no full-canvas white rect as first child intent.
    #expect(noBG.svg.contains("xmlns"))
}

@Test func svgXMLDeclarationToggle() throws {
    let with = try MathSVG.render(
        latex: "x",
        options: MathSVG.Options(includeXMLDeclaration: true)
    )
    #expect(with.svg.hasPrefix("<?xml"))

    let without = try MathSVG.render(
        latex: "x",
        options: MathSVG.Options(includeXMLDeclaration: false)
    )
    #expect(without.svg.hasPrefix("<svg"))
}

@Test func svgFromDisplayList() throws {
    let display = try MathRenderer().layout(latex: #"\sqrt{x}"#)
    let result = MathSVG.render(display: display)
    #expect(result.svg.contains("<path") || result.svg.contains("<line"))
    #expect(result.display.width == display.width)
}

@Test func svgUtf8DataRoundTrip() throws {
    let result = try MathSVG.render(latex: #"\alpha+\beta"#)
    let text = String(data: result.data, encoding: .utf8)
    #expect(text == result.svg)
}
