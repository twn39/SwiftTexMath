import Testing
import SwiftTexMath
import SwiftTexMathCore

@Test @MainActor
func mathViewConstructible() {
    let view = Math(#"a^2 + b^2 = c^2"#)
        .mathFont(MathFont(name: .latinModern, size: 22))
        .mathTypesettingStyle(.display)
        .mathRenderingMode(.monochrome)
    _ = view
}

@Test func rendererThroughUIModule() throws {
    let display = try MathRenderer().layout(latex: #"a^2 + b^2 = c^2"#)
    #expect(display.width > 0)
}

@Test func uiModuleWidthConstrainedLayout() throws {
    let font = MathFont(name: .latinModern, size: 18)
    let latex = #"a = b = c = d = e = f"#
    let wide = try MathRenderer(
        environment: MathEnvironment(font: font, maxWidth: 0)
    ).layout(latex: latex)
    let narrow = try MathRenderer(
        environment: MathEnvironment(font: font, maxWidth: 60)
    ).layout(latex: latex)
    #expect(narrow.width <= 61)
    #expect(narrow.ascent + narrow.descent >= wide.ascent + wide.descent)
}

@Test func uiModuleSurfacesParseErrors() {
    #expect(throws: ParseError.self) {
        _ = try MathRenderer().layout(latex: #"\notacommand"#)
    }
}
