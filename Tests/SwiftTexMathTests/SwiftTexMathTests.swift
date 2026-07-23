import Testing
@testable import SwiftTexMath
import SwiftTexMathCore

@Test @MainActor
func mathViewConstructible() {
    let view = Math(#"a^2 + b^2 = c^2"#)
        .mathFont(MathFont(name: .latinModern, size: 22))
        .mathTypesettingStyle(.display)
        .mathRenderingMode(.monochrome)
        .mathFonts(FontRegistry.shared)
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

/// Custom `FontProviding` must not write into `DisplayProvider`'s shared cache.
@Test func displayProviderBypassesCacheForCustomFonts() throws {
    let latex = #"x+y"#
    let font = MathFont(name: .latinModern, size: 20)

    struct EmptyFonts: FontProviding {
        func metrics(for font: MathFont) -> FontMetrics? { nil }
    }

    let shared = DisplayProvider.display(
        for: latex,
        font: font,
        style: .display,
        proposedWidth: 0,
        fonts: FontRegistry.shared
    )
    guard case .success(let cached) = shared else {
        Issue.record("Expected success with shared registry")
        return
    }
    #expect(cached.width > 0)

    let custom = DisplayProvider.display(
        for: latex,
        font: font,
        style: .display,
        proposedWidth: 0,
        fonts: EmptyFonts()
    )
    guard case .success(let empty) = custom else {
        Issue.record("Expected empty success with EmptyFonts")
        return
    }
    #expect(empty.width == 0 || empty.children.isEmpty)

    let again = DisplayProvider.display(
        for: latex,
        font: font,
        style: .display,
        proposedWidth: 0,
        fonts: FontRegistry.shared
    )
    guard case .success(let stillCached) = again else {
        Issue.record("Shared cache should remain valid after custom provider call")
        return
    }
    #expect(stillCached.width == cached.width)
}
